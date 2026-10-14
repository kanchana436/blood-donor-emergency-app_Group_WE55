const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { prisma } = require('../prisma');
const { authenticateToken, JWT_SECRET } = require('../middleware/auth.middleware');
const { normalizeCity } = require('../services/blood-stock-notification.service');
const router = express.Router();
// Domain-separated signing key prevents a chat JWT being used as an app JWT.
const CHAT_SECRET = require('node:crypto').createHmac('sha256', JWT_SECRET).update('lifelink-manager-chat-v1').digest('hex');
const managers = ['manager', 'admin'];
const personSelect = { id: true, name: true, role: true, isActive: true, branchId: true,
  branch: true, donorProfile: { select: { city: true, bloodGroup: true } } };
const conversationInclude = { manager: { select: personSelect }, donor: { select: personSelect }, branch: true };
const messageSelect = { id: true, conversationId: true, senderId: true, message: true, isRead: true, createdAt: true };
const issue = (message, status = 403) => Object.assign(new Error(message), { status });
function assigned(user) {
  return user?.isActive && managers.includes(user.role) && user.branchId && user.branch
    && user.branch.id === user.branchId && normalizeCity(user.branch.city);
}
function eligible(manager, donor, branch = manager?.branch) {
  return assigned(manager) && donor?.isActive && donor.role === 'donor'
    && branch?.id === manager.branchId && normalizeCity(branch.city)
    && normalizeCity(branch.city) === normalizeCity(donor.donorProfile?.city);
}
function safeConversation(c) {
  return { id: c.id, managerId: c.managerId, donorId: c.donorId, branchId: c.branchId,
    managerName: c.manager.name, donorName: c.donor.name,
    branchName: c.branch.name, city: c.branch.city.trim(), updatedAt: c.updatedAt };
}
function fail(res, error) {
  return res.status(error.status || 503).json({ success: false,
    message: error.status ? error.message : 'Chat database is unavailable. Please try again.' });
}
const route = fn => async (req, res, next) => { try { await fn(req, res, next); } catch (error) { fail(res, error); } };

// The shared middleware supports offline fallback; chat deliberately requires PostgreSQL.
router.use(authenticateToken, route(async (req, res, next) => {
  if (req.user.scope) throw issue('A regular application session is required', 401);
  const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: personSelect });
  if (!user) throw issue('Authenticated account not found', 401);
  if (!user.isActive || ![...managers, 'donor'].includes(user.role)) throw issue('Active manager or donor access required');
  if (managers.includes(user.role) && !assigned(user)) throw issue('A branch with a city must be assigned to your account');
  req.chatUser = user;
  // Explicit next: route wrapper also serves as fail-closed authorization middleware.
  next();
}));

// A small process-local attempt limiter; no credentials or tokens are retained.
const attempts = new Map();
router.post('/manager/reauth', route(async (req, res) => {
  if (!managers.includes(req.chatUser.role)) throw issue('Manager access required');
  const now = Date.now();
  for (const [id, entry] of attempts) if (entry.until <= now) attempts.delete(id);
  const entry = attempts.get(req.user.id) || { count: 0, until: now + 15 * 60 * 1000 };
  if (entry.count >= 5) throw issue('Too many verification attempts. Try again in 15 minutes.', 429);
  entry.count++; attempts.set(req.user.id, entry);
  const { email, password } = req.body || {};
  if (typeof email !== 'string' || typeof password !== 'string' || !email.trim() || !password) {
    throw issue('Email and password are required', 400);
  }
  const user = await prisma.user.findUnique({ where: { id: req.user.id }, include: { branch: true } });
  if (!assigned(user)) throw issue('An active manager with an assigned branch is required');
  const ownEmail = email.trim().toLowerCase() === user.email.trim().toLowerCase();
  const validPassword = await bcrypt.compare(password, user.password).catch(() => false);
  if (!ownEmail || !validPassword) throw issue('Invalid manager email or password', 401);
  attempts.delete(user.id);
  const token = jwt.sign({ userId: user.id, role: user.role, scope: 'manager_chat' }, CHAT_SECRET,
    { expiresIn: '15m', audience: 'lifelink-manager-chat' });
  res.json({ success: true, data: { token, expiresIn: 900 } });
}));

