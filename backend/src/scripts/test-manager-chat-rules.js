// Offline HTTP integration: real routes, bcrypt and JWT; isolated Prisma-compatible persistence.
// Never imports the live database module, never executes SQL or modifies existing records.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const secret = process.env.JWT_SECRET || 'lifelink_secret_2026';
const chatSecret = require('node:crypto').createHmac('sha256', secret).update('lifelink-manager-chat-v1').digest('hex');
let users, branches, conversations, messages;
const clone = v => structuredClone(v);
function match(row, where = {}) {
  return Object.entries(where).every(([k, v]) => {
    if (k === 'donorProfile') return row.donorProfile != null;
    if (v && typeof v === 'object') {
      if ('not' in v) return row[k] != null && row[k] !== v.not;
      if ('equals' in v) return row[k].toLowerCase() === v.equals.toLowerCase();
    }
    return row[k] === v;
  });
}
function project(row, select) {
  if (!row) return null;
  if (!select) return clone(row);
  return Object.fromEntries(Object.entries(select).map(([key, value]) => [key,
    value === true ? clone(row[key]) : row[key] == null ? null : project(row[key], value.select)]));
}
function user(where) {
  const u = users.find(u => match(u, where));
  return u ? { ...u, branch: branches.find(b => b.id === u.branchId) || null } : null;
}
function hydrate(c) { return c ? { ...c, manager: user({ id: c.managerId }), donor: user({ id: c.donorId }), branch: branches.find(b => b.id === c.branchId) } : null; }
const prisma = {
  user: {
    findUnique: async ({ where, select }) => project(user(where), select),
    findFirst: async ({ where, select }) => project(user(where), select),
    findMany: async ({ where, select }) => users.filter(u => match(u, where))
      .sort((a, b) => `${a.branchId || ''}:${a.id}`.localeCompare(`${b.branchId || ''}:${b.id}`)).map(u => project(user({ id: u.id }), select)),
    update: async ({ where, data, select }) => { const u = users.find(u => match(u, where)); Object.assign(u, data); return project(u, select); },
  },
  chatConversation: {
    findMany: async ({ where }) => clone(conversations.filter(c => match(c, where)).map(hydrate).reverse()),
    findUnique: async ({ where }) => clone(hydrate(conversations.find(c => match(c, where)))),
    upsert: async ({ where, create }) => {
      let c = conversations.find(c => match(c, where.managerId_donorId_branchId));
      if (!c) { c = { id: `c${conversations.length}`, ...create, createdAt: new Date(), updatedAt: new Date() }; conversations.push(c); }
      return clone(hydrate(c));
    },
    update: async ({ where, data }) => { const c = conversations.find(c => match(c, where)); Object.assign(c, data); return clone(c); },
  },
  chatMessage: {
    findUnique: async ({ where, select }) => project(messages.find(m => match(m, where)), select),
    findMany: async ({ where, take, cursor, skip = 0, select }) => {
      let list = messages.filter(m => match(m, where)).slice().reverse();
      if (cursor) list = list.slice(list.findIndex(m => m.id === cursor.id) + skip);
      return list.slice(0, take).map(m => project(m, select));
    },
    create: async ({ data, select }) => { const m = { id: `msg${messages.length}`, ...data, isRead: false, createdAt: new Date() }; messages.push(m); return project(m, select); },
    update: async ({ where, data, select }) => { const m = messages.find(m => match(m, where)); Object.assign(m, data); return project(m, select); },
  },
  $queryRaw: async () => [],
  $transaction: async fn => fn(prisma),
};
require.cache[require.resolve('../prisma')] = { exports: { prisma, db: { users: [] } } };
const chat = require('../routes/chat.routes');
const auth = require('../routes/auth.routes');
const normal = id => jwt.sign({ id, role: 'manager' }, secret, { expiresIn: '5m' });
const elevated = (id, options = {}) => jwt.sign({ userId: id, role: 'manager', scope: 'manager_chat', ...options }, chatSecret,
  { audience: 'lifelink-manager-chat', ...(options.exp ? {} : { expiresIn: '15m' }) });
