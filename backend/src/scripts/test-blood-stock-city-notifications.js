// Offline HTTP integration tests use real routes/JWT middleware with isolated persistence.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
let users, stocks, notifications, branches, failNotifications;
const clone = value => structuredClone(value);
function matches(row, where = {}) {
  return Object.entries(where).every(([key, value]) => {
    if (key === 'donorProfile') return value.isNot === null ? row.donorProfile != null : false;
    if (value?.in) return value.in.includes(row[key]);
    if (value && Object.hasOwn(value, 'not')) return row[key] !== value.not;
    return row[key] === value;
  });
}
function duplicate(data, except) {
  return stocks.some(row => row.id !== except && row.bloodGroup === data.bloodGroup
    && row.location === data.location);
}
const prisma = {
  user: {
    findUnique: async ({ where, include }) => {
      const user = users.find(row => matches(row, where));
      return user ? clone({ ...user, ...(include?.branch ? { branch: branches.find(b => b.id === user.branchId) || null } : {}) }) : null;
    },
    findMany: async ({ where }) => clone(users.filter(row => matches(row, where))),
  },
  bloodStock: {
    findUnique: async ({ where }) => clone(stocks.find(row => matches(row, where)) || null),
    findMany: async ({ where }) => clone(stocks.filter(row => matches(row, where))),
    create: async ({ data }) => {
      if (duplicate(data)) throw Object.assign(new Error('Duplicate'), { code: 'P2002' });
      const row = { id: `stock-${stocks.length + 1}`, createdAt: new Date(), updatedAt: new Date(), ...clone(data) };
      stocks.push(row); return clone(row);
    },
    update: async ({ where, data }) => {
      const row = stocks.find(row => matches(row, where));
      if (duplicate({ ...row, ...data }, row.id)) throw Object.assign(new Error('Duplicate'), { code: 'P2002' });
      Object.assign(row, clone(data), { updatedAt: new Date() }); return clone(row);
    },
    delete: async ({ where }) => stocks.splice(stocks.findIndex(row => matches(row, where)), 1)[0],
  },
  notification: { createMany: async ({ data }) => {
    if (failNotifications) throw new Error('Injected notification failure');
    notifications.push(...clone(data)); return { count: data.length };
  } },
  $queryRaw: async () => [],
  $transaction: async operation => {
    const before = clone({ stocks, notifications });
    try { return await operation(prisma); }
    catch (error) { ({ stocks, notifications } = before); throw error; }
  },
};
require.cache[require.resolve('../prisma')] = { exports: { prisma, db: { users: [] } } };
const router = require('../routes/blood-stock.routes');
const secret = process.env.JWT_SECRET || 'lifelink_secret_2026';
const token = (id, role = 'manager') => jwt.sign({ id, role }, secret, { expiresIn: '5m' });
function reset() {
  branches = [{ id: 'colombo', name: 'National Blood Bank', city: ' Colombo ' }, { id: 'kandy', name: 'Kandy Hospital', city: 'Kandy' }];
  users = [
    { id: 'manager', role: 'manager', isActive: true, branchId: 'colombo', donorProfile: { city: 'Colombo' } },
    { id: 'other-manager', role: 'manager', isActive: true, branchId: 'kandy' },
    { id: 'local-donor', role: 'donor', isActive: true, donorProfile: { city: ' colombo ', bloodGroup: 'AB-' } },
    { id: 'local-recipient', role: 'recipient', isActive: true, donorProfile: { city: 'COLOMBO' } },
    { id: 'remote-donor', role: 'donor', isActive: true, donorProfile: { city: 'Kandy' } },
    { id: 'remote-recipient', role: 'recipient', isActive: true, donorProfile: { city: 'Kandy' } },
    { id: 'inactive', role: 'donor', isActive: false, donorProfile: { city: 'Colombo' } },
    { id: 'inactive-recipient', role: 'recipient', isActive: false, donorProfile: { city: 'Colombo' } },
    { id: 'admin', role: 'admin', isActive: true, branchId: 'colombo', donorProfile: { city: 'Colombo' } },
    { id: 'no-profile', role: 'recipient', isActive: true },
    { id: 'blank-city', role: 'donor', isActive: true, donorProfile: { city: ' ' } },
    { id: 'address-city', role: 'donor', isActive: true, donorProfile: { city: 'Colombo 03 Hospital Road' } },
    { id: 'unassigned', role: 'manager', isActive: true },
  ];
  stocks = [{ id: 'own', bloodGroup: 'O+', availableUnits: 3, status: 'Unavailable', branchId: 'colombo', location: 'National Blood Bank', createdAt: new Date(), updatedAt: new Date() },
    { id: 'foreign', bloodGroup: 'O+', availableUnits: 5, status: 'Available', branchId: 'kandy', location: 'Kandy Hospital' },
    { id: 'legacy', bloodGroup: 'B+', availableUnits: 5, status: 'Available', branchId: null, location: 'Unassigned bank' }];
  notifications = []; failNotifications = false;
}
test('city-based blood stock HTTP integration', async t => {
  const app = express(); app.use(express.json()); app.use('/api/blood-stock', router);
  const server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve));
  async function request(status, method, path = '', body, id = 'manager', role) {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/blood-stock${path}`, {
      method, headers: { 'Content-Type': 'application/json', ...(id ? { Authorization: `Bearer ${token(id, role)}` } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const json = await response.json(); assert.equal(response.status, status, JSON.stringify(json)); return json;
  }
  async function scenario(name, fn) { await t.test(name, async () => { reset(); await fn(); }); }
  const changed = { availableUnits: 15, status: 'Available' };
  try {
    await scenario('own branch update targets same-city donor and recipient using normalized exact city', async () => {
      const result = await request(200, 'PATCH', '/own', changed);
      assert.equal(result.data.availableUnits, 15); assert.equal(result.notificationsSent, 2);
      assert.deepEqual(notifications.map(n => n.userId).sort(), ['local-donor', 'local-recipient']);
      for (const n of notifications) {
        assert.equal(n.type, 'BLOOD_STOCK_UPDATE'); assert.equal(n.title, 'O+ Blood Stock Update');
        assert.equal(n.message, 'O+ blood is now Available at National Blood Bank - Colombo. 15 units currently available.');
        assert.equal(n.isRead, false);
      }
      assert.ok(!JSON.stringify(result).includes('local-donor'));
    });
    for (const id of ['remote-donor', 'remote-recipient', 'inactive', 'inactive-recipient', 'manager', 'admin', 'no-profile', 'blank-city', 'address-city']) {
      await scenario(`excludes ${id}`, async () => {
        await request(200, 'PATCH', '/own', changed); assert.ok(!notifications.some(n => n.userId === id));
      });
    }
    await scenario('same-value save creates no notification', async () => {
      const result = await request(200, 'PATCH', '/own', { bloodGroup: 'O+', availableUnits: 3, status: 'Unavailable', location: ' National Blood Bank ' });
      assert.equal(result.notificationsSent, 0); assert.equal(notifications.length, 0);
    });
    for (const body of [{ availableUnits: 4 }, { status: 'Reserved' }, { bloodGroup: 'AB-' }]) {
      await scenario(`meaningful update ${JSON.stringify(body)}`, async () => {
        const result = await request(200, 'PATCH', '/own', body); assert.equal(result.notificationsSent, 2);
        assert.ok(notifications.every(n => n.title.startsWith(result.data.bloodGroup)));
      });
    }
    await scenario('repeated save sends once', async () => {
      await request(200, 'PATCH', '/own', changed);
      const result = await request(200, 'PATCH', '/own', changed);
      assert.equal(result.notificationsSent, 0); assert.equal(notifications.length, 2);
    });
    await scenario('other branch read/update/delete and reassignment are forbidden', async () => {
      for (const method of ['GET', 'PATCH', 'DELETE']) await request(403, method, '/foreign', method === 'PATCH' ? changed : undefined);
      await request(403, 'PATCH', '/own', { location: 'Kandy Hospital' });
      await request(400, 'PATCH', '/own', { branchId: 'kandy' });
      await request(403, 'POST', '', { bloodGroup: 'AB-', availableUnits: 5, status: 'Available', location: 'Kandy Hospital' });
      const list = await request(200, 'GET'); assert.deepEqual(list.data.map(s => s.id), ['own']);
      assert.equal(stocks.find(s => s.id === 'foreign').availableUnits, 5); assert.equal(notifications.length, 0);
    });
    await scenario('unassigned managers and stock fail closed', async () => {
      await request(403, 'GET', '', undefined, 'unassigned'); await request(403, 'PATCH', '/legacy', changed);
    });
    await scenario('legacy assigned location is preserved', async () => {
      const stock = stocks.find(s => s.id === 'legacy'); stock.branchId = 'colombo';
      const result = await request(200, 'PATCH', '/legacy', changed);
      assert.equal(result.data.location, 'Unassigned bank'); assert.equal(result.notificationsSent, 2);
      assert.ok(notifications[0].message.includes('National Blood Bank - Colombo'));
    });
    await scenario('creates available stock and notifies; reserved/unavailable creation is silent', async () => {
      for (const [bloodGroup, status, count] of [['AB-', 'Available', 2], ['A-', 'Unavailable', 0], ['B-', 'Reserved', 0]]) {
        const result = await request(201, 'POST', '', { bloodGroup, status, availableUnits: 10, location: ' National Blood Bank ' });
        assert.equal(result.notificationsSent, count); assert.equal(result.data.branchId, 'colombo');
      }
    });
    await scenario('delete is silent and missing records return 404', async () => {
      await request(200, 'DELETE', '/own'); assert.equal(notifications.length, 0);
      for (const method of ['GET', 'PATCH', 'DELETE']) await request(404, method, '/missing', method === 'PATCH' ? changed : undefined);
    });
    await scenario('notification insert failure rolls back update and create', async () => {
      failNotifications = true; await request(500, 'PATCH', '/own', changed);
      assert.equal(stocks.find(s => s.id === 'own').availableUnits, 3);
      await request(500, 'POST', '', { bloodGroup: 'AB-', availableUnits: 10, status: 'Available', location: 'National Blood Bank' });
      assert.equal(stocks.length, 3); assert.equal(notifications.length, 0);
    });
    await scenario('existing validation, duplicate checks, JWT and database roles remain enforced', async () => {
      await request(401, 'GET', '', undefined, null);
      await request(403, 'GET', '', undefined, 'local-donor', 'manager');
      users.find(u => u.id === 'manager').isActive = false; await request(403, 'GET');
      users.find(u => u.id === 'manager').isActive = true;
      for (const body of [{ availableUnits: -1 }, { availableUnits: 1.5 }, { availableUnits: '12' }, { bloodGroup: 'C+' }, { status: 'invalid' }, {}]) await request(400, 'PATCH', '/own', body);
      await request(409, 'POST', '', { bloodGroup: 'O+', availableUnits: 1, status: 'Available', location: 'National Blood Bank' });
      assert.equal(notifications.length, 0);
      const branch = await request(200, 'GET', '/branch'); assert.deepEqual(branch.data, { id: 'colombo', name: 'National Blood Bank', city: 'Colombo' });
    });
  } finally { await new Promise(resolve => server.close(resolve)); }
});
