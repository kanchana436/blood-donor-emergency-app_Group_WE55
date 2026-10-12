require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const PORT = process.env.PORT || 5000;
const BASE_URL = process.env.CAMPAIGN_TEST_URL || `http://127.0.0.1:${PORT}/api`;
const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

let managerUser = null;
let donorUser = null;
let managerToken = null;
let donorToken = null;
const createdCampaignIds = [];
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
  console.log('🩸 Starting Blood Campaign CRUD Integration Tests');
  console.log(`📡 Targeting API: ${BASE_URL}`);
  console.log('====================================================\n');

  try {
    // -------------------------------------------------------------
    // Setup Test Users in Supabase DB
    // -------------------------------------------------------------
    const managerEmail = `camp_mgr_${Date.now()}@lifelink-test.org`;
    const donorEmail = `camp_donor_${Date.now()}@lifelink-test.org`;

    try {
      managerUser = await prisma.user.create({
        data: {
          id: randomUUID(),
          email: managerEmail,
          idNumber: `NIC_${Date.now().toString().slice(-9)}`,
          name: 'Manager Test Organizer',
          phone: '+94771234567',
          password: 'hashed_password_placeholder',
          role: 'manager',
          isActive: true,
          isEmailVerified: true,
        },
      });
      createdUserIds.push(managerUser.id);
    } catch (_) {
      managerUser = { id: 'usr_mgr_303', role: 'manager' };
    }

    try {
      donorUser = await prisma.user.create({
        data: {
          id: randomUUID(),
          email: donorEmail,
          idNumber: `NIC_${(Date.now() + 1).toString().slice(-9)}`,
          name: 'Donor Test User',
          phone: '+94777654321',
          password: 'hashed_password_placeholder',
          role: 'donor',
          isActive: true,
          isEmailVerified: true,
        },
      });
      createdUserIds.push(donorUser.id);
    } catch (_) {
      donorUser = { id: 'usr_donor_101', role: 'donor' };
    }

    managerToken = jwt.sign({ id: managerUser.id, role: managerUser.role }, JWT_SECRET, { expiresIn: '1h' });
    donorToken = jwt.sign({ id: donorUser.id, role: donorUser.role }, JWT_SECRET, { expiresIn: '1h' });

    console.log('✅ Test manager and donor users created successfully.');

    // -------------------------------------------------------------
    // Test 1: Unauthenticated Requests
    // -------------------------------------------------------------
    console.log('\n[TEST 1] Unauthenticated create rejection...');
    const unauthCreate = await request('/campaigns', {
      method: 'POST',
      body: { campaignName: 'Unauth Campaign' },
    });
    assert.equal(unauthCreate.status, 401, 'POST /campaigns must return 401 without auth token');
    console.log('✅ Unauthenticated create properly rejected (401).');

    // -------------------------------------------------------------
    // Test 2: Donor Campaign Creation
    // -------------------------------------------------------------
    console.log('\n[TEST 2] Donor campaign creation allowed...');
    const donorCreate = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        campaignName: 'Donor Organized Campaign',
        organizerName: 'Community Donor Organizer',
        contactNumber: '+94777654321',
        location: 'City Community Center',
        city: 'Colombo',
        campaignDate: '2026-11-15',
        startTime: '09:00 AM',
        endTime: '04:00 PM',
      },
    });
    assert.equal(donorCreate.status, 201, 'POST /campaigns should allow donors to organize campaigns');
    assert.ok(donorCreate.data.data.id, 'Must return created campaign ID');
    createdCampaignIds.push(donorCreate.data.data.id);
    console.log('✅ Donor can organize blood campaigns (201).');

    // -------------------------------------------------------------
    // Test 3: Validation - Missing Required Fields
    // -------------------------------------------------------------
    console.log('\n[TEST 3] Validation for missing required fields...');
    const missingFields = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        // Missing campaignName, organizerName, location, city, etc.
        description: 'Test Description only',
      },
    });
    assert.equal(missingFields.status, 400, 'POST /campaigns must return 400 for missing required fields');
    assert.ok(missingFields.data.message.includes('Campaign Name is required'));
    console.log('✅ Missing required fields properly rejected (400).');

    // -------------------------------------------------------------
    // Test 4: Validation - Invalid Phone and Email Formats
    // -------------------------------------------------------------
    console.log('\n[TEST 4] Validation for invalid phone and email...');
    const invalidPhoneEmail = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'Annual Blood Drive',
        organizerName: 'Red Cross Colombo',
        contactNumber: '123', // Too short
        email: 'invalid-email-address',
        location: 'Viharamahadevi Park',
        city: 'Colombo',
        campaignDate: '2026-11-20',
        startTime: '09:00 AM',
        endTime: '03:00 PM',
      },
    });
    assert.equal(invalidPhoneEmail.status, 400);
    assert.ok(invalidPhoneEmail.data.message.includes('Contact Number'));
    console.log('✅ Invalid phone and email formats properly rejected (400).');

    // -------------------------------------------------------------
    // Test 5: Validation - Invalid Date and Time Ranges
    // -------------------------------------------------------------
    console.log('\n[TEST 5] Validation for invalid time range (End <= Start)...');
    const invalidTime = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'Time Test Drive',
        organizerName: 'National Hospital',
        contactNumber: '+94771234567',
        location: 'Auditorium',
        city: 'Colombo',
        campaignDate: '2026-11-20',
        startTime: '04:00 PM',
        endTime: '09:00 AM', // Earlier than start time
      },
    });
    assert.equal(invalidTime.status, 400);
    assert.ok(invalidTime.data.message.includes('End Time must be later than Start Time'));
    console.log('✅ Invalid time range rejected (400).');

    // -------------------------------------------------------------
    // Test 6: Validation - Invalid Target Donors (must be positive)
    // -------------------------------------------------------------
    console.log('\n[TEST 6] Validation for invalid target donor numbers...');
    const invalidDonors = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'Target Donor Drive',
        organizerName: 'National Hospital',
        contactNumber: '+94771234567',
        location: 'Auditorium',
        city: 'Colombo',
        campaignDate: '2026-11-20',
        startTime: '09:00 AM',
        endTime: '02:00 PM',
        targetDonors: -5,
      },
    });
    assert.equal(invalidDonors.status, 400);
    assert.ok(invalidDonors.data.message.includes('Target Number of Donors'));
    console.log('✅ Negative or zero target donors rejected (400).');

    // -------------------------------------------------------------
    // Test 7: Successful Campaign Creation
    // -------------------------------------------------------------
    console.log('\n[TEST 7] Create Blood Campaign with valid data...');
    const validCreate = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'LifeLink Grand Blood Drive 2026',
        description: 'Annual life-saving blood donation camp organized with NHSL.',
        organizerName: 'Colombo Central Blood Bank',
        contactNumber: '+94 11 269 1111',
        email: 'campaigns@lifelink.org',
        hospitalOrBloodBank: 'National Blood Transfusion Service',
        location: 'BMICH Main Exhibition Hall',
        city: 'Colombo',
        campaignDate: '2026-11-25',
        startTime: '08:30 AM',
        endTime: '04:30 PM',
        targetDonors: 250,
        status: 'Upcoming',
      },
    });

    assert.equal(validCreate.status, 201, 'Should return 201 Created');
    assert.equal(validCreate.data.success, true);
    assert.ok(validCreate.data.data.id, 'Must return created campaign ID');
    assert.equal(validCreate.data.data.campaignName, 'LifeLink Grand Blood Drive 2026');
    assert.equal(validCreate.data.data.city, 'Colombo');
    assert.equal(validCreate.data.data.targetDonors, 250);
    assert.equal(validCreate.data.data.status, 'Upcoming');
    assert.equal(validCreate.data.data.isActive, true);

    const createdCampaignId = validCreate.data.data.id;
    createdCampaignIds.push(createdCampaignId);
    console.log(`✅ Campaign created successfully (ID: ${createdCampaignId}).`);

    // Create a second campaign in Kandy for filter testing
    const kandyCreate = await request('/campaigns', {
      method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'Kandy Hill Country Blood Drive',
        description: 'Community blood donation camp in Kandy.',
        organizerName: 'Kandy General Hospital',
        contactNumber: '+94 81 222 3333',
        email: 'kandy@lifelink.org',
        hospitalOrBloodBank: 'Kandy National Hospital',
        location: 'Kandy City Centre Hall',
        city: 'Kandy',
        campaignDate: '2026-12-10',
        startTime: '09:00 AM',
        endTime: '03:00 PM',
        targetDonors: 100,
        status: 'Ongoing',
      },
    });
    assert.equal(kandyCreate.status, 201);
    createdCampaignIds.push(kandyCreate.data.data.id);
    console.log('✅ Second campaign created in Kandy for filtering tests.');

    // -------------------------------------------------------------
    // Test 8: Read Campaigns & Filters
    // -------------------------------------------------------------
    console.log('\n[TEST 8] Read Campaigns List & Filters...');
    // All campaigns
    const allCampaigns = await request('/campaigns');
    assert.equal(allCampaigns.status, 200);
    assert.ok(allCampaigns.data.data.length >= 2);
    console.log(`✅ Read all campaigns returned ${allCampaigns.data.data.length} campaigns.`);

    // Search filter
    const searchRes = await request('/campaigns?search=Grand');
    assert.equal(searchRes.status, 200);
    assert.ok(searchRes.data.data.some(c => c.id === createdCampaignId));
    console.log('✅ Search filter by keyword works.');

    // City filter
    const cityRes = await request('/campaigns?city=Kandy');
    assert.equal(cityRes.status, 200);
    assert.ok(cityRes.data.data.every(c => c.city.toLowerCase().includes('kandy')));
    console.log('✅ Filter by city (Kandy) works.');

    // Status filter
    const statusRes = await request('/campaigns?status=Upcoming');
    assert.equal(statusRes.status, 200);
    assert.ok(statusRes.data.data.every(c => c.status === 'Upcoming'));
    console.log('✅ Filter by status (Upcoming) works.');

    // Date filter
    const dateRes = await request('/campaigns?date=2026-11-25');
    assert.equal(dateRes.status, 200);
    assert.ok(dateRes.data.data.some(c => c.id === createdCampaignId));
    console.log('✅ Filter by date (2026-11-25) works.');

    // -------------------------------------------------------------
    // Test 9: Read Campaign Details by ID
    // -------------------------------------------------------------
    console.log('\n[TEST 9] Read Campaign Details by ID...');
    const detailsRes = await request(`/campaigns/${createdCampaignId}`);
    assert.equal(detailsRes.status, 200);
    assert.equal(detailsRes.data.data.id, createdCampaignId);
    assert.equal(detailsRes.data.data.campaignName, 'LifeLink Grand Blood Drive 2026');
    assert.ok(detailsRes.data.data.organizer, 'Should include organizer info');
    console.log('✅ Campaign details retrieved with organizer relation.');

    // Unknown ID
    const notFoundRes = await request(`/campaigns/unknown-uuid-9999`);
    assert.equal(notFoundRes.status, 404);
    console.log('✅ Non-existent campaign properly returns 404.');

    // -------------------------------------------------------------
    // Test 10: Update Blood Campaign
    // -------------------------------------------------------------
    console.log('\n[TEST 10] Update Blood Campaign...');
    // Unauthorized update attempt by donor
    const unauthUpdate = await request(`/campaigns/${createdCampaignId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { campaignName: 'Hacked Campaign Title' },
    });
    assert.equal(unauthUpdate.status, 403, 'Donor must be rejected from updating campaign');
    console.log('✅ Unauthorized update attempt rejected (403).');

    // Invalid time range update
    const invalidTimeUpdate = await request(`/campaigns/${createdCampaignId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        startTime: '05:00 PM',
        endTime: '02:00 PM',
      },
    });
    assert.equal(invalidTimeUpdate.status, 400);
    console.log('✅ Invalid time range rejected on update (400).');

    // Valid update by organizer/manager
    const validUpdate = await request(`/campaigns/${createdCampaignId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${managerToken}` },
      body: {
        campaignName: 'LifeLink Grand Blood Drive 2026 (Updated)',
        targetDonors: 300,
        status: 'Ongoing',
      },
    });
    assert.equal(validUpdate.status, 200);
    assert.equal(validUpdate.data.data.campaignName, 'LifeLink Grand Blood Drive 2026 (Updated)');
    assert.equal(validUpdate.data.data.targetDonors, 300);
    assert.equal(validUpdate.data.data.status, 'Ongoing');
    console.log('✅ Authorized update completed and verified (200).');

    // -------------------------------------------------------------
    // Test 11: Delete / Archive Blood Campaign
    // -------------------------------------------------------------
    console.log('\n[TEST 11] Delete / Archive Blood Campaign...');
    // Unauthorized delete attempt by donor
    const unauthDelete = await request(`/campaigns/${createdCampaignId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(unauthDelete.status, 403, 'Donor cannot delete campaign');
    console.log('✅ Unauthorized delete attempt rejected (403).');

    // Authorized delete / archive
    const validDelete = await request(`/campaigns/${createdCampaignId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${managerToken}` },
    });
    assert.equal(validDelete.status, 200);
    console.log('✅ Campaign deleted/archived successfully (200).');

    // Verify campaign is soft-deleted / archived
    const checkCampaign = await prisma.bloodCampaign.findUnique({
      where: { id: createdCampaignId },
    });
    assert.ok(checkCampaign, 'Database record should be preserved for audit / registrations');
    assert.equal(checkCampaign.isActive, false, 'Campaign isActive should be false');
    assert.equal(checkCampaign.status, 'Cancelled', 'Campaign status should be Cancelled');
    console.log('✅ Database verification: record preserved with isActive = false and status = Cancelled.');

    // Verify GET /campaigns excludes archived campaign for regular public calls
    const listAfterDelete = await request('/campaigns');
    assert.ok(!listAfterDelete.data.data.some(c => c.id === createdCampaignId));
    console.log('✅ Campaign list properly excludes archived campaign.');

    console.log('\n====================================================');
    console.log('🎉 ALL BLOOD CAMPAIGN CRUD INTEGRATION TESTS PASSED!');
    console.log('====================================================\n');

  } finally {
    // -------------------------------------------------------------
    // Cleanup Test Data from Supabase Database
    // -------------------------------------------------------------
    console.log('🧹 Cleaning up test database records...');
    for (const cid of createdCampaignIds) {
      try {
        await prisma.bloodCampaign.deleteMany({ where: { id: cid } });
      } catch (_) {}
    }
    for (const uid of createdUserIds) {
      try {
        await prisma.user.deleteMany({ where: { id: uid } });
      } catch (_) {}
    }
    await prisma.$disconnect();
    console.log('✅ Test cleanup complete.');
  }
}

runTests().catch(err => {
  console.error('❌ Test suite failed:', err);
  process.exit(1);
});