router.use(route(async (req, res, next) => {
  if (managers.includes(req.chatUser.role)) {
    try {
      const decoded = jwt.verify(req.headers['x-manager-chat-token'] || '', CHAT_SECRET,
        { audience: 'lifelink-manager-chat', algorithms: ['HS256'] });
      if (decoded.scope !== 'manager_chat' || decoded.userId !== req.user.id
          || decoded.role !== req.chatUser.role) throw new Error('Wrong chat scope or account');
    } catch (_) { throw issue('Manager chat verification expired or missing. Verify again.', 401); }
  }
  next();
}));

router.get('/manager/donors', route(async (req, res) => {
  if (!managers.includes(req.chatUser.role)) throw issue('Manager access required');
  const users = await prisma.user.findMany({ where: { role: 'donor', isActive: true, donorProfile: { isNot: null } },
    select: { id: true, name: true, donorProfile: { select: { city: true, bloodGroup: true } } }, orderBy: { id: 'asc' } });
  res.json({ success: true, data: users.filter(u => normalizeCity(u.donorProfile.city) === normalizeCity(req.chatUser.branch.city))
    .map(u => ({ userId: u.id, name: u.name, city: u.donorProfile.city.trim(), bloodGroup: u.donorProfile.bloodGroup })) });
}));

function accessible(c, user) {
  return c && (user.role === 'donor' ? c.donorId === user.id : c.managerId === user.id)
    && c.managerId === c.manager.id && c.donorId === c.donor.id
    && c.branchId === c.manager.branchId && eligible(c.manager, c.donor, c.branch);
}
router.get('/conversations', route(async (req, res) => {
  const user = req.chatUser;
  const conversations = await prisma.chatConversation.findMany({
    where: user.role === 'donor' ? { donorId: user.id } : { managerId: user.id },
    include: conversationInclude, orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }] });
  res.json({ success: true, data: conversations.filter(c => accessible(c, user)).map(safeConversation) });
}));

