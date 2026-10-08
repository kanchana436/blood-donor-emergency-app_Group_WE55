require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const base = process.env.VERIFICATION_QUEUE_TEST_URL || `http://127.0.0.1:${process.env.PORT || 5001}/api`;
const marker = `verification-test-${randomUUID()}`;
const users = [], records = [];
let token;
async function expect(status, method, path = '/verification-queue', body, auth = token) {
  const response = await fetch(`${base}${path}`, { method, headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Bearer ${auth}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(20000) });
  const json = await response.json(); assert.equal(response.status, status, JSON.stringify(json)); assert.equal(json.success, status < 400); return json.data;
}
async function run() {
  try {
    await prisma.verificationQueue.count();
    for (const role of ['manager', 'admin', 'donor', 'recipient']) users.push(await prisma.user.create({ data: { idNumber: `${marker}-${role}`, email: `${marker}-${role}@example.invalid`, name: 'Verification test', phone: '0770000000', password: '!test-no-login!', role, isEmailVerified: true } }));
    const sign = (u, role = u.role) => jwt.sign({ id: u.id, role }, process.env.JWT_SECRET || 'lifelink_secret_2026', { expiresIn: '5m' });
    token = sign(users[0]);
    await expect(401, 'GET', undefined, undefined, null); await expect(401, 'GET', undefined, undefined, 'invalid');
    const donorToken = sign(users[2]);
    const body = {};
    const item = await expect(201, 'POST', undefined, body, donorToken); records.push(item.id);
    const path = `/verification-queue/${item.id}`;
    assert.equal(item.submittedById, users[2].id);
    assert.equal(item.verificationType, 'DonorVerification');
    assert.equal(item.title, 'Donor Profile Verification');
    await expect(409, 'POST', undefined, {}, donorToken);
    await expect(403, 'POST', undefined, {}, token);
    await expect(403, 'POST', undefined, {}, sign(users[3]));
    const mine = await expect(200, 'GET', '/verification-queue/mine', undefined, donorToken);
    assert.ok(mine.some(row => row.id === item.id));
    assert.ok(mine.every(row => row.submittedById === users[2].id));
    const otherDonor = await prisma.user.create({ data: { idNumber: `${marker}-other`, email: `${marker}-other@example.invalid`, name: 'Other donor', phone: '0770000000', password: '!test-no-login!', role: 'donor' } });
    users.push(otherDonor);
    assert.deepEqual(await expect(200, 'GET', '/verification-queue/mine', undefined, sign(otherDonor)), []);
    assert.equal(item.status, 'Pending'); assert.equal(item.reviewedAt, null);
    for (const auth of [sign(users[2]), sign(users[2], 'manager')]) {
      for (const [method, url, data] of [['GET', '/verification-queue'], ['GET', path], ['PATCH', path, { status: 'Approved' }], ['DELETE', path]]) await expect(403, method, url, data, auth);
    }
    await expect(200, 'GET', undefined, undefined, sign(users[1]));
    assert.ok((await expect(200, 'GET')).some(r => r.id === item.id)); assert.equal((await expect(200, 'GET', path)).title, 'Donor Profile Verification');
    for (const invalid of [{ title: '' }, { status: 'Other' }, { reviewedById: users[1].id }, { reviewedAt: new Date().toISOString() }, { submittedById: null }]) await expect(400, 'POST', undefined, { ...body, ...invalid }, donorToken);
    await expect(400, 'GET', '/verification-queue?status=Other'); await expect(400, 'PATCH', path, {}); await expect(400, 'PATCH', path, { reviewedById: users[1].id });
    for (const status of ['Approved', 'Rejected']) {
      const updated = await expect(200, 'PATCH', path, { status, managerNote: `Reviewed ${status}` });
      assert.equal(updated.reviewedById, users[0].id); assert.ok(updated.reviewedAt);
      const own = await expect(200, 'GET', '/verification-queue/mine', undefined, donorToken);
      assert.equal(own.find(row => row.id === item.id).status, status);
      assert.equal(own.find(row => row.id === item.id).managerNote, `Reviewed ${status}`);
      const persisted = await prisma.verificationQueue.findUnique({ where: { id: item.id } }); assert.equal(persisted.status, status); assert.equal(persisted.managerNote, `Reviewed ${status}`);
      const filtered = await expect(200, 'GET', `/verification-queue?status=${status}`); assert.ok(filtered.some(r => r.id === item.id)); assert.ok(filtered.every(r => r.status === status));
    }
    const pending = await expect(200, 'PATCH', path, { status: 'Pending' }); assert.equal(pending.reviewedById, null); assert.equal(pending.reviewedAt, null);
    await expect(200, 'DELETE', path); assert.equal(await prisma.verificationQueue.findUnique({ where: { id: item.id } }), null);
    await expect(404, 'GET', path); await expect(404, 'PATCH', path, { title: 'Missing' }); await expect(404, 'DELETE', path);
    await prisma.user.update({ where: { id: users[0].id }, data: { isActive: false } }); await expect(403, 'GET');
    console.log('PASS: Verification Queue CRUD, validation, filters, role authorization and review audit fields');
  } finally {
    // Cleanup is restricted to fixtures created by this invocation.
    if (records.length) await prisma.verificationQueue.deleteMany({ where: { id: { in: records } } });
    if (users.length) await prisma.user.deleteMany({ where: { id: { in: users.map(u => u.id) } } });
    await prisma.$disconnect();
  }
}
run().catch(error => { console.error(error.message); process.exitCode = 1; });
