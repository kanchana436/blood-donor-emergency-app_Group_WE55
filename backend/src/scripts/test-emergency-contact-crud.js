require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const base = process.env.EMERGENCY_CONTACT_TEST_URL || `http://127.0.0.1:${process.env.PORT || 5001}/api`;
const marker = `emergency-contact-test-${randomUUID()}`;
const users = [];
let token;
async function request(method, path, body, auth = token) {
  const response = await fetch(`${base}${path}`, {
    method, headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(20000),
  });
  return { status: response.status, json: await response.json() };
}
async function expect(status, method, path, body, auth) {
  const result = await request(method, path, body, auth);
  assert.equal(result.status, status, JSON.stringify(result.json));
  assert.equal(result.json.success, status < 400);
  return result.json;
}
async function run() {
  const path = '/emergency-contacts';
  try {
    // Before fixtures, require the reviewed table and partial unique index.
    await prisma.emergencyContact.count();
    const indexes = await prisma.$queryRaw`SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'EmergencyContact_one_primary_per_user_key'`;
    assert.ok(indexes.length && /UNIQUE.*WHERE/i.test(indexes[0].indexdef), 'Apply the reviewed emergency-contacts.sql first');
    for (let i = 0; i < 2; i++) {
      const user = await prisma.user.create({ data: { idNumber: `${marker}-${i}`, name: 'Emergency Contact Test', email: `${marker}-${i}@example.invalid`, phone: '0770000000', password: '!no-login-test!', role: 'donor', isEmailVerified: true } });
      users.push(user.id);
    }
    const secret = process.env.JWT_SECRET || 'lifelink_secret_2026';
    const sign = id => jwt.sign({ id }, secret, { expiresIn: '10m' });
    token = sign(users[0]);
    const other = sign(users[1]);
    await expect(401, 'GET', path, undefined, null);
    await expect(401, 'GET', path, undefined, 'invalid');
    await expect(401, 'GET', path, undefined, sign(randomUUID()));
    const body = { fullName: '  Test Contact  ', relationship: '  Sibling  ', phone: '+94 (77) 123-4567', isPrimary: true };
    const first = (await expect(201, 'POST', path, body)).data;
    const item = `${path}/${first.id}`;
    assert.equal(first.phone, '94771234567');
    assert.equal(first.fullName, 'Test Contact');
    assert.equal((await prisma.emergencyContact.findUnique({ where: { id: first.id } })).phone, first.phone);
    assert.ok((await expect(200, 'GET', path)).data.some(contact => contact.id === first.id));
    assert.equal((await expect(200, 'GET', item)).data.id, first.id);
    assert.equal((await expect(200, 'GET', path, undefined, other)).data.length, 0);
    for (const method of ['GET', 'PATCH', 'DELETE']) await expect(404, method, item, method === 'PATCH' ? { fullName: 'Intruder' } : undefined, other);
    for (const phone of ['94771234567', '077 123 4567', '0094 77 1234567']) await expect(409, 'POST', path, { ...body, phone });
    for (const invalid of [{ phone: 'abc' }, { phone: '123' }, { alternatePhone: 'bad' }, { fullName: ' ' }, { relationship: '' }, { isPrimary: 'true' }, { userId: users[1] }]) await expect(400, 'POST', path, { ...body, ...invalid });
    await expect(400, 'POST', path, {});
    await expect(400, 'PATCH', item, {});
    await expect(400, 'PATCH', item, { phone: 'bad' });
    const second = (await expect(201, 'POST', path, { ...body, phone: '0771234568', isPrimary: false })).data;
    await expect(409, 'PATCH', `${path}/${second.id}`, { phone: '+94 77 1234567', isPrimary: true });
    assert.equal((await prisma.emergencyContact.findUnique({ where: { id: first.id } })).isPrimary, true, 'Duplicate transaction rolls back primary change');
    const updated = (await expect(200, 'PATCH', item, { fullName: ' Updated ', alternatePhone: '071 1234567', address: ' Colombo ' })).data;
    assert.equal(updated.fullName, 'Updated');
    assert.equal(updated.alternatePhone, '94711234567');
    assert.equal(updated.address, 'Colombo');
    await expect(200, 'PATCH', item, { alternatePhone: null, address: null });
    await expect(200, 'PATCH', `${path}/${second.id}`, { isPrimary: true });
    assert.equal((await prisma.emergencyContact.findUnique({ where: { id: first.id } })).isPrimary, false);
    await Promise.all([expect(200, 'PATCH', item, { isPrimary: true }), expect(200, 'PATCH', `${path}/${second.id}`, { isPrimary: true })]);
    assert.equal(await prisma.emergencyContact.count({ where: { userId: users[0], isPrimary: true } }), 1);
    const primary = await prisma.emergencyContact.findFirst({ where: { userId: users[0], isPrimary: true } });
    const remaining = primary.id === first.id ? second : first;
    await assert.rejects(prisma.emergencyContact.update({ where: { id: remaining.id }, data: { isPrimary: true } }), error => error.code === 'P2002');
    // A second account may use the same phone and have its own primary contact.
    await expect(201, 'POST', path, body, other);
    await expect(200, 'DELETE', `${path}/${primary.id}`);
    assert.equal(await prisma.emergencyContact.findUnique({ where: { id: primary.id } }), null);
    assert.equal(await prisma.emergencyContact.count({ where: { userId: users[0], isPrimary: true } }), 0);
    await expect(200, 'PATCH', `${path}/${remaining.id}`, { isPrimary: true });
    await expect(200, 'PATCH', `${path}/${remaining.id}`, { isPrimary: false });
    for (const method of ['GET', 'PATCH', 'DELETE']) await expect(404, method, `${path}/${primary.id}`, method === 'PATCH' ? { fullName: 'Missing' } : undefined);
    await prisma.user.update({ where: { id: users[0] }, data: { isActive: false } });
    await expect(403, 'GET', path);
    console.log('PASS: Real PostgreSQL CRUD, normalization, ownership, validation, primary concurrency/index and deletion');
  } finally {
    // Only these two unique test accounts and their cascade-owned contacts.
    if (users.length) await prisma.user.deleteMany({ where: { id: { in: users } } });
    await prisma.$disconnect();
  }
}
run().catch(error => { console.error(error.message); process.exitCode = 1; });