// Lock authorization records for writes so reassignment/deactivation/city edits cannot race a message.
async function lockPeople(tx, ids) {
  for (const id of [...new Set(ids)].sort()) {
    await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${id} FOR SHARE`;
    await tx.$queryRaw`SELECT "id" FROM "DonorProfile" WHERE "userId" = ${id} FOR SHARE`;
  }
}
async function owned(tx, id, requester, lock = false) {
  let c = await tx.chatConversation.findUnique({ where: { id }, include: conversationInclude });
  if (!c || (requester.role === 'donor' ? c.donorId !== requester.id : c.managerId !== requester.id)) {
    throw issue('Conversation not found', 404);
  }
  if (lock) {
    await lockPeople(tx, [c.managerId, c.donorId]);
    await tx.$queryRaw`SELECT "id" FROM "BloodBankBranch" WHERE "id" = ${c.branchId} FOR SHARE`;
    c = await tx.chatConversation.findUnique({ where: { id }, include: conversationInclude });
  }
  if (!accessible(c, requester)) throw issue('Conversation is no longer authorized for this city or branch');
  return c;
}
router.post('/conversations', route(async (req, res) => {
  const body = req.body || {};
  const isDonor = req.chatUser.role === 'donor';
  if (Object.keys(body).some(k => k !== 'donorId') || (isDonor && Object.keys(body).length)) {
    throw issue('Only managers may supply a donorId; other identity fields are forbidden', 400);
  }
  if (!isDonor && (typeof body.donorId !== 'string' || !body.donorId)) throw issue('donorId is required', 400);
  const conversation = await prisma.$transaction(async tx => {
    let manager = req.chatUser;
    let donor = isDonor ? req.chatUser : await tx.user.findUnique({ where: { id: body.donorId }, select: personSelect });
    if (isDonor) {
      // Reuse the most recently active eligible conversation before selecting a new manager.
      const existing = await tx.chatConversation.findMany({ where: { donorId: donor.id }, include: conversationInclude,
        orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }] });
      const valid = existing.find(c => accessible(c, donor));
      if (valid) return safeConversation(await owned(tx, valid.id, donor, true));
      const candidates = await tx.user.findMany({ where: { role: 'manager', isActive: true, branchId: { not: null } },
        select: personSelect, orderBy: [{ branchId: 'asc' }, { id: 'asc' }] });
      manager = candidates.find(m => eligible(m, donor));
      if (!manager) throw issue('No Blood Bank Manager is currently available for your city.', 404);
    }
    if (!donor || !manager) throw issue('Eligible donor not found', 404);
    await lockPeople(tx, [manager.id, donor.id]);
    manager = await tx.user.findUnique({ where: { id: manager.id }, select: personSelect });
    donor = await tx.user.findUnique({ where: { id: donor.id }, select: personSelect });
    if (!manager?.branchId) throw issue('Manager branch is unavailable');
    await tx.$queryRaw`SELECT "id" FROM "BloodBankBranch" WHERE "id" = ${manager.branchId} FOR SHARE`;
    manager = await tx.user.findUnique({ where: { id: manager.id }, select: personSelect });
    if (!eligible(manager, donor)) throw issue('Donor and manager must be active and in the same city');
    const key = { managerId: manager.id, donorId: donor.id, branchId: manager.branchId };
    const c = await tx.chatConversation.upsert({ where: { managerId_donorId_branchId: key },
      create: key, update: {}, include: conversationInclude });
    return safeConversation(c);
  });
  res.json({ success: true, data: conversation });
}));

router.get('/conversations/:id/messages', route(async (req, res) => {
  await owned(prisma, req.params.id, req.chatUser);
  const before = req.query.before;
  if (before !== undefined && typeof before !== 'string') throw issue('Invalid message cursor', 400);
  if (before) {
    const cursor = await prisma.chatMessage.findUnique({ where: { id: before }, select: messageSelect });
    if (!cursor || cursor.conversationId !== req.params.id) throw issue('Invalid message cursor', 400);
  }
  const messages = await prisma.chatMessage.findMany({ where: { conversationId: req.params.id },
    select: messageSelect, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 100,
    ...(before ? { cursor: { id: before }, skip: 1 } : {}) });
  res.json({ success: true, data: messages.reverse() });
}));
router.post('/conversations/:id/messages', route(async (req, res) => {
  const body = req.body || {};
  if (Object.keys(body).some(k => k !== 'message')) throw issue('Only message text may be supplied', 400);
  const text = typeof body.message === 'string' ? body.message.trim() : '';
  if (!text || text.length > 2000) throw issue('Message must contain 1–2000 characters', 400);
  const message = await prisma.$transaction(async tx => {
    await owned(tx, req.params.id, req.chatUser, true);
    const result = await tx.chatMessage.create({ data: { conversationId: req.params.id, senderId: req.user.id, message: text }, select: messageSelect });
    await tx.chatConversation.update({ where: { id: req.params.id }, data: { updatedAt: new Date() } });
    return result;
  });
  res.status(201).json({ success: true, data: message });
}));
router.patch('/messages/:id/read', route(async (req, res) => {
  const result = await prisma.$transaction(async tx => {
    const message = await tx.chatMessage.findUnique({ where: { id: req.params.id }, select: messageSelect });
    if (!message) throw issue('Message not found', 404);
    await owned(tx, message.conversationId, req.chatUser, true);
    if (message.senderId === req.user.id) throw issue('Only the recipient can mark a message read');
    return tx.chatMessage.update({ where: { id: message.id }, data: { isRead: true }, select: messageSelect });
  });
  res.json({ success: true, data: result });
}));
module.exports = router;
