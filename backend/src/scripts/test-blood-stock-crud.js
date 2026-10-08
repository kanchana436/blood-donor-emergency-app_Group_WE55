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
    for (const role of ['manager', 'donor']) {
      const user = await prisma.user.create({ data: {
        idNumber: `${marker}-${role}`, name: 'Blood Stock Test',
        email: `${marker}-${role}@example.invalid`, phone: '0770000000',
        password: '!integration-test-no-login!', role, isEmailVerified: true,
      } });
      userIds.push(user.id);
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
    const path = `/blood-stock/${created.data.id}`;
    assert.equal((await prisma.bloodStock.findUnique({ where: { id: created.data.id } })).availableUnits, 12);
    console.log('PASS: Create persists to PostgreSQL');
    const all = await expectStatus(200, 'GET', '/blood-stock');
    assert.ok(all.data.some(stock => stock.id === created.data.id));
    const filtered = await expectStatus(200, 'GET', '/blood-stock?bloodGroup=O%2B');
    assert.ok(filtered.data.some(stock => stock.id === created.data.id));
    assert.ok(filtered.data.every(stock => stock.bloodGroup === 'O+'));
    assert.equal((await expectStatus(200, 'GET', path)).data.location, marker);
    console.log('PASS: Read all, filter and read by ID');
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
    const updated = await expectStatus(200, 'PATCH', path,
      { availableUnits: 0, status: 'Unavailable', location: `  ${marker}-updated  ` });
    assert.equal(updated.data.availableUnits, 0);
    assert.equal(updated.data.location, `${marker}-updated`);
    assert.ok(new Date(updated.data.updatedAt) >= new Date(created.data.updatedAt));
    assert.equal((await prisma.bloodStock.findUnique({ where: { id: created.data.id } })).status, 'Unavailable');
    console.log('PASS: Update and duplicate update validation');
    await expectStatus(200, 'DELETE', path);
    assert.equal(await prisma.bloodStock.findUnique({ where: { id: created.data.id } }), null);
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
    await prisma.$disconnect();
  }
}
run().catch(error => { console.error(error.message); process.exitCode = 1; });
