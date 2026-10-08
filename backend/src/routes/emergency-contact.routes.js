const express = require('express');
const { prisma } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');
const { validatePhone } = require('../utils/validation');
const router = express.Router();
const fields = ['fullName', 'relationship', 'phone', 'alternatePhone', 'address', 'isPrimary'];

// Canonical digits: remove punctuation/+; 00 international prefix becomes country
// code; Sri Lankan domestic 0XXXXXXXXX becomes 94XXXXXXXXX.
function normalizePhone(value) {
  let digits = value.replace(/[^0-9]/g, '');
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (/^0[0-9]{9}$/.test(digits)) digits = `94${digits.slice(1)}`;
  return digits;
}
function validate(body, creating) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return { error: 'A JSON object is required' };
  if (Object.keys(body).some(key => !fields.includes(key))) return { error: 'Only contact fields may be supplied' };
  const data = {};
  for (const field of fields) {
    if (!Object.hasOwn(body, field)) {
      if (creating && ['fullName', 'relationship', 'phone'].includes(field)) return { error: `${field} is required` };
      continue;
    }
    const value = body[field];
    if (field === 'isPrimary') {
      if (typeof value !== 'boolean') return { error: 'isPrimary must be a boolean' };
      data[field] = value;
    } else if (['alternatePhone', 'address'].includes(field) && value === null) {
      data[field] = null;
    } else {
      if (typeof value !== 'string' || !value.trim()) return { error: `${field} cannot be empty` };
      if (value.trim().length > (field === 'address' ? 1000 : 200)) return { error: `${field} is too long` };
      if (field === 'phone' || field === 'alternatePhone') {
        const checked = validatePhone(value);
        if (!checked.valid) return { error: `${field}: ${checked.message}` };
        data[field] = normalizePhone(checked.value);
        if (!/^[0-9]{9,15}$/.test(data[field])) return { error: `${field} must contain 9-15 digits after normalization` };
      } else data[field] = value.trim();
    }
  }
  return Object.keys(data).length ? { data } : { error: 'Supply at least one contact field' };
}
function fail(res, error) {
  if (error.code === 'P2002') return res.status(409).json({ success: false, message: 'A contact with that phone already exists, or a primary contact conflict occurred' });
  if (error.code === 'P2025' || error.contactMissing) return res.status(404).json({ success: false, message: 'Emergency contact not found' });
  console.error('Emergency contact operation failed:', error.message);
  return res.status(500).json({ success: false, message: 'Unable to complete emergency contact operation' });
}
router.use(authenticateToken);
router.use(async (req, res, next) => {
  try {
    if (!prisma) throw new Error('Prisma unavailable');
    const user = typeof req.user?.id === 'string' ? await prisma.user.findUnique({ where: { id: req.user.id } }) : null;
    if (!user) return res.status(401).json({ success: false, message: 'Authenticated account not found' });
    if (!user.isActive) return res.status(403).json({ success: false, message: 'Account is deactivated' });
    next();
  } catch (error) { return fail(res, error); }
});
const owned = req => ({ userId: req.user.id, id: req.params.id });
function missing() { return Object.assign(new Error('Contact not found'), { contactMissing: true }); }
// All writes for a user take the same row lock. The partial unique index remains
// a second safeguard, including for writes outside this router.
async function write(req, operation) {
  return prisma.$transaction(async tx => {
    await tx.$queryRaw`SELECT "id" FROM "public"."User" WHERE "id" = ${req.user.id} FOR UPDATE`;
    return operation(tx);
  });
}
router.post('/', async (req, res) => {
  const { data, error } = validate(req.body, true);
  if (error) return res.status(400).json({ success: false, message: error });
  try {
    const contact = await write(req, async tx => {
      if (data.isPrimary) await tx.emergencyContact.updateMany({ where: { userId: req.user.id, isPrimary: true }, data: { isPrimary: false } });
      return tx.emergencyContact.create({ data: { ...data, userId: req.user.id } });
    });
    res.status(201).json({ success: true, data: contact, message: 'Emergency contact created' });
  } catch (error) { return fail(res, error); }
});
router.get('/', async (req, res) => {
  try {
    const data = await prisma.emergencyContact.findMany({ where: { userId: req.user.id }, orderBy: [{ isPrimary: 'desc' }, { createdAt: 'desc' }, { id: 'asc' }] });
    res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});
router.get('/:id', async (req, res) => {
  try {
    const data = await prisma.emergencyContact.findFirst({ where: owned(req) });
    if (!data) throw missing();
    res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});
router.patch('/:id', async (req, res) => {
  try {
    const contact = await write(req, async tx => {
      if (!await tx.emergencyContact.findFirst({ where: owned(req) })) throw missing();
      const { data, error } = validate(req.body, false);
      if (error) return { validationError: error };
      if (data.isPrimary) await tx.emergencyContact.updateMany({ where: { userId: req.user.id, isPrimary: true }, data: { isPrimary: false } });
      return tx.emergencyContact.update({ where: owned(req), data });
    });
    if (contact.validationError) return res.status(400).json({ success: false, message: contact.validationError });
    res.json({ success: true, data: contact, message: 'Emergency contact updated' });
  } catch (error) { return fail(res, error); }
});
router.delete('/:id', async (req, res) => {
  try {
    await write(req, async tx => {
      const result = await tx.emergencyContact.deleteMany({ where: owned(req) });
      if (!result.count) throw missing();
    });
    res.json({ success: true, message: 'Emergency contact deleted' });
  } catch (error) { return fail(res, error); }
});
module.exports = router;
