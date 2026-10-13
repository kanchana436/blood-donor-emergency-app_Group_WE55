require('dotenv').config();
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const PORT = process.env.PORT || 5000;
const BASE_URL = process.env.DONOR_AVAILABILITY_TEST_URL || `http://127.0.0.1:${PORT}/api`;
const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

let donorUser = null;
let otherUser = null;
let donorToken = null;
let otherToken = null;
const createdAvailabilityIds = [];
const createdUserIds = [];

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const data = await res.json().catch(() => null);
  return { status: res.status, data };
}

async function runTests() {
  console.log('====================================================');
  console.log('🧪 Starting Donor Availability CRUD Integration Tests');
  console.log(`📡 Targeting API: ${BASE_URL}`);
  console.log('====================================================\n');

  try {
    // -------------------------------------------------------------
    // Setup Test Users in Supabase DB
    // -------------------------------------------------------------
    const donorEmail = `avail_donor_${Date.now()}@lifelink-test.org`;
    const otherEmail = `avail_other_${Date.now()}@lifelink-test.org`;

    donorUser = await prisma.user.create({
      data: {
        id: randomUUID(),
        email: donorEmail,
        idNumber: `NIC_${Date.now().toString().slice(-9)}`,
        name: 'Test Availability Donor',
        phone: '+94771239999',
        password: 'hashed_password_placeholder',
        role: 'donor',
        isActive: true,
        isEmailVerified: true,
        donorProfile: {
          create: {
            bloodGroup: 'O+',
            city: 'Colombo',
            address: 'Test Address Colombo',
            isAvailable: true,
          },
        },
      },
    });
    createdUserIds.push(donorUser.id);

    otherUser = await prisma.user.create({
      data: {
        id: randomUUID(),
        email: otherEmail,
        idNumber: `NIC_${(Date.now() + 1).toString().slice(-9)}`,
        name: 'Test Other User',
        phone: '+94771238888',
        password: 'hashed_password_placeholder',
        role: 'recipient',
        isActive: true,
        isEmailVerified: true,
      },
    });
    createdUserIds.push(otherUser.id);

    donorToken = jwt.sign({ id: donorUser.id, role: donorUser.role }, JWT_SECRET, { expiresIn: '1h' });
    otherToken = jwt.sign({ id: otherUser.id, role: otherUser.role }, JWT_SECRET, { expiresIn: '1h' });

    console.log('✅ Test users and profiles created successfully.');

    // -------------------------------------------------------------
    // Test 1: Unauthenticated Requests
    // -------------------------------------------------------------
    console.log('\n[TEST 1] Unauthenticated request rejection...');
    const unauthCreate = await request('/donor-availability', {
      method: 'POST',
      body: { availableFrom: new Date().toISOString() },
    });
    assert.equal(unauthCreate.status, 401, 'POST /donor-availability must return 401 without auth token');

    const unauthGet = await request('/donor-availability/me');
    assert.equal(unauthGet.status, 401, 'GET /donor-availability/me must return 401 without auth token');
    console.log('✅ Unauthenticated requests properly rejected (401).');

    // -------------------------------------------------------------
    // Test 2: Validation on Create
    // -------------------------------------------------------------
    console.log('\n[TEST 2] Validation rules on Create...');
    // Missing availableFrom
    const missingFrom = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { status: 'Available' },
    });
    assert.equal(missingFrom.status, 400, 'Must reject missing availableFrom');

    // Invalid status
    const invalidStatus = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'InvalidStatus',
        availableFrom: new Date().toISOString(),
      },
    });
    assert.equal(invalidStatus.status, 400, 'Must reject invalid status');

    // availableUntil earlier than availableFrom
    const invalidDateRange = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'Available',
        availableFrom: new Date(Date.now() + 86400000).toISOString(),
        availableUntil: new Date().toISOString(), // earlier!
      },
    });
    assert.equal(invalidDateRange.status, 400, 'Must reject availableUntil earlier than availableFrom');
    console.log('✅ Validation rules enforced correctly (400).');

    // -------------------------------------------------------------
    // Test 3: Create Valid Availability Record
    // -------------------------------------------------------------
    console.log('\n[TEST 3] Create valid availability record...');
    const tomorrow = new Date(Date.now() + 86400000);
    const inAWeek = new Date(Date.now() + 7 * 86400000);

    const createRes = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'Available',
        availableFrom: tomorrow.toISOString(),
        availableUntil: inAWeek.toISOString(),
        city: 'Colombo',
        notes: 'Available on weekdays after 5 PM',
      },
    });

    assert.equal(createRes.status, 201, 'Must return 201 Created');
    assert.equal(createRes.data.success, true);
    assert.ok(createRes.data.data.id, 'Record must have an ID');
    assert.equal(createRes.data.data.donorId, donorUser.id, 'Record must belong to authenticated donor');
    assert.equal(createRes.data.data.status, 'Available');
    assert.equal(createRes.data.data.isActive, true);

    const firstRecordId = createRes.data.data.id;
    createdAvailabilityIds.push(firstRecordId);
    console.log(`✅ Availability record created: ID ${firstRecordId}`);

    // -------------------------------------------------------------
    // Test 4: Conflict / Overlap Detection
    // -------------------------------------------------------------
    console.log('\n[TEST 4] Preventing overlapping active availability records...');
    const overlapRes = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'Available',
        availableFrom: new Date(Date.now() + 2 * 86400000).toISOString(), // falls within tomorrow..inAWeek
        availableUntil: new Date(Date.now() + 4 * 86400000).toISOString(),
        notes: 'Overlapping schedule attempt',
      },
    });
    assert.equal(overlapRes.status, 409, 'Must return 409 Conflict for overlapping schedules');
    console.log('✅ Overlapping availability schedule rejected (409 Conflict).');

    // -------------------------------------------------------------
    // Test 5: Read Own Availability (GET /me and GET /:id)
    // -------------------------------------------------------------
    console.log('\n[TEST 5] Read authenticated donor availability...');
    const getMeRes = await request('/donor-availability/me', {
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(getMeRes.status, 200);
    assert.equal(getMeRes.data.success, true);
    assert.ok(Array.isArray(getMeRes.data.data));
    assert.equal(getMeRes.data.data.length, 1);
    assert.equal(getMeRes.data.data[0].id, firstRecordId);

    const getOneRes = await request(`/donor-availability/${firstRecordId}`, {
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(getOneRes.status, 200);
    assert.equal(getOneRes.data.data.id, firstRecordId);
    console.log('✅ Authenticated donor can retrieve own records successfully.');

    // -------------------------------------------------------------
    // Test 6: Cross-user Authorization Protection
    // -------------------------------------------------------------
    console.log('\n[TEST 6] Cross-user unauthorized access protection...');
    const forbiddenGet = await request(`/donor-availability/${firstRecordId}`, {
      headers: { Authorization: `Bearer ${otherToken}` },
    });
    assert.equal(forbiddenGet.status, 403, 'Another user cannot access private availability record');

    const forbiddenPut = await request(`/donor-availability/${firstRecordId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${otherToken}` },
      body: { notes: 'Malicious modification' },
    });
    assert.equal(forbiddenPut.status, 403, 'Another user cannot update availability record');

    const forbiddenDelete = await request(`/donor-availability/${firstRecordId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${otherToken}` },
    });
    assert.equal(forbiddenDelete.status, 403, 'Another user cannot delete availability record');
    console.log('✅ Cross-user private records strictly protected (403 Forbidden).');

    // -------------------------------------------------------------
    // Test 7: Update Availability Record (PUT /:id)
    // -------------------------------------------------------------
    console.log('\n[TEST 7] Update existing availability record...');
    const updatedNotes = 'Updated: Available weekends only';
    const extendedUntil = new Date(Date.now() + 10 * 86400000);

    const updateRes = await request(`/donor-availability/${firstRecordId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        notes: updatedNotes,
        availableUntil: extendedUntil.toISOString(),
      },
    });
    assert.equal(updateRes.status, 200);
    assert.equal(updateRes.data.success, true);
    assert.equal(updateRes.data.data.notes, updatedNotes);

    // Verify in database directly
    const dbRecord = await prisma.donorAvailability.findUnique({ where: { id: firstRecordId } });
    assert.equal(dbRecord.notes, updatedNotes);
    console.log('✅ Availability record updated and verified in Supabase database.');

    // -------------------------------------------------------------
    // Test 8: Soft Delete Availability Record (DELETE /:id)
    // -------------------------------------------------------------
    console.log('\n[TEST 8] Soft Delete availability record...');
    const deleteRes = await request(`/donor-availability/${firstRecordId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(deleteRes.status, 200);
    assert.equal(deleteRes.data.success, true);

    // Verify soft delete in DB: record exists but isActive = false
    const deletedDbRecord = await prisma.donorAvailability.findUnique({ where: { id: firstRecordId } });
    assert.ok(deletedDbRecord, 'Record must still exist in DB for audit history');
    assert.equal(deletedDbRecord.isActive, false, 'Record must be marked isActive: false');

    // GET /me without history should return 0 active records
    const meAfterDelete = await request('/donor-availability/me', {
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(meAfterDelete.data.data.length, 0, 'Active list must exclude soft-deleted record');

    // GET /me with includeHistory=true should return the soft-deleted record
    const meWithHistory = await request('/donor-availability/me?includeHistory=true', {
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(meWithHistory.data.data.length, 1, 'History must include soft-deleted record');
    console.log('✅ Soft-delete strategy verified; audit history preserved.');

    // -------------------------------------------------------------
    // Test 9: Integration with Donor Search and Availability
    // -------------------------------------------------------------
    console.log('\n[TEST 9] Integration with Donor Search...');
    // Create an active Unavailable record covering today
    const now = new Date();
    const pastHour = new Date(Date.now() - 3600000);
    const nextHour = new Date(Date.now() + 3600000);

    const unavailNow = await request('/donor-availability', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'Unavailable',
        availableFrom: pastHour.toISOString(),
        availableUntil: nextHour.toISOString(),
        notes: 'Currently undergoing minor dental treatment',
      },
    });
    assert.equal(unavailNow.status, 201);
    createdAvailabilityIds.push(unavailNow.data.data.id);

    // Donor search with isAvailable=true should NOT include this donor
    const searchAvailable = await request(`/donors?bloodGroup=O%2B&city=Colombo&isAvailable=true`);
    assert.equal(searchAvailable.status, 200);
    const foundWhenUnavailable = searchAvailable.data.data.find(d => d.userId === donorUser.id);
    assert.equal(foundWhenUnavailable, undefined, 'Unavailable donor must not appear in isAvailable=true search results');

    // Donor search with isAvailable=false SHOULD include this donor
    const searchUnavailable = await request(`/donors?bloodGroup=O%2B&city=Colombo&isAvailable=false`);
    assert.equal(searchUnavailable.status, 200);
    const foundWhenFalse = searchUnavailable.data.data.find(d => d.userId === donorUser.id);
    assert.ok(foundWhenFalse, 'Donor must appear when filtering isAvailable=false');
    assert.equal(foundWhenFalse.isAvailable, false);

    // Now update this record to Available covering right now
    await request(`/donor-availability/${unavailNow.data.data.id}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        status: 'Available',
      },
    });

    // Donor search with isAvailable=true should NOW include this donor!
    const searchAvailableAgain = await request(`/donors?bloodGroup=O%2B&city=Colombo&isAvailable=true`);
    assert.equal(searchAvailableAgain.status, 200);
    const foundWhenAvailable = searchAvailableAgain.data.data.find(d => d.userId === donorUser.id);
    assert.ok(foundWhenAvailable, 'Available donor must appear in isAvailable=true search results');
    assert.equal(foundWhenAvailable.isAvailable, true);

    console.log('✅ Real-time integration with donor search verified.');

    console.log('\n🎉 ALL TESTS PASSED SUCCESSFULLY! (10/10)');
  } finally {
    // Cleanup fixtures
    console.log('\n🧹 Cleaning up test fixtures...');
    try {
      if (createdAvailabilityIds.length > 0) {
        await prisma.donorAvailability.deleteMany({
          where: { id: { in: createdAvailabilityIds } },
        });
      }
      if (createdUserIds.length > 0) {
        await prisma.user.deleteMany({
          where: { id: { in: createdUserIds } },
        });
      }
      console.log('✅ Test fixtures cleaned up successfully.');
    } catch (cleanErr) {
      console.warn('Notice during cleanup:', cleanErr.message);
    }
    await prisma.$disconnect();
  }
}

runTests().catch(err => {
  console.error('\n❌ Test Suite Failed:', err);
  process.exit(1);
});
