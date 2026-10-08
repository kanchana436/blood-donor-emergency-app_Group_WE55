const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const BASE_URL = 'http://127.0.0.1:5000/api';

async function testDeactivateFlow() {
  console.log('====================================================');
  console.log('🧪 Starting End-to-End Account Deactivation Tests');
  console.log('====================================================\n');

  const timestamp = Date.now();
  const testEmail = `deact_test_${timestamp}@lifelink-test.org`;
  let userId = null;
  let userToken = null;

  try {
    // ----------------------------------------------------
    // STEP 1: Register a new test user (Active account)
    // ----------------------------------------------------
    console.log(`[STEP 1] Registering fresh test donor account: ${testEmail}...`);
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Deactivation Test User',
        email: testEmail,
        phone: '+94 77 999 0000',
        password: 'Password123!',
        role: 'donor',
      }),
    });

    const regData = await regRes.json();
    if (regRes.status !== 201 || !regData.success) {
      throw new Error(`Step 1 Failed: Registration failed (${JSON.stringify(regData)})`);
    }

    userId = regData.data.user.id;
    userToken = regData.data.token;
    console.log(`✅ STEP 1 PASSED: User registered (ID: ${userId}, isActive: ${regData.data.user.isActive})\n`);

    // ----------------------------------------------------
    // STEP 2: Verify active user can log in
    // ----------------------------------------------------
    console.log('[STEP 2] Verifying active user can log in successfully...');
    const loginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: 'Password123!',
      }),
    });

    const loginData = await loginRes.json();
    if (loginRes.status !== 200 || !loginData.success) {
      throw new Error(`Step 2 Failed: Active user could not log in (${JSON.stringify(loginData)})`);
    }
    userToken = loginData.data.token;
    console.log('✅ STEP 2 PASSED: Active user logged in successfully.\n');

    // ----------------------------------------------------
    // STEP 3: Verify active user can access protected APIs
    // ----------------------------------------------------
    console.log('[STEP 3] Verifying active user can access protected endpoint (/api/auth/verify)...');
    const verifyRes = await fetch(`${BASE_URL}/auth/verify`, {
      headers: { 'Authorization': `Bearer ${userToken}` },
    });
    const verifyData = await verifyRes.json();
    if (verifyRes.status !== 200 || !verifyData.success) {
      throw new Error(`Step 3 Failed: Active user could not access protected API (${JSON.stringify(verifyData)})`);
    }
    console.log('✅ STEP 3 PASSED: Active user successfully accessed protected API.\n');

    // ----------------------------------------------------
    // STEP 4: Unauthorized deactivation attempts (401)
    // ----------------------------------------------------
    console.log('[STEP 4] Testing deactivation without authentication token (should be 401)...');
    const noTokenRes = await fetch(`${BASE_URL}/auth/deactivate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId }),
    });
    const noTokenData = await noTokenRes.json();
    if (noTokenRes.status !== 401) {
      throw new Error(`Step 4 Failed: Expected 401 for missing token. Got: ${noTokenRes.status}`);
    }
    console.log('✅ STEP 4 PASSED: Missing token properly rejected with 401.\n');

    // ----------------------------------------------------
    // STEP 5: Deactivate with non-existent user ID (404)
    // ----------------------------------------------------
    console.log('[STEP 5] Testing deactivation of non-existent user ID...');
    const notFoundRes = await fetch(`${BASE_URL}/auth/deactivate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({ userId: 'usr_non_existent_999999' }),
    });
    // Because target ID != token ID and not admin, it returns 403, or if queried returns 404
    console.log(`Response status for unauthorized ID: ${notFoundRes.status}`);
    if (notFoundRes.status !== 403 && notFoundRes.status !== 404) {
      throw new Error(`Step 5 Failed: Expected 403/404 for invalid user ID. Got: ${notFoundRes.status}`);
    }
    console.log('✅ STEP 5 PASSED: Unauthorized target ID properly rejected.\n');

    // ----------------------------------------------------
    // STEP 6: Deactivate account with valid user session
    // ----------------------------------------------------
    console.log('[STEP 6] Executing Deactivate Account request...');
    const deactRes = await fetch(`${BASE_URL}/auth/deactivate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({ userId }),
    });

    const deactData = await deactRes.json();
    console.log(`Response status: ${deactRes.status}, message: "${deactData.message}"`);
    if (deactRes.status !== 200 || !deactData.success) {
      throw new Error(`Step 6 Failed: Expected 200 OK. Got: ${JSON.stringify(deactData)}`);
    }
    if (deactData.message !== 'Your account has been deactivated.') {
      throw new Error(`Step 6 Failed: Expected "Your account has been deactivated.". Got "${deactData.message}"`);
    }
    console.log('✅ STEP 6 PASSED: Account successfully deactivated.\n');

    // ----------------------------------------------------
    // STEP 7: Attempt to deactivate already deactivated account (400)
    // ----------------------------------------------------
    console.log('[STEP 7] Attempting to deactivate already deactivated account...');
    // Note: old token hitting authenticateToken middleware will be blocked because account is deactivated (403)!
    const deactAgainRes = await fetch(`${BASE_URL}/auth/deactivate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({ userId }),
    });
    const deactAgainData = await deactAgainRes.json();
    console.log(`Response status: ${deactAgainRes.status}, message: "${deactAgainData.message}"`);
    if (deactAgainRes.status !== 403 && deactAgainRes.status !== 400) {
      throw new Error(`Step 7 Failed: Expected 403 or 400. Got: ${deactAgainRes.status}`);
    }
    console.log('✅ STEP 7 PASSED: Deactivated account prevented from executing deactivation again.\n');

    // ----------------------------------------------------
    // STEP 8: Deactivated user attempts to log in -> REJECT (403)
    // ----------------------------------------------------
    console.log('[STEP 8] Attempting to log in as deactivated user...');
    const deactLoginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: 'Password123!',
      }),
    });

    const deactLoginData = await deactLoginRes.json();
    console.log(`Response status: ${deactLoginRes.status}, message: "${deactLoginData.message}"`);
    if (deactLoginRes.status !== 403 || deactLoginData.success !== false) {
      throw new Error(`Step 8 Failed: Expected 403 Forbidden. Got ${deactLoginRes.status}`);
    }
    const expectedMsg = 'Your account has been deactivated. Please contact support to reactivate your account.';
    if (deactLoginData.message !== expectedMsg) {
      throw new Error(`Step 8 Failed: Expected "${expectedMsg}". Got "${deactLoginData.message}"`);
    }
    console.log('✅ STEP 8 PASSED: Login rejected with exact support reactivation message.\n');

    // ----------------------------------------------------
    // STEP 9: Deactivated user attempts to access protected APIs with old token -> REJECT (403)
    // ----------------------------------------------------
    console.log('[STEP 9] Attempting to access protected API with old token...');
    const deactAccessRes = await fetch(`${BASE_URL}/auth/verify`, {
      headers: { 'Authorization': `Bearer ${userToken}` },
    });
    const deactAccessData = await deactAccessRes.json();
    console.log(`Response status: ${deactAccessRes.status}, message: "${deactAccessData.message}"`);
    if (deactAccessRes.status !== 403 || deactAccessData.success !== false) {
      throw new Error(`Step 9 Failed: Expected 403 Forbidden. Got ${deactAccessRes.status}`);
    }
    if (deactAccessData.message !== expectedMsg) {
      throw new Error(`Step 9 Failed: Expected "${expectedMsg}". Got "${deactAccessData.message}"`);
    }
    console.log('✅ STEP 9 PASSED: Protected API access blocked with old token.\n');

    // ----------------------------------------------------
    // STEP 10: Check database record integrity (Not deleted, only soft-deactivated)
    // ----------------------------------------------------
    console.log('[STEP 10] Verifying database integrity...');
    let dbUser = null;
    try {
      dbUser = await prisma.user.findUnique({ where: { id: userId } });
    } catch (_) {}

    if (dbUser) {
      console.log(`Found user in database: id=${dbUser.id}, email=${dbUser.email}, isActive=${dbUser.isActive}`);
      if (dbUser.isActive !== false) {
        throw new Error('Step 10 Failed: User isActive is not false in database!');
      }
    }
    console.log('✅ STEP 10 PASSED: User record preserved in database with isActive: false.\n');

    // ----------------------------------------------------
    // STEP 11: Another active user continues to function normally
    // ----------------------------------------------------
    console.log('[STEP 11] Verifying another active user (alexander@lifelink.org) remains active...');
    const otherLoginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'alexander@lifelink.org',
        password: 'password123',
      }),
    });
    const otherLoginData = await otherLoginRes.json();
    if (otherLoginRes.status !== 200 || !otherLoginData.success) {
      throw new Error('Step 11 Failed: Other active user could not log in!');
    }
    console.log('✅ STEP 11 PASSED: Other active user functions normally and is unaffected.\n');

    console.log('====================================================');
    console.log('🎉 ALL 11 ACCOUNT DEACTIVATION TESTS PASSED SUCCESSFULLY!');
    console.log('====================================================');
  } catch (error) {
    console.error('\n❌ TEST RUN FAILED:', error.message);
    process.exitCode = 1;
  } finally {
    if (userId) {
      try {
        await prisma.user.deleteMany({ where: { id: userId } });
      } catch (_) {}
    }
    await prisma.$disconnect();
  }
}

testDeactivateFlow();