async function reset() {
  branches = [{ id: 'b1', name: 'Colombo Bank', city: ' Colombo ' }, { id: 'b2', name: 'Kandy Bank', city: 'Kandy' }];
  const password = await bcrypt.hash('correct password', 4);
  users = [
    { id: 'manager', name: 'Manager', email: 'manager@example.com', password, role: 'manager', isActive: true, branchId: 'b1' },
    { id: 'another', name: 'Other', email: 'other@example.com', password, role: 'manager', isActive: true, branchId: 'b1' },
    { id: 'remote-manager', name: 'Remote', email: 'remote@example.com', password, role: 'manager', isActive: true, branchId: 'b2' },
    { id: 'unassigned', email: 'unassigned@example.com', password, role: 'manager', isActive: true },
    { id: 'inactive-manager', email: 'inactive@example.com', password, role: 'manager', isActive: false, branchId: 'b1' },
    { id: 'donor', name: 'Local Donor', email: 'private@example.com', password, phone: 'private', idNumber: 'private', role: 'donor', isActive: true, donorProfile: { city: ' coLOMBo ', bloodGroup: 'O+', medicalConditions: 'private' } },
    { id: 'second-donor', name: 'Second', role: 'donor', isActive: true, donorProfile: { city: 'Colombo', bloodGroup: 'B+' } },
    { id: 'remote-donor', name: 'Remote', role: 'donor', isActive: true, donorProfile: { city: 'Gampaha', bloodGroup: 'A+' } },
    { id: 'inactive-donor', name: 'Inactive', role: 'donor', isActive: false, donorProfile: { city: 'Colombo', bloodGroup: 'A+' } },
    { id: 'substring-donor', name: 'Substring', role: 'donor', isActive: true, donorProfile: { city: 'Colombo 03', bloodGroup: 'A+' } },
    { id: 'recipient', role: 'recipient', isActive: true },
  ];
  conversations = []; messages = [];
}
test('manager chat and rules HTTP security', async t => {
  const app = express(); app.use(express.json()); app.use('/api/chat', chat); app.use('/api/auth', auth);
  const server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve));
  async function request(status, method, path, body, id = 'manager', access = elevated(id), session = id ? normal(id) : null) {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api${path}`, {
      method, headers: { 'Content-Type': 'application/json', ...(session ? { Authorization: `Bearer ${session}` } : {}),
        ...(access ? { 'X-Manager-Chat-Token': access } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const json = await response.json(); assert.equal(response.status, status, JSON.stringify(json)); return json.data;
  }
  const scenario = (name, fn) => t.test(name, async () => { await reset(); await fn(); });
  const create = () => request(200, 'POST', '/chat/conversations', { donorId: 'donor' });
  try {
    await scenario('rules require authentication; donor/recipient rejected; timestamp/version saved for manager/admin', async () => {
      await request(401, 'POST', '/auth/manager/rules/accept', {}, null, null);
      for (const id of ['donor', 'recipient', 'inactive-manager']) await request(403, 'POST', '/auth/manager/rules/accept', {}, id);
      const before = Date.now();
      const data = await request(200, 'POST', '/auth/manager/rules/accept', { userId: 'donor', managerRulesVersion: 'fake' });
      assert.equal(data.managerRulesVersion, '1.0'); assert.ok(new Date(data.managerRulesAcceptedAt).getTime() >= before);
      assert.equal(users[0].managerRulesVersion, '1.0'); assert.ok(users[0].managerRulesAcceptedAt instanceof Date);
      users[0].role = 'admin'; await request(200, 'POST', '/auth/manager/rules/accept', {});
    });
    await scenario('reauth own credentials; minimal 900-second token; no replacement for regular session', async () => {
      const data = await request(200, 'POST', '/chat/manager/reauth', { email: ' MANAGER@example.com ', password: 'correct password' });
      const claims = jwt.verify(data.token, chatSecret, { audience: 'lifelink-manager-chat' });
      assert.equal(claims.exp - claims.iat, 900); assert.equal(claims.scope, 'manager_chat'); assert.equal(claims.userId, 'manager');
      assert.deepEqual(Object.keys(claims).sort(), ['aud', 'exp', 'iat', 'role', 'scope', 'userId']);
      await request(200, 'GET', '/chat/manager/donors', undefined, 'manager', data.token);
      await request(401, 'GET', '/chat/manager/donors', undefined, 'manager', data.token, data.token);
      await request(401, 'GET', '/chat/manager/donors', undefined, 'manager', data.token, null);
    });
    await scenario('wrong password and another manager credentials rejected', async () => {
      await request(401, 'POST', '/chat/manager/reauth', { email: 'manager@example.com', password: 'wrong' });
      await request(401, 'POST', '/chat/manager/reauth', { email: 'other@example.com', password: 'correct password' });
    });
    await scenario('donor/inactive/unassigned/deleted branch fail closed', async () => {
      for (const id of ['donor', 'inactive-manager', 'unassigned']) await request(403, 'POST', '/chat/manager/reauth', { email: 'x', password: 'x' }, id);
      branches = []; await request(403, 'POST', '/chat/manager/reauth', { email: 'x', password: 'x' });
    });
    await scenario('expired, missing, wrong-account, wrong-scope and regular JWT rejected as elevation', async () => {
      for (const token of [null, normal('manager'), elevated('manager', { exp: Math.floor(Date.now() / 1000) - 1 }), elevated('another'), elevated('manager', { scope: 'other' })]) {
        await request(401, 'GET', '/chat/manager/donors', undefined, 'manager', token);
      }
    });
    await scenario('list includes normalized exact city only and never private fields', async () => {
      const list = await request(200, 'GET', '/chat/manager/donors');
      assert.deepEqual(list.map(d => d.userId).sort(), ['donor', 'second-donor']);
      for (const d of list) assert.deepEqual(Object.keys(d).sort(), ['bloodGroup', 'city', 'name', 'userId']);
    });
    await scenario('cross-city/inactive donor creation and spoofed identities rejected', async () => {
      for (const donorId of ['remote-donor', 'inactive-donor', 'substring-donor']) await request(403, 'POST', '/chat/conversations', { donorId });
      await request(400, 'POST', '/chat/conversations', { donorId: 'donor', managerId: 'another' });
      await request(400, 'POST', '/chat/conversations', { donorId: 'second-donor' }, 'donor');
    });
    await scenario('donor deterministic resolution, reuse, no-manager message', async () => {
      const c = await request(200, 'POST', '/chat/conversations', {}, 'donor');
      assert.equal(c.managerId, 'another'); // same branch, lexical manager ID first
      assert.equal((await request(200, 'POST', '/chat/conversations', {}, 'donor')).id, c.id);
      await request(404, 'POST', '/chat/conversations', {}, 'remote-donor');
      const own = await request(200, 'GET', '/chat/conversations', undefined, 'donor'); assert.equal(own.length, 1);
      assert.deepEqual(await request(200, 'GET', '/chat/conversations', undefined, 'second-donor'), []);
    });
    await scenario('private participant access, manager send, donor reply and persistence across fetches', async () => {
      const c = await create();
      for (const id of ['another', 'remote-manager', 'second-donor']) await request(404, 'GET', `/chat/conversations/${c.id}/messages`, undefined, id);
      const m = await request(201, 'POST', `/chat/conversations/${c.id}/messages`, { message: ' Hello donor ' });
      assert.equal(m.senderId, 'manager'); assert.equal(m.message, 'Hello donor');
      await request(201, 'POST', `/chat/conversations/${c.id}/messages`, { message: 'Hello manager' }, 'donor');
      const list = await request(200, 'GET', `/chat/conversations/${c.id}/messages`, undefined, 'donor');
      assert.deepEqual(list.map(m => m.message), ['Hello donor', 'Hello manager']); assert.equal(messages.length, 2);
      assert.ok(list.every(m => m.createdAt));
      assert.deepEqual(await request(200, 'GET', '/chat/conversations', undefined, 'another'), []);
    });
    await scenario('empty/oversized/spoofed sender rejected; maximum message accepted', async () => {
      const c = await create();
      for (const message of ['', '   ', 'a'.repeat(2001), 99]) await request(400, 'POST', `/chat/conversations/${c.id}/messages`, { message });
      await request(400, 'POST', `/chat/conversations/${c.id}/messages`, { message: 'hi', senderId: 'another' });
      await request(201, 'POST', `/chat/conversations/${c.id}/messages`, { message: 'a'.repeat(2000) });
    });
    await scenario('city change, manager reassignment and inactive participant revoke access', async () => {
      const c = await create(); users.find(u => u.id === 'donor').donorProfile.city = 'Gampaha';
      await request(403, 'POST', `/chat/conversations/${c.id}/messages`, { message: 'no' });
      await request(403, 'GET', `/chat/conversations/${c.id}/messages`, undefined, 'donor');
      users.find(u => u.id === 'donor').donorProfile.city = 'Colombo'; users[0].branchId = 'b2';
      await request(403, 'GET', `/chat/conversations/${c.id}/messages`);
      users[0].branchId = 'b1'; users[0].isActive = false;
      await request(403, 'GET', `/chat/conversations/${c.id}/messages`, undefined, 'donor');
    });
    await scenario('read only by receiving participant', async () => {
      const c = await create(); const m = await request(201, 'POST', `/chat/conversations/${c.id}/messages`, { message: 'hello' });
      await request(404, 'PATCH', `/chat/messages/${m.id}/read`, {}, 'second-donor');
      await request(403, 'PATCH', `/chat/messages/${m.id}/read`, {});
      assert.equal((await request(200, 'PATCH', `/chat/messages/${m.id}/read`, {}, 'donor')).isRead, true);
    });
    await scenario('bounded message pagination; foreign cursor rejected', async () => {
      const c = await create();
      for (let i = 0; i < 105; i++) messages.push({ id: `p${i}`, conversationId: c.id, senderId: 'manager', message: `${i}`, createdAt: new Date(), isRead: false });
      const page = await request(200, 'GET', `/chat/conversations/${c.id}/messages`); assert.equal(page.length, 100);
      const older = await request(200, 'GET', `/chat/conversations/${c.id}/messages?before=${page[0].id}`); assert.equal(older.length, 5);
      await request(400, 'GET', `/chat/conversations/${c.id}/messages?before=missing`);
    });
    await scenario('reauth limits repeated failed attempts', async () => {
      for (let i = 0; i < 5; i++) await request(401, 'POST', '/chat/manager/reauth', { email: 'other@example.com', password: 'wrong' }, 'another');
      await request(429, 'POST', '/chat/manager/reauth', { email: 'other@example.com', password: 'correct password' }, 'another');
    });
    await scenario('database outages fail closed without memory chat or acceptance', async () => {
      const original = prisma.user.findUnique;
      prisma.user.findUnique = async () => { throw new Error('offline'); };
      try {
        await request(503, 'GET', '/chat/conversations');
        await request(503, 'POST', '/auth/manager/rules/accept', {});
      } finally { prisma.user.findUnique = original; }
    });
    await scenario('unknown regular account cannot use chat or accept rules', async () => {
      await request(401, 'GET', '/chat/conversations', undefined, 'unknown');
      await request(401, 'POST', '/auth/manager/rules/accept', {}, 'unknown');
    });
  } finally { await new Promise(resolve => server.close(resolve)); }
});
