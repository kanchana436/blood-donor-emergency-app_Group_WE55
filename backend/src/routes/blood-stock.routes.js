const express = require('express');
const { prisma } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');
const { authorizeBloodStock } = require('../middleware/blood-stock-auth.middleware');

const { notifyLocalUsersOfBloodStockUpdate } = require('../services/blood-stock-notification.service');

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
  if (error.status) return res.status(error.status).json({ success: false, message: error.message });
  if (error.code === 'P2002') {
    return res.status(409).json({ success: false, message: 'Stock already exists for this blood group and location' });
  }
  if (error.code === 'P2025') {
    return res.status(404).json({ success: false, message: 'Blood stock not found' });
  }
  console.error('Blood stock database error:', error.message);
  return res.status(500).json({ success: false, message: 'Unable to complete blood stock operation' });
}

function issue(message, status) { return Object.assign(new Error(message), { status }); }

async function managerInTransaction(tx, req) {
  // Assignment/deactivation cannot race a stock write. Stock rows are locked below.
  await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${req.user.id} FOR SHARE`;
  const manager = await tx.user.findUnique({ where: { id: req.user.id }, include: { branch: true } });
  if (!manager?.isActive || !['manager', 'admin'].includes(manager.role) || !manager.branch
      || !manager.branch.name.trim() || !manager.branch.city.trim()) {
    throw issue('An active coordinator with an assigned branch and city is required', 403);
  }
  return manager;
}
function branchData(data, manager, previousStock) {
  if (data.location !== undefined && data.location !== manager.branch.name.trim() && data.location !== previousStock?.location) {
    throw issue('Location must match your assigned branch; stock cannot be reassigned', 403);
  }
  return { ...data, location: previousStock?.location ?? manager.branch.name.trim(), branchId: manager.branchId };
}
async function ownedStock(tx, id, manager) {
  await tx.$queryRaw`SELECT "id" FROM "BloodStock" WHERE "id" = ${id} FOR UPDATE`;
  const stock = await tx.bloodStock.findUnique({ where: { id } });
  if (!stock) throw issue('Blood stock not found', 404);
  if (stock.branchId !== manager.branchId) throw issue('This stock does not belong to your assigned branch', 403);
  return stock;
}

// Branch identity comes from the authenticated account, including on an empty inventory.
router.get('/branch', (req, res) => {
  const { id, name, city } = req.stockManager.branch;
  return res.json({ success: true, data: { id, name: name.trim(), city: city.trim() } });
});

router.post('/', async (req, res) => {
  const { data, error } = validate(req.body, true);
  if (error) return res.status(400).json({ success: false, message: error });
  try {
    const result = await prisma.$transaction(async tx => {
      const manager = await managerInTransaction(tx, req);
      const stock = await tx.bloodStock.create({ data: branchData(data, manager) });
      const notificationsSent = await notifyLocalUsersOfBloodStockUpdate(tx, { stock, manager });
      return { stock, notificationsSent };
    });
    return res.status(201).json({ success: true, data: { ...result.stock, notificationsSent: result.notificationsSent },
      notificationsSent: result.notificationsSent, message: 'Blood stock created' });
  } catch (error) { return fail(res, error); }
});

router.get('/', async (req, res) => {
  const bloodGroup = typeof req.query.bloodGroup === 'string' ? req.query.bloodGroup.trim() : req.query.bloodGroup;
  if (bloodGroup !== undefined && !groups.includes(bloodGroup)) {
    return res.status(400).json({ success: false, message: 'Invalid blood group filter' });
  }
  try {
    const data = await prisma.bloodStock.findMany({
      where: { branchId: req.stockManager.branchId, ...(bloodGroup ? { bloodGroup } : {}) },
      orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }],
    });
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});

router.get('/:id', async (req, res) => {
  try {
    const data = await prisma.bloodStock.findUnique({ where: { id: req.params.id } });
    if (!data) return res.status(404).json({ success: false, message: 'Blood stock not found' });
    if (data.branchId !== req.stockManager.branchId) throw issue('This stock does not belong to your assigned branch', 403);
    return res.json({ success: true, data });
  } catch (error) { return fail(res, error); }
});

router.patch('/:id', async (req, res) => {
  const { data, error } = validate(req.body, false);
  if (error) return res.status(400).json({ success: false, message: error });
  try {
    const result = await prisma.$transaction(async tx => {
      const manager = await managerInTransaction(tx, req);
      const previousStock = await ownedStock(tx, req.params.id, manager);
      const stock = await tx.bloodStock.update({ where: { id: previousStock.id }, data: branchData(data, manager, previousStock) });
      const notificationsSent = await notifyLocalUsersOfBloodStockUpdate(tx, { stock, previousStock, manager });
      return { stock, notificationsSent };
    });
    return res.json({ success: true, data: { ...result.stock, notificationsSent: result.notificationsSent },
      notificationsSent: result.notificationsSent, message: 'Blood stock updated' });
  } catch (error) { return fail(res, error); }
});

router.delete('/:id', async (req, res) => {
  try {
    await prisma.$transaction(async tx => {
      const manager = await managerInTransaction(tx, req);
      await ownedStock(tx, req.params.id, manager);
      await tx.bloodStock.delete({ where: { id: req.params.id } });
    });
    return res.json({ success: true, message: 'Blood stock deleted' });
  } catch (error) { return fail(res, error); }
});

module.exports = router;
