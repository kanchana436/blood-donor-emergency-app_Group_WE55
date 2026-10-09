require('dotenv').config();
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

// Real PostgreSQL integration test. Only uniquely identified fixtures are removed.
const prisma = new PrismaClient();
const base = process.env.BLOOD_STOCK_TEST_URL || `http://127.0.0.1:${process.env.PORT || 5001}/api`;
const marker = `blood-stock-test-${randomUUID()}`;
const userIds = [];
const stockIds = [];
const branchIds = [];
let token;

async function request(method, path = '/blood-stock', body, auth = token) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(20000),
  });
  return { status: response.status, json: await response.json() };
}

async function expectStatus(status, method, path, body, auth) {
  const result = await request(method, path, body, auth);
  assert.equal(result.status, status, JSON.stringify(result.json));
  assert.equal(result.json.success, status < 400);
  return result.json;
}

async function run() {
  try {
    // Fail before creating fixtures if the additive schema hasn't been applied.
    await prisma.bloodStock.count();
    await prisma.bloodBankBranch.count();
    await prisma.user.findFirst({ select: { id: true, branchId: true } });
    await prisma.bloodStock.findFirst({ select: { id: true, branchId: true } });
    await prisma.notification.count();
    const branch = await prisma.bloodBankBranch.create({ data: { name: marker, city: marker } });
    branchIds.push(branch.id);
    for (const role of ['manager', 'donor']) {
      const user = await prisma.user.create({ data: {
        idNumber: `${marker}-${role}`, name: 'Blood Stock Test',
        email: `${marker}-${role}@example.invalid`, phone: '0770000000',
        password: '!integration-test-no-login!', role, isEmailVerified: true,
        ...(role === 'manager' ? { branchId: branchIds[0] } : {}),
      } });
      userIds.push(user.id);
    }
    await prisma.donorProfile.create({ data: { userId: userIds[1], bloodGroup: 'AB-', city: ` ${marker.toUpperCase()} ` } });
    const localRecipientIds = [userIds[1]];
    for (const fixture of [
      { key: 'local-recipient', role: 'recipient', city: marker },
      { key: 'remote-donor', role: 'donor', city: `${marker}-remote` },
      { key: 'remote-recipient', role: 'recipient', city: `${marker}-remote` },
      { key: 'inactive-donor', role: 'donor', city: marker, isActive: false },
      { key: 'inactive-recipient', role: 'recipient', city: marker, isActive: false },
      { key: 'no-city-recipient', role: 'recipient', city: null },
    ]) {
      const user = await prisma.user.create({ data: {
        idNumber: `${marker}-${fixture.key}`, name: 'City Notification Test',
        email: `${marker}-${fixture.key}@example.invalid`, phone: '0770000000',
        password: '!integration-test-no-login!', role: fixture.role, isActive: fixture.isActive !== false,
      } });
      userIds.push(user.id);
      if (fixture.city) await prisma.donorProfile.create({ data: { userId: user.id, bloodGroup: 'AB-', city: fixture.city } });
      if (fixture.key === 'local-recipient') localRecipientIds.push(user.id);
    }
    const secret = process.env.JWT_SECRET || 'lifelink_secret_2026';
    token = jwt.sign({ id: userIds[0], role: 'manager' }, secret, { expiresIn: '5m' });
    const donorToken = jwt.sign({ id: userIds[1], role: 'donor' }, secret, { expiresIn: '5m' });
    await expectStatus(401, 'GET', '/blood-stock', undefined, null);
    await expectStatus(401, 'GET', '/blood-stock', undefined, 'invalid-token');
    await expectStatus(403, 'GET', '/blood-stock', undefined, donorToken);
    const spoofedToken = jwt.sign({ id: userIds[1], role: 'manager' }, secret, { expiresIn: '5m' });
    await expectStatus(403, 'GET', '/blood-stock', undefined, spoofedToken);
    console.log('PASS: JWT and database role authorization');

    const body = { bloodGroup: 'O+', availableUnits: 12, location: marker, status: 'Available' };
    const created = await expectStatus(201, 'POST', '/blood-stock', body);
    stockIds.push(created.data.id);
    assert.equal(created.notificationsSent, 2);
    const path = `/blood-stock/${created.data.id}`;
    assert.equal((await prisma.bloodStock.findUnique({ where: { id: created.data.id } })).availableUnits, 12);
    const initialNotifications = await prisma.notification.findMany({ where: { userId: { in: userIds } } });
    assert.deepEqual(initialNotifications.map(n => n.userId).sort(), [...localRecipientIds].sort());
    assert.ok(initialNotifications.every(n => n.type === 'BLOOD_STOCK_UPDATE' && n.title === 'O+ Blood Stock Update'
      && n.message.includes(`${marker} - ${marker}`) && n.message.includes('12 units') && n.message.includes('Available')));
    console.log('PASS: Create persists and only active same-city donor/recipient receive notifications');
    const all = await expectStatus(200, 'GET', '/blood-stock');
    assert.ok(all.data.some(stock => stock.id === created.data.id));
    const filtered = await expectStatus(200, 'GET', '/blood-stock?bloodGroup=O%2B');
    assert.ok(filtered.data.some(stock => stock.id === created.data.id));
    assert.ok(filtered.data.every(stock => stock.bloodGroup === 'O+'));
    assert.equal((await expectStatus(200, 'GET', path)).data.location, marker);
    const foreignBranch = await prisma.bloodBankBranch.create({ data: { name: `${marker}-foreign`, city: `${marker}-remote` } });
    branchIds.push(foreignBranch.id);
    const foreign = await prisma.bloodStock.create({ data: { bloodGroup: 'O+', availableUnits: 5, status: 'Available', location: foreignBranch.name, branchId: foreignBranch.id } });
    stockIds.push(foreign.id);
    for (const method of ['GET', 'PATCH', 'DELETE']) await expectStatus(403, method, `/blood-stock/${foreign.id}`, method === 'PATCH' ? { availableUnits: 6 } : undefined);
    const scoped = await expectStatus(200, 'GET', '/blood-stock');
    assert.ok(!scoped.data.some(row => row.id === foreign.id));
    console.log('PASS: Read all, filter, read by ID and other branch access rejected');
    await expectStatus(409, 'POST', '/blood-stock', { ...body, location: `  ${marker}  ` });
    for (const invalid of [
      { availableUnits: -1 }, { availableUnits: 0 }, { availableUnits: 1.5 },
      { availableUnits: '12' }, { availableUnits: 2147483648 },
      { bloodGroup: 'C+' }, { location: '   ' }, { status: 'Invalid' },
    ]) await expectStatus(400, 'POST', '/blood-stock', { ...body, ...invalid });
    await expectStatus(400, 'PATCH', path, { availableUnits: -1 });
    await expectStatus(400, 'PATCH', path, { bloodGroup: 'C+' });
    await expectStatus(400, 'PATCH', path, {});
    console.log('PASS: Invalid groups, units, location, status and duplicate validation');

    const second = await expectStatus(201, 'POST', '/blood-stock', { ...body, bloodGroup: 'A-' });
    stockIds.push(second.data.id);
    await expectStatus(409, 'PATCH', `/blood-stock/${second.data.id}`, { bloodGroup: 'O+' });
    await expectStatus(403, 'PATCH', path, { location: `${marker}-updated` });
    const unchanged = await expectStatus(200, 'PATCH', path, body);
    assert.equal(unchanged.notificationsSent, 0);
    const updated = await expectStatus(200, 'PATCH', path,
      { availableUnits: 0, status: 'Unavailable', location: `  ${marker}  ` });
    assert.equal(updated.notificationsSent, 2);
    assert.equal(updated.data.availableUnits, 0);
    assert.equal(updated.data.location, marker);
    assert.ok(new Date(updated.data.updatedAt) >= new Date(created.data.updatedAt));
    assert.equal((await prisma.bloodStock.findUnique({ where: { id: created.data.id } })).status, 'Unavailable');
    // Row locking must prevent simultaneous identical saves from sending twice.
    const simultaneous = await Promise.all([
      expectStatus(200, 'PATCH', path, { availableUnits: 15 }),
      expectStatus(200, 'PATCH', path, { availableUnits: 15 }),
    ]);
    assert.deepEqual(simultaneous.map(result => result.notificationsSent).sort(), [0, 2]);
    const statusOnly = await expectStatus(200, 'PATCH', path, { status: 'Reserved' });
    assert.equal(statusOnly.notificationsSent, 2);
    const groupOnly = await expectStatus(200, 'PATCH', path, { bloodGroup: 'AB-' });
    assert.equal(groupOnly.notificationsSent, 2);
    const beforeDelete = await prisma.notification.count({ where: { userId: { in: userIds } } });
    console.log('PASS: Update, duplicate validation, units/status/group changes and concurrent identical saves');
    await expectStatus(200, 'DELETE', path);
    assert.equal(await prisma.bloodStock.findUnique({ where: { id: created.data.id } }), null);
    assert.equal(await prisma.notification.count({ where: { userId: { in: userIds } } }), beforeDelete);
    await expectStatus(404, 'GET', path);
    await expectStatus(404, 'PATCH', path, { availableUnits: 1 });
    await expectStatus(404, 'DELETE', path);
    console.log('PASS: Delete persists and missing IDs return 404');
    await prisma.user.update({ where: { id: userIds[0] }, data: { isActive: false } });
    await expectStatus(403, 'GET', '/blood-stock');
    console.log('PASS: Deactivated manager rejected');
  } finally {
    if (stockIds.length) await prisma.bloodStock.deleteMany({ where: { id: { in: stockIds } } });
    if (userIds.length) await prisma.user.deleteMany({ where: { id: { in: userIds } } });
    if (branchIds.length) await prisma.bloodBankBranch.deleteMany({ where: { id: { in: branchIds } } });
    await prisma.$disconnect();
  }
}
run().catch(error => { console.error(error.message); process.exitCode = 1; });
