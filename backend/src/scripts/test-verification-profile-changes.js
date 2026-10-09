// Offline behavior tests: no PostgreSQL connection or real data mutations.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { snapshot, stageProfileChanges } = require('../services/verification-profile.service');
let users, profiles, queue, nextId;
const clone = v => structuredClone(v);
const matches = (r, w) => Object.entries(w).every(([k, v]) => v?.in ? v.in.includes(r[k]) : r[k] === v);
function delegate(rows) {
  return {
    findUnique: async ({ where, include }) => { const r = rows().find(r => matches(r, where)); return r ? clone(include ? { ...r, submittedBy: users.find(u => u.id === r.submittedById) } : r) : null; },
    findFirst: async ({ where }) => clone(rows().find(r => matches(r, where)) || null),
    findMany: async ({ where = {}, include }) => rows().filter(r => matches(r, where)).slice().reverse().map(r => clone(include ? { ...r, submittedBy: users.find(u => u.id === r.submittedById) } : r)),
    create: async ({ data }) => { const r = { id: `request-${nextId++}`, createdAt: new Date(), updatedAt: new Date(), reviewedById: null, reviewedAt: null, ...clone(data) }; rows().push(r); return clone(r); },
    update: async ({ where, data }) => { const r = rows().find(r => matches(r, where)); if (!r) throw Object.assign(new Error('Missing'), { code: 'P2025' }); Object.assign(r, clone(data)); return clone(r); },
    delete: async ({ where }) => { const list = rows(), i = list.findIndex(r => matches(r, where)); if (i < 0) throw Object.assign(new Error('Missing'), { code: 'P2025' }); return list.splice(i, 1)[0]; },
  };
}
const prisma = {
  user: delegate(() => users), donorProfile: delegate(() => profiles), verificationQueue: delegate(() => queue),
  $queryRaw: async () => [],
  $transaction: async fn => { const before = clone({ users, profiles, queue }); try { return await fn(prisma); } catch (e) { ({ users, profiles, queue } = before); throw e; } },
};
// Substitute persistence and JWT decoding; execute actual route and authorization code.
require.cache[require.resolve('../prisma')] = { exports: { prisma } };
require.cache[require.resolve('../middleware/auth.middleware')] = { exports: { authenticateToken: (req, res, next) => {
  const id = req.headers.authorization?.replace('Bearer ', '');
  if (!id) return res.status(401).json({ success: false }); req.user = { id }; next();
} } };
const router = require('../routes/verification-queue.routes');
const { verificationProfile } = require('../middleware/verification-profile.middleware');
const { authenticateToken } = require('../middleware/auth.middleware');
test('stage, compare, authorize, approve, reject and prevent duplicate profile changes', async () => {
  users = [{ id: 'donor', role: 'donor', isActive: true, name: 'Alexander Silva', idNumber: '199012345678', email: 'a@example.com', phone: '0771234567' }, { id: 'other', role: 'donor', isActive: true }, { id: 'manager', role: 'manager', isActive: true }];
  profiles = [{ id: 'profile', userId: 'donor', bloodGroup: 'B+', city: 'Colombo', address: 'Colombo Road', weightKg: 65, isAvailable: true }]; queue = []; nextId = 1;
  assert.deepEqual(snapshot({ phone: '0771234567', name: 'Alexander Silva' }, { phone: '0719876543', name: 'Alexander Silva' }), { oldValues: { phone: '0771234567' }, newValues: { phone: '0719876543' }, changedFields: ['phone'] });
  const app = express(); app.use(express.json());
  app.put('/api/auth/profile', authenticateToken, verificationProfile(false));
  app.post('/api/donors/profile', authenticateToken, verificationProfile(true)); app.use('/api/verification-queue', router);
  const server = app.listen(0, '127.0.0.1'); await new Promise(r => server.once('listening', r));
  async function request(status, method, path, body, id = 'donor') {
    const r = await fetch(`http://127.0.0.1:${server.address().port}${path}`, { method, headers: { 'Content-Type': 'application/json', ...(id ? { Authorization: `Bearer ${id}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    const json = await r.json(); assert.equal(r.status, status, JSON.stringify(json)); return json;
  }
  try {
    await request(401, 'PUT', '/api/auth/profile', { phone: '0719876543' }, null);
    await request(403, 'PUT', '/api/auth/profile', { userId: 'other', phone: '0719876543' });
    const result = await request(200, 'PUT', '/api/auth/profile', { userId: 'donor', phone: '0719876543', name: 'Alexander Silva' });
    const item = result.verification, path = `/api/verification-queue/${item.id}`;
    assert.equal(item.status, 'Pending'); assert.equal(item.verificationType, 'DonorProfileUpdate');
    assert.deepEqual(item.oldValues, { phone: '0771234567' }); assert.deepEqual(item.newValues, { phone: '0719876543' }); assert.deepEqual(item.changedFields, ['phone']);
    assert.equal(users[0].phone, '0771234567'); assert.equal(result.data.phone, '0771234567');
    await request(409, 'PUT', '/api/auth/profile', { phone: '0719876543' }); assert.equal(queue.length, 1);
    assert.equal((await request(200, 'GET', '/api/verification-queue/mine')).data[0].status, 'Pending');
    assert.deepEqual((await request(200, 'GET', '/api/verification-queue/mine', undefined, 'other')).data, []);
    await request(403, 'GET', '/api/verification-queue'); await request(403, 'GET', path);
    for (const status of ['Approved', 'Rejected']) await request(403, 'PATCH', path, { status }); await request(403, 'DELETE', path);
    const detail = (await request(200, 'GET', path, undefined, 'manager')).data; assert.equal(detail.submittedBy.name, 'Alexander Silva'); assert.equal(detail.newValues.phone, '0719876543');
    await request(400, 'PATCH', path, { status: 'Approved', newValues: { phone: 'hack' } }, 'manager');
    const approved = (await request(200, 'PATCH', path, { status: 'Approved', managerNote: 'Checked identity' }, 'manager')).data;
    assert.equal(users[0].phone, '0719876543'); assert.equal(approved.reviewedById, 'manager'); assert.ok(approved.reviewedAt);
    assert.equal((await request(200, 'GET', '/api/verification-queue/mine')).data[0].status, 'Approved');
    await request(409, 'PATCH', path, { status: 'Rejected' }, 'manager');
    const medical = (await request(200, 'POST', '/api/donors/profile', { bloodGroup: 'B-', city: 'Colombo', address: 'Colombo Road', weightKg: 65 })).verification;
    assert.deepEqual(medical.changedFields, ['bloodGroup']); assert.equal(medical.oldValues.bloodGroup, 'B+'); assert.equal(profiles[0].bloodGroup, 'B+');
    await request(200, 'PATCH', `/api/verification-queue/${medical.id}`, { status: 'Rejected', managerNote: 'Need evidence' }, 'manager');
    assert.equal(profiles[0].bloodGroup, 'B+'); const mine = (await request(200, 'GET', '/api/verification-queue/mine')).data; assert.equal(mine[0].status, 'Rejected'); assert.equal(mine[0].managerNote, 'Need evidence');
    const retry = (await request(200, 'POST', '/api/donors/profile', { bloodGroup: 'B-' })).verification;
    await request(200, 'PATCH', `/api/verification-queue/${retry.id}`, { status: 'Approved' }, 'manager'); assert.equal(profiles[0].bloodGroup, 'B-');
    const count = queue.length; await request(200, 'POST', '/api/donors/profile', { isAvailable: false }); assert.equal(queue.length, count); assert.equal(profiles[0].isAvailable, false);
    const stale = (await stageProfileChanges(prisma, 'donor', { phone: '0729876543' }, false)).verification; users[0].phone = '0739876543';
    await request(409, 'PATCH', `/api/verification-queue/${stale.id}`, { status: 'Approved' }, 'manager'); assert.equal(queue.at(-1).status, 'Pending');
  } finally { await new Promise(r => server.close(r)); }
});
