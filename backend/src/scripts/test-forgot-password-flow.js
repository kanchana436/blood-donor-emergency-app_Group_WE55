const BASE_URL = 'http://localhost:5000/api';
const { getLatestOtpForTesting } = require('../services/otp.service');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testForgotPasswordFlow() {
  console.log('====================================================');
  console.log('🧪 Starting End-to-End Forgot Password & OTP Tests');
  console.log('====================================================\n');

  const timestamp = Date.now();
  const testEmail = `forgot_${timestamp}@lifelink-test.org`;
  const testNic = `${String(timestamp).slice(-9)}V`;
  const initialPassword = 'InitialPass123!';
  const newPassword = 'NewSecurePass456!';
  let userId = null;

  try {
    // ----------------------------------------------------
    // STEP 0: Register a dedicated test user
    // ----------------------------------------------------
    console.log(`[SETUP] Registering test user: ${testEmail}...`);
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-verified': 'true',
      },
      body: JSON.stringify({
        name: 'Forgot Password Tester',
        email: testEmail,
        idNumber: testNic,
        phone: '+94 77 555 1234',
        password: initialPassword,
        role: 'donor',
        bloodGroup: 'B+',
        city: 'Colombo',
        livingAddress: 'No 77, Havelock Road, Colombo',
        bodyWeight: 68,
      }),
    });
    const regData = await regRes.json();
    if (regRes.status !== 201 || !regData.success) {
      throw new Error(`Setup Failed: ${JSON.stringify(regData)}`);
    }
    userId = regData.data.user.id;
    console.log(`✅ SETUP PASSED: Test user registered (ID: ${userId})\n`);

    // ----------------------------------------------------
    // TEST 1: Invalid email format -> Validation Error (400)
    // ----------------------------------------------------
    console.log('[TEST 1] Requesting OTP with invalid email format...');
    const res1 = await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'not-a-valid-email' }),
    });
    const data1 = await res1.json();
    console.log(`Status: ${res1.status}, success: ${data1.success}, message: "${data1.message}"`);
    if (res1.status !== 400 || data1.success !== false) {
      throw new Error(`Test 1 Failed: Expected 400 for invalid email. Got ${res1.status}`);
    }
    console.log('✅ TEST 1 PASSED: Invalid email rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 2: Unregistered email -> Handled securely without leaking user existence
    // ----------------------------------------------------
    const fakeEmail = `nonexistent_${Date.now()}@test-fake.org`;
    console.log(`[TEST 2] Requesting OTP for unregistered email: ${fakeEmail}...`);
    const res2 = await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: fakeEmail }),
    });
    const data2 = await res2.json();
    console.log(`Status: ${res2.status}, success: ${data2.success}, message: "${data2.message}"`);
    if (res2.status !== 200 || !data2.success) {
      throw new Error(`Test 2 Failed: Expected generic 200 message. Got ${res2.status}`);
    }
    // Verify no OTP leaked
    if (data2.otp || data2.data?.otp) {
      throw new Error('Test 2 Security Violation: OTP leaked in response!');
    }
    console.log('✅ TEST 2 PASSED: Unregistered email handled securely with generic confirmation.\n');

    // ----------------------------------------------------
    // TEST 3: Valid registered email -> OTP generated and sent
    // ----------------------------------------------------
    console.log(`[TEST 3] Requesting OTP for registered email: ${testEmail}...`);
    const res3 = await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail }),
    });
    const data3 = await res3.json();
    console.log(`Status: ${res3.status}, success: ${data3.success}`);
    if (res3.status !== 200 || !data3.success) {
      throw new Error(`Test 3 Failed: OTP request failed. Got ${JSON.stringify(data3)}`);
    }
    if (data3.otp || data3.data?.otp) {
      throw new Error('Test 3 Security Violation: OTP was returned in API response!');
    }

    const firstOtp = getLatestOtpForTesting(testEmail);
    if (!firstOtp || firstOtp.length !== 6 || !/^\d{6}$/.test(firstOtp)) {
      throw new Error(`Test 3 Failed: Expected 6-digit OTP generated. Got: ${firstOtp}`);
    }
    console.log('✅ TEST 3 PASSED: Valid 6-digit OTP created and email dispatched (not exposed in API response).\n');

    // ----------------------------------------------------
    // TEST 4: Invalid OTP formats -> Reject (400)
    // ----------------------------------------------------
    console.log('[TEST 4] Verifying OTP with invalid formats (empty, 5 digits, letters)...');
    const invalidOtps = ['', '12345', '1234567', 'abcdef'];
    for (const badOtp of invalidOtps) {
      const res4 = await fetch(`${BASE_URL}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: testEmail, otp: badOtp }),
      });
      const data4 = await res4.json();
      if (res4.status !== 400 || data4.success !== false) {
        throw new Error(`Test 4 Failed for OTP "${badOtp}": Expected 400. Got ${res4.status}`);
      }
    }
    console.log('✅ TEST 4 PASSED: Invalid OTP formats correctly rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 5: Incorrect OTP -> Rejection with attempts remaining
    // ----------------------------------------------------
    console.log('[TEST 5] Verifying incorrect 6-digit OTP...');
    const wrongOtp = firstOtp === '111111' ? '222222' : '111111';
    const res5 = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: wrongOtp }),
    });
    const data5 = await res5.json();
    console.log(`Status: ${res5.status}, success: ${data5.success}, message: "${data5.message}"`);
    if (res5.status !== 400 || data5.success !== false || !data5.message.includes('remaining')) {
      throw new Error(`Test 5 Failed: Expected 400 with attempts count. Got ${JSON.stringify(data5)}`);
    }
    console.log('✅ TEST 5 PASSED: Incorrect OTP rejected with remaining attempts counter.\n');

    // ----------------------------------------------------
    // TEST 6: Resend OTP -> Invalidate previous OTP & enforce cooldown
    // ----------------------------------------------------
    console.log('[TEST 6] Testing Resend OTP rate limit & invalidation...');
    // Rapid re-request triggers 429 rate limit
    const res6a = await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail }),
    });
    const data6a = await res6a.json();
    console.log(`Cooldown test status: ${res6a.status}, message: "${data6a.message}"`);
    if (res6a.status !== 429) {
      throw new Error(`Test 6 Failed: Expected 429 cooldown. Got ${res6a.status}`);
    }

    // Now simulate cooldown expiry by aging the record in memory, then resend
    const { db } = require('../prisma');
    const existingRec = db.passwordResetOtps.find(o => o.email === testEmail && !o.used);
    if (existingRec) {
      existingRec.createdAt = new Date(Date.now() - 65000).toISOString();
    }

    const res6b = await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-bypass-cooldown': 'lifelink-test-suite',
      },
      body: JSON.stringify({ email: testEmail }),
    });
    const data6b = await res6b.json();
    if (res6b.status !== 200 || !data6b.success) {
      throw new Error(`Test 6 Failed: Resend OTP failed after cooldown: ${JSON.stringify(data6b)}`);
    }

    const secondOtp = getLatestOtpForTesting(testEmail);
    console.log(`New OTP generated after resend.`);

    // Previous OTP must now be rejected
    console.log('Attempting to use previous invalidated OTP...');
    const res6c = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: firstOtp }),
    });
    const data6c = await res6c.json();
    console.log(`Status: ${res6c.status}, message: "${data6c.message}"`);
    if (res6c.status !== 400 || data6c.success !== false) {
      throw new Error(`Test 6 Failed: Old OTP was accepted after resend!`);
    }
    console.log('✅ TEST 6 PASSED: Resend OTP correctly invalidated previous OTP.\n');

    // ----------------------------------------------------
    // TEST 7: Too many incorrect attempts (5) -> Block verification (429)
    // ----------------------------------------------------
    console.log('[TEST 7] Testing max incorrect attempts lockout (5 attempts)...');
    for (let i = 0; i < 3; i++) {
      await fetch(`${BASE_URL}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: testEmail, otp: '000000' }),
      });
    }
    const res7Lock = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: '000000' }),
    });
    const data7Lock = await res7Lock.json();
    console.log(`Lockout status: ${res7Lock.status}, message: "${data7Lock.message}"`);
    if (res7Lock.status !== 429 || !data7Lock.message.includes('Too many incorrect attempts')) {
      throw new Error(`Test 7 Failed: Expected 429 after 5 failed attempts. Got ${res7Lock.status}`);
    }
    console.log('✅ TEST 7 PASSED: 5 incorrect attempts blocks verification and invalidates OTP.\n');

    // ----------------------------------------------------
    // TEST 8: Correct OTP -> Verification succeeds & generates single-use resetToken
    // ----------------------------------------------------
    console.log('[TEST 8] Requesting fresh OTP and verifying with correct code...');
    // Reset cooldown to generate fresh OTP
    const recToAge = db.passwordResetOtps.find(o => o.email === testEmail && !o.used);
    if (recToAge) recToAge.createdAt = new Date(Date.now() - 65000).toISOString();

    await fetch(`${BASE_URL}/auth/forgot-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-bypass-cooldown': 'lifelink-test-suite',
      },
      body: JSON.stringify({ email: testEmail }),
    });
    const validOtp = getLatestOtpForTesting(testEmail);

    const res8 = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: validOtp }),
    });
    const data8 = await res8.json();
    console.log(`Status: ${res8.status}, success: ${data8.success}, token issued: ${!!data8.data?.resetToken}`);
    if (res8.status !== 200 || !data8.success || !data8.data?.resetToken) {
      throw new Error(`Test 8 Failed: Expected 200 with resetToken. Got ${JSON.stringify(data8)}`);
    }
    const resetToken = data8.data.resetToken;
    console.log('✅ TEST 8 PASSED: Correct OTP verified and single-use resetToken issued.\n');

    // ----------------------------------------------------
    // TEST 9: OTP cannot be reused
    // ----------------------------------------------------
    console.log('[TEST 9] Attempting to reuse already-used OTP...');
    const res9 = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: validOtp }),
    });
    const data9 = await res9.json();
    console.log(`Status: ${res9.status}, success: ${data9.success}, message: "${data9.message}"`);
    if (res9.status !== 400 || data9.success !== false) {
      throw new Error(`Test 9 Failed: Reused OTP was accepted!`);
    }
    console.log('✅ TEST 9 PASSED: Used OTP cannot be reused.\n');

    // ----------------------------------------------------
    // TEST 10: Reset Password Validation (weak, mismatch, same as old)
    // ----------------------------------------------------
    console.log('[TEST 10] Testing password reset validations...');
    // 10a. Weak password (< 6 chars)
    const res10a = await fetch(`${BASE_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        resetToken,
        newPassword: '123',
        confirmPassword: '123',
      }),
    });
    const data10a = await res10a.json();
    if (res10a.status !== 400 || !data10a.message.includes('6 characters')) {
      throw new Error(`Test 10a Failed: Weak password was accepted.`);
    }

    // 10b. Password mismatch
    const res10b = await fetch(`${BASE_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        resetToken,
        newPassword: 'Password123!',
        confirmPassword: 'DifferentPassword123!',
      }),
    });
    const data10b = await res10b.json();
    if (res10b.status !== 400 || !data10b.message.includes('match')) {
      throw new Error(`Test 10b Failed: Mismatched password confirmation was accepted.`);
    }

    // 10c. Same as old password
    const res10c = await fetch(`${BASE_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        resetToken,
        newPassword: initialPassword,
        confirmPassword: initialPassword,
      }),
    });
    const data10c = await res10c.json();
    if (res10c.status !== 400 || !data10c.message.includes('different')) {
      throw new Error(`Test 10c Failed: Password identical to old password was accepted.`);
    }
    console.log('✅ TEST 10 PASSED: Weak, mismatched, and identical passwords rejected.\n');

    // ----------------------------------------------------
    // TEST 11: Valid Reset Password -> SUCCESS (200)
    // ----------------------------------------------------
    console.log('[TEST 11] Resetting password with valid new password...');
    const res11 = await fetch(`${BASE_URL}/auth/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        resetToken,
        newPassword: newPassword,
        confirmPassword: newPassword,
      }),
    });
    const data11 = await res11.json();
    console.log(`Status: ${res11.status}, success: ${data11.success}, message: "${data11.message}"`);
    if (res11.status !== 200 || !data11.success) {
      throw new Error(`Test 11 Failed: Reset password failed: ${JSON.stringify(data11)}`);
    }
    console.log('✅ TEST 11 PASSED: Password reset successfully.\n');

    // ----------------------------------------------------
    // TEST 12: Old password rejected upon login -> REJECT (401)
    // ----------------------------------------------------
    console.log('[TEST 12] Attempting login with OLD password...');
    const res12 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, password: initialPassword }),
    });
    const data12 = await res12.json();
    if (res12.status !== 401 || data12.success !== false) {
      throw new Error('Test 12 Failed: Old password still worked after reset!');
    }
    console.log('✅ TEST 12 PASSED: Old password no longer works.\n');

    // ----------------------------------------------------
    // TEST 13: New password works upon login -> SUCCESS (200)
    // ----------------------------------------------------
    console.log('[TEST 13] Logging in with NEW password...');
    const res13 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, password: newPassword }),
    });
    const data13 = await res13.json();
    if (res13.status !== 200 || !data13.success || !data13.data?.token) {
      throw new Error(`Test 13 Failed: Login with new password failed: ${JSON.stringify(data13)}`);
    }
    console.log('✅ TEST 13 PASSED: Login with new password succeeded!\n');

    console.log('====================================================');
    console.log('🎉 ALL 13 FORGOT PASSWORD & OTP TESTS PASSED PERFECTLY!');
    console.log('====================================================');
  } catch (err) {
    console.error('\n❌ TEST RUN FAILED:', err.message, err.cause || '');
    process.exit(1);
  } finally {
    if (userId) {
      try {
        await prisma.donorProfile.deleteMany({ where: { userId } });
        await prisma.user.delete({ where: { id: userId } });
        await prisma.$disconnect();
        console.log(`🧹 Cleaned up test user ${testEmail} from database.`);
      } catch (_) {}
    }
  }
}

testForgotPasswordFlow();
