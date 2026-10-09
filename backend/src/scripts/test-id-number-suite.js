const http = require('http');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const BASE_URL = 'http://localhost:5000/api';

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE_URL + path);
    const postData = body ? JSON.stringify(body) : '';

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(body ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({ status: res.statusCode, body: json });
        } catch (_) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function runTestSuite() {
  console.log('🧪 ========================================================');
  console.log('🧪 STARTING COMPREHENSIVE ID NUMBER VERIFICATION TEST SUITE');
  console.log('🧪 ========================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName, extra = '') {
    if (condition) {
      console.log(`✅ [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`❌ [FAIL] ${testName} ${extra}`);
      failed++;
    }
  }

  const timestamp = Date.now();
  const testIdNum1 = `NIC${timestamp.toString().slice(-8)}V`;
  const testIdNum2 = `NIC${(timestamp + 1).toString().slice(-8)}V`;
  const testEmail1 = `donor_${timestamp}@testlifelink.org`;
  const testEmail2 = `donor_${timestamp + 1}@testlifelink.org`;

  let createdUserId1 = null;
  let authToken1 = null;

  try {
    // ----------------------------------------------------
    // TEST 1: Create user without ID Number -> Should FAIL (400)
    // ----------------------------------------------------
    console.log('\n--- 1. Testing user creation WITHOUT ID Number ---');
    const resNoId = await request('POST', '/auth/register', {
      name: 'No ID User',
      email: `noid_${timestamp}@testlifelink.org`,
      phone: '+94 77 111 2233',
      password: 'password123',
      role: 'donor',
    });
    assert(
      resNoId.status === 400 && resNoId.body.message.includes('ID Number is required'),
      'Create user without ID Number fails with 400 and friendly error message',
      `Got status: ${resNoId.status}, message: ${resNoId.body?.message}`
    );

    // ----------------------------------------------------
    // TEST 2: Create user with invalid ID Number (too short/special chars) -> Should FAIL (400)
    // ----------------------------------------------------
    console.log('\n--- 2. Testing user creation with INVALID ID Number ---');
    const resInvalidId = await request('POST', '/auth/register', {
      name: 'Invalid ID User',
      idNumber: '12@!', // invalid
      email: `invalid_${timestamp}@testlifelink.org`,
      phone: '+94 77 111 2233',
      password: 'password123',
      role: 'donor',
    });
    assert(
      resInvalidId.status === 400 && resInvalidId.body.message.includes('valid ID Number'),
      'Create user with invalid ID Number fails with 400',
      `Got status: ${resInvalidId.status}, message: ${resInvalidId.body?.message}`
    );

    // ----------------------------------------------------
    // TEST 3: Create user with VALID ID Number -> Should SUCCEED (201)
    // ----------------------------------------------------
    console.log('\n--- 3. Testing user creation with VALID ID Number ---');
    const resValid = await request('POST', '/auth/register', {
      name: 'Valid ID User One',
      idNumber: testIdNum1,
      email: testEmail1,
      phone: '+94 77 555 1234',
      password: 'password123',
      role: 'donor',
    });
    assert(
      resValid.status === 201 && resValid.body.success === true,
      'Create user with valid ID Number succeeds (201)',
      `Got status: ${resValid.status}, message: ${resValid.body?.message}`
    );
    assert(
      resValid.body?.data?.user?.idNumber === testIdNum1,
      'User response data includes correct idNumber',
      `Received idNumber: ${resValid.body?.data?.user?.idNumber}`
    );

    createdUserId1 = resValid.body?.data?.user?.id;
    authToken1 = resValid.body?.data?.token;

    // ----------------------------------------------------
    // TEST 4: Create user with DUPLICATE ID Number -> Should FAIL (400)
    // ----------------------------------------------------
    console.log('\n--- 4. Testing user creation with DUPLICATE ID Number ---');
    // Test case-insensitive duplicate (e.g. lowercase version)
    const resDuplicate = await request('POST', '/auth/register', {
      name: 'Duplicate ID User',
      idNumber: testIdNum1.toLowerCase(), // case-insensitive duplicate check!
      email: testEmail2,
      phone: '+94 77 999 8877',
      password: 'password123',
      role: 'recipient',
    });
    assert(
      resDuplicate.status === 400 && resDuplicate.body.message.includes('ID Number already exists'),
      'Create user with duplicate (case-insensitive) ID Number fails with 400',
      `Got status: ${resDuplicate.status}, message: ${resDuplicate.body?.message}`
    );

    // ----------------------------------------------------
    // TEST 5: Verify ID Number is correctly stored in Supabase / PostgreSQL
    // ----------------------------------------------------
    console.log('\n--- 5. Verifying ID Number in Supabase Database ---');
    const dbUser = await prisma.user.findUnique({
      where: { id: createdUserId1 },
    });
    assert(
      dbUser !== null && dbUser.idNumber === testIdNum1,
      'ID Number correctly stored and retrieved from Supabase PostgreSQL',
      `Expected ${testIdNum1}, found: ${dbUser?.idNumber}`
    );

    // ----------------------------------------------------
    // TEST 6: Update user profile with VALID new ID Number -> Should SUCCEED (200)
    // ----------------------------------------------------
    console.log('\n--- 6. Testing updating user ID Number with valid value ---');
    const resUpdate = await request('PUT', '/auth/profile', {
      userId: createdUserId1,
      name: 'Valid ID User Updated',
      idNumber: testIdNum2,
      phone: '+94 77 555 9999',
    }, authToken1);

    assert(
      resUpdate.status === 200 && resUpdate.body.success === true,
      'Update profile with valid new ID Number succeeds',
      `Got status: ${resUpdate.status}, message: ${resUpdate.body?.message}`
    );
    assert(
      resUpdate.body?.data?.idNumber === testIdNum2,
      'Updated profile data returns updated ID Number',
      `Received idNumber: ${resUpdate.body?.data?.idNumber}`
    );

    // Verify in database as well
    const dbUserUpdated = await prisma.user.findUnique({
      where: { id: createdUserId1 },
    });
    assert(
      dbUserUpdated?.idNumber === testIdNum2,
      'Database verifies updated ID Number in Supabase',
      `DB has: ${dbUserUpdated?.idNumber}`
    );

    // ----------------------------------------------------
    // TEST 7: Update to an existing user's ID Number -> Should FAIL (400)
    // ----------------------------------------------------
    console.log('\n--- 7. Testing updating to an existing user\'s duplicate ID Number ---');
    // First create a second user with testIdNum1
    const resUser2 = await request('POST', '/auth/register', {
      name: 'Second User',
      idNumber: testIdNum1,
      email: testEmail2,
      phone: '+94 77 222 3333',
      password: 'password123',
      role: 'recipient',
    });
    assert(resUser2.status === 201, 'Created second user for collision testing');
    const user2Id = resUser2.body?.data?.user?.id;
    const user2Token = resUser2.body?.data?.token;

    // Now try to update user2's ID to testIdNum2 (which belongs to user1)
    const resUpdateCollision = await request('PUT', '/auth/profile', {
      userId: user2Id,
      idNumber: testIdNum2,
    }, user2Token);

    assert(
      resUpdateCollision.status === 400 && resUpdateCollision.body.message.includes('ID Number already exists'),
      'Update to an existing user\'s ID Number fails with 400 duplicate error',
      `Got status: ${resUpdateCollision.status}, message: ${resUpdateCollision.body?.message}`
    );

    // ----------------------------------------------------
    // TEST 8: Verify login and existing user functions still work
    // ----------------------------------------------------
    console.log('\n--- 8. Verifying login and existing user functions ---');
    const resLogin = await request('POST', '/auth/login', {
      email: testEmail1,
      password: 'password123',
    });
    assert(
      resLogin.status === 200 && resLogin.body.success === true,
      'Login with registered user credentials succeeds',
      `Got status: ${resLogin.status}`
    );
    assert(
      resLogin.body?.data?.user?.idNumber === testIdNum2,
      'Login response includes user ID Number',
      `Received: ${resLogin.body?.data?.user?.idNumber}`
    );

    // Verify GET /me
    const resMe = await request('GET', '/auth/me', null, authToken1);
    assert(
      resMe.status === 200 && resMe.body?.data?.idNumber === testIdNum2,
      'GET /auth/me returns current user with ID Number',
      `Received: ${resMe.body?.data?.idNumber}`
    );

    // ----------------------------------------------------
    // TEST 9: Security check - Verify donor search/requests don't leak ID Number
    // ----------------------------------------------------
    console.log('\n--- 9. Security verification: ID Numbers not leaked in public searches ---');
    const resRequests = await request('GET', '/requests');
    const exposedInRequests = JSON.stringify(resRequests.body).includes(testIdNum2);
    assert(
      !exposedInRequests,
      'Security: Public blood requests do not expose donor/recipient ID Numbers'
    );

    // Cleanup test users from DB
    await prisma.user.deleteMany({
      where: { id: { in: [createdUserId1, user2Id] } },
    });
    console.log('\n🧹 Test users cleaned up.');

  } catch (err) {
    console.error('Fatal error during test suite:', err);
    failed++;
  } finally {
    await prisma.$disconnect();
    console.log('\n========================================================');
    console.log(`📊 TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('========================================================\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTestSuite();
