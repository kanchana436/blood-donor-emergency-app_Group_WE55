const express = require('express');
const { prisma } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');
const { authorizeBloodStock } = require('../middleware/blood-stock-auth.middleware');

const router = express.Router();
const groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const statuses = ['Available', 'Unavailable', 'Reserved'];
const fields = ['bloodGroup', 'availableUnits', 'location', 'status'];

router.use(authenticateToken, authorizeBloodStock);

function validate(body, creating) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'A JSON object is required' };
  }
  if (Object.keys(body).some(key => !fields.includes(key))) {
    return { error: 'Only bloodGroup, availableUnits, location and status may be supplied' };
  }
  const data = {};
  for (const field of fields) {
    if (!Object.hasOwn(body, field)) {
      if (creating) return { error: `${field} is required` };
      continue;
    }
    data[field] = typeof body[field] === 'string' ? body[field].trim() : body[field];
  }
  if (!Object.keys(data).length) return { error: 'Supply at least one stock field to update' };
  if ('bloodGroup' in data && !groups.includes(data.bloodGroup)) {
    return { error: 'bloodGroup must be A+, A-, B+, B-, AB+, AB-, O+ or O-' };
  }
  if ('availableUnits' in data && (!Number.isInteger(data.availableUnits)
      || data.availableUnits < (creating ? 1 : 0) || data.availableUnits > 2147483647)) {
    return { error: `availableUnits must be an integer between ${creating ? 1 : 0} and 2147483647` };
  }
  if ('location' in data && (typeof data.location !== 'string' || !data.location.length)) {
    return { error: 'location cannot be empty' };
  }
  if ('status' in data && !statuses.includes(data.status)) {
    return { error: 'status must be Available, Unavailable or Reserved' };
  }
  return { data };
}

function fail(res, error) {
  if (error.code === 'P2002') {
    return res.status(409).json({ success: false, message: 'Stock already exists for this blood group and location' });
  }
  if (error.code === 'P2025') {
    return res.status(404).json({ success: false, message: 'Blood stock not found' });
  }
  console.error('Blood stock database error:', error.message);
  return res.status(500).json({ success: false, message: 'Unable to complete blood stock operation' });
}

router.post('/', async (req, res) => {
  const { data, error } = validate(req.body, true);
  if (error) return res.status(400).json({ success: false, message: error });
  try {
    const stock = await prisma.bloodStock.create({ data });
    return res.status(201).json({ success: true, data: stock, message: 'Blood stock created' });
  } catch (error) { return fail(res, error); }
});

router.get('/', async (req, res) => {
  const bloodGroup = typeof req.query.bloodGroup === 'string' ? req.query.bloodGroup.trim() : req.query.bloodGroup;
  if (bloodGroup !== undefined && !groups.includes(bloodGroup)) {
    return res.status(400).json({ success: false, message: 'Invalid blood group filter' });
  }
  try {
    const data = await prisma.bloodStock.findMany({
      where: bloodGroup ? { bloodGroup } : {},
      orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }],
    });
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});

router.get('/:id', async (req, res) => {
  try {
    const data = await prisma.bloodStock.findUnique({ where: { id: req.params.id } });
    if (!data) return res.status(404).json({ success: false, message: 'Blood stock not found' });
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});

router.patch('/:id', async (req, res) => {
  const { data, error } = validate(req.body, false);
  if (error) return res.status(400).json({ success: false, message: error });
  try {
    const stock = await prisma.bloodStock.update({ where: { id: req.params.id }, data });
    return res.json({ success: true, data: stock, message: 'Blood stock updated' });
  } catch (error) { return fail(res, error); }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.bloodStock.delete({ where: { id: req.params.id } });
    return res.json({ success: true, message: 'Blood stock deleted' });
  } catch (error) { return fail(res, error); }
});

module.exports = router;
