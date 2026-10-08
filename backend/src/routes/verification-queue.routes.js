const express = require('express');
const { prisma } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');
const router = express.Router();
const statuses = ['Pending', 'Approved', 'Rejected'];
const required = ['verificationType', 'title'];
const optional = ['referenceId', 'description', 'managerNote'];
function fail(res, error) {
  if (error.code === 'P2025') return res.status(404).json({ success: false, message: 'Verification not found' });
  if (error.code === 'P2003') return res.status(400).json({ success: false, message: 'Referenced user does not exist' });
  console.error('Verification queue error:', error.message);
  return res.status(500).json({ success: false, message: 'Unable to complete verification queue operation' });
}
router.use(authenticateToken, async (req, res, next) => {
  try {
    if (!prisma) throw new Error('Prisma unavailable');
    const user = req.user?.id ? await prisma.user.findUnique({ where: { id: req.user.id } }) : null;
    if (!user) return res.status(401).json({ success: false, message: 'Authenticated account not found' });
    if (!user.isActive) return res.status(403).json({ success: false, message: 'An active account is required' });
    req.dbUser = user;
    next();
  } catch (error) { fail(res, error); }
});
function validate(body, creating, reviewerId) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return { error: 'A JSON object is required' };
  if (Object.keys(body).some(key => ![...required, ...optional, 'status'].includes(key))) return { error: 'Unknown or server-managed field supplied' };
  const data = {};
  for (const field of [...required, ...optional]) {
    if (!Object.hasOwn(body, field)) {
      if (creating && required.includes(field)) return { error: `${field} is required` };
      continue;
    }
    const value = body[field];
    if (optional.includes(field) && value === null) { data[field] = null; continue; }
    if (typeof value !== 'string' || value.length > 10000 || (required.includes(field) && !value.trim())) return { error: `${field} must be a valid string (maximum 10000 characters)` };
    data[field] = value.trim() || null;
  }
  if (Object.hasOwn(body, 'status') || creating) {
    data.status = Object.hasOwn(body, 'status') ? body.status : 'Pending';
    if (!statuses.includes(data.status)) return { error: 'status must be Pending, Approved or Rejected' };
    data.reviewedById = data.status === 'Pending' ? null : reviewerId;
    data.reviewedAt = data.status === 'Pending' ? null : new Date();
  }
  if (!Object.keys(data).length) return { error: 'Supply at least one verification field' };
  return { data };
}
function requireDonor(req, res, next) {
  if (req.dbUser.role !== 'donor') return res.status(403).json({ success: false, message: 'A donor account is required' });
  next();
}
router.post('/', requireDonor, async (req, res) => {
  // Submission identity, type, title and status are owned by the server.
  if (req.body && (typeof req.body !== 'object' || Array.isArray(req.body) || Object.keys(req.body).length)) {
    return res.status(400).json({ success: false, message: 'Submit an empty JSON object; verification fields are server-managed' });
  }
  try {
    const data = await prisma.$transaction(async tx => {
      // Lock this donor's existing row to serialize concurrent submissions without a schema change.
      await tx.$queryRaw`SELECT "id" FROM "public"."User" WHERE "id" = ${req.user.id} FOR UPDATE`;
      const pending = await tx.verificationQueue.findFirst({ where: {
        submittedById: req.user.id, verificationType: 'DonorVerification', status: 'Pending',
      } });
      if (pending) return null;
      return tx.verificationQueue.create({ data: {
        submittedById: req.user.id, verificationType: 'DonorVerification',
        title: 'Donor Profile Verification', status: 'Pending',
      } });
    });
    if (!data) return res.status(409).json({ success: false, message: 'A verification request is already pending.' });
    return res.status(201).json({ success: true, data });
  } catch (error) { return fail(res, error); }
});
// Must precede /:id and manager-only middleware.
router.get('/mine', requireDonor, async (req, res) => {
  try {
    const data = await prisma.verificationQueue.findMany({
      where: { submittedById: req.user.id, verificationType: 'DonorVerification' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});
router.use((req, res, next) => {
  if (!['manager', 'admin'].includes(req.dbUser.role)) return res.status(403).json({ success: false, message: 'A manager or admin account is required' });
  next();
});
router.get('/', async (req, res) => {
  const status = req.query.status;
  if (status !== undefined && !statuses.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status filter' });
  try { return res.json({ success: true, data: await prisma.verificationQueue.findMany({ where: status ? { status } : {}, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }] }) }); }
  catch (error) { return fail(res, error); }
});
router.get('/:id', async (req, res) => {
  try {
    const data = await prisma.verificationQueue.findUnique({ where: { id: req.params.id } });
    if (!data) return res.status(404).json({ success: false, message: 'Verification not found' });
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});
router.patch('/:id', async (req, res) => {
  const { data, error } = validate(req.body, false, req.user.id);
  if (error) return res.status(400).json({ success: false, message: error });
  try { return res.json({ success: true, data: await prisma.verificationQueue.update({ where: { id: req.params.id }, data }) }); }
  catch (error) { return fail(res, error); }
});
router.delete('/:id', async (req, res) => {
  try { await prisma.verificationQueue.delete({ where: { id: req.params.id } }); return res.json({ success: true, message: 'Verification deleted' }); }
  catch (error) { return fail(res, error); }
});
module.exports = router;
