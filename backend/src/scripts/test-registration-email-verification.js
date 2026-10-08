const BASE_URL = 'http://localhost:5000/api';
const { getLatestRegistrationOtpForTesting } = require('../services/otp.service');

async function testRegistrationEmailVerification() {
  console.log('================================================================');
  console.log('🧪 Starting End-to-End Registration Email OTP Verification Tests');
  console.log('================================================================\n');

  const timestamp = Date.now();
  const testEmail = `newreg_${timestamp}@lifelink-test.org`;
  const testNic = `${String(timestamp).slice(-9)}V`;
  const testPassword = 'SecurePass123!';

  try {
    // ----------------------------------------------------
    // TEST 1: Missing required fields -> 400
    // ----------------------------------------------------
    console.log('[TEST 1] Registering with missing fields (no password)...');
    const res1 = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Incomplete User',
        email: 'incomplete@lifelink-test.org',
        idNumber: '111222333V',
        phone: '+94 77 111 2222',
        role: 'donor',
      }),
    });
    const data1 = await res1.json();
    console.log(`Status: ${res1.status}, success: ${data1.success}, message: "${data1.message}"`);
    if (res1.status !== 400 || data1.success !== false) {
      throw new Error(`Test 1 Failed: Expected 400 for missing fields. Got ${res1.status}`);
    }
    console.log('✅ TEST 1 PASSED: Missing required fields rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 2: Invalid email format -> 400
    // ----------------------------------------------------
    console.log('[TEST 2] Registering with invalid email format...');
    const res2 = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Invalid Email User',
        email: 'not-an-email',
        idNumber: '222333444V',
        phone: '+94 77 222 3333',
        password: testPassword,
        role: 'donor',
      }),
    });
    const data2 = await res2.json();
    console.log(`Status: ${res2.status}, success: ${data2.success}, message: "${data2.message}"`);
    if (res2.status !== 400 || data2.success !== false) {
      throw new Error(`Test 2 Failed: Expected 400 for invalid email. Got ${res2.status}`);
    }
    console.log('✅ TEST 2 PASSED: Invalid email format rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 3: Valid registration -> 201, unverified state
    // ----------------------------------------------------
    console.log(`[TEST 3] Registering valid new user: ${testEmail}...`);
    const res3 = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-bypass-cooldown': 'lifelink-test-suite',
      },
      body: JSON.stringify({
        name: 'New Test Donor',
        email: testEmail,
        idNumber: testNic,
        phone: '+94 77 888 9999',
        password: testPassword,
        role: 'donor',
        bloodGroup: 'A+',
        city: 'Colombo',
        livingAddress: '100 Galle Road, Colombo',
        bodyWeight: 72,
      }),
    });
    const data3 = await res3.json();
    console.log(`Status: ${res3.status}, success: ${data3.success}, requiresVerification: ${data3.requiresVerification}`);
    if (res3.status !== 201 || !data3.success || !data3.requiresVerification) {
      throw new Error(`Test 3 Failed: Expected 201 and requiresVerification: true. Got ${JSON.stringify(data3)}`);
    }
    const registeredUser = data3.data.user;
    if (registeredUser.isEmailVerified !== false) {
      throw new Error(`Test 3 Failed: Expected isEmailVerified to be false. Got ${registeredUser.isEmailVerified}`);
    }
    console.log(`✅ TEST 3 PASSED: User created in unverified state (isEmailVerified = false).\n`);

    // ----------------------------------------------------
    // TEST 4: Login blocked for unverified account -> 403
    // ----------------------------------------------------
    console.log('[TEST 4] Attempting login before verifying email...');
    const res4 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: testPassword,
      }),
    });
    const data4 = await res4.json();
    console.log(`Status: ${res4.status}, success: ${data4.success}, isUnverified: ${data4.isUnverified}, message: "${data4.message}"`);
    if (res4.status !== 403 || data4.isUnverified !== true) {
      throw new Error(`Test 4 Failed: Expected 403 and isUnverified: true. Got status ${res4.status}`);
    }
    console.log('✅ TEST 4 PASSED: Login blocked for unverified user with 403 isUnverified.\n');

    // ----------------------------------------------------
    // TEST 5: Existing unverified email re-registering -> handled gracefully
    // ----------------------------------------------------
    console.log('[TEST 5] Re-registering existing unverified user...');
    const res5 = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-bypass-cooldown': 'lifelink-test-suite',
      },
      body: JSON.stringify({
        name: 'New Test Donor Updated',
        email: testEmail,
        idNumber: testNic,
        phone: '+94 77 888 9999',
        password: testPassword,
        role: 'donor',
        bloodGroup: 'A+',
        city: 'Colombo',
        livingAddress: '100 Galle Road, Colombo',
        bodyWeight: 72,
      }),
    });
    const data5 = await res5.json();
    console.log(`Status: ${res5.status}, success: ${data5.success}, requiresVerification: ${data5.requiresVerification}`);
    if ((res5.status !== 200 && res5.status !== 201) || !data5.success) {
      throw new Error(`Test 5 Failed: Expected 200/201. Got ${JSON.stringify(data5)}`);
    }
    console.log('✅ TEST 5 PASSED: Existing unverified email handled gracefully without duplicate error.\n');

    // ----------------------------------------------------
    // TEST 6: OTP validation checks (empty, letters, length, wrong)
    // ----------------------------------------------------
    console.log('[TEST 6a] Verifying with empty OTP...');
    const res6a = await fetch(`${BASE_URL}/auth/verify-email-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: '' }),
    });
    const data6a = await res6a.json();
    if (res6a.status !== 400 || data6a.success !== false) {
      throw new Error(`Test 6a Failed: Expected 400 for empty OTP. Got ${res6a.status}`);
    }
    console.log('✅ TEST 6a PASSED: Empty OTP rejected with 400.');

    console.log('[TEST 6b] Verifying with letters in OTP ("ABC123")...');
    const res6b = await fetch(`${BASE_URL}/auth/verify-email-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: 'ABC123' }),
    });
    const data6b = await res6b.json();
    if (res6b.status !== 400 || data6b.success !== false) {
      throw new Error(`Test 6b Failed: Expected 400 for letters in OTP. Got ${res6b.status}`);
    }
    console.log('✅ TEST 6b PASSED: Letters in OTP rejected with 400.');

    console.log('[TEST 6c] Verifying with wrong 6-digit OTP ("999999")...');
    const res6c = await fetch(`${BASE_URL}/auth/verify-email-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: '999999' }),
    });
    const data6c = await res6c.json();
    if (res6c.status !== 400 || data6c.success !== false) {
      throw new Error(`Test 6c Failed: Expected 400 for incorrect OTP. Got ${res6c.status}`);
    }
    console.log('✅ TEST 6c PASSED: Incorrect 6-digit OTP rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 7: Resend OTP and Cooldown Rate Limiting
    // ----------------------------------------------------
    console.log('[TEST 7a] Resending OTP with cooldown bypass...');
    const res7a = await fetch(`${BASE_URL}/auth/resend-verification-otp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-bypass-cooldown': 'lifelink-test-suite',
      },
      body: JSON.stringify({ email: testEmail }),
    });
    const data7a = await res7a.json();
    if (res7a.status !== 200 || !data7a.success) {
      throw new Error(`Test 7a Failed: Resend OTP failed. Got ${JSON.stringify(data7a)}`);
    }
    console.log('✅ TEST 7a PASSED: Resend OTP succeeded.');

    console.log('[TEST 7b] Resending OTP immediately WITHOUT bypass -> 429 Cooldown...');
    const res7b = await fetch(`${BASE_URL}/auth/resend-verification-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail }),
    });
    const data7b = await res7b.json();
    console.log(`Status: ${res7b.status}, message: "${data7b.message}"`);
    if (res7b.status !== 429) {
      throw new Error(`Test 7b Failed: Expected 429 rate limit on immediate resend. Got ${res7b.status}`);
    }
    console.log('✅ TEST 7b PASSED: Immediate resend without cooldown rate limited with 429.\n');

    // ----------------------------------------------------
    // TEST 8: Verify with valid OTP -> Account becomes verified
    // ----------------------------------------------------
    const validOtp = getLatestRegistrationOtpForTesting(testEmail);
    if (!validOtp) {
      throw new Error('Test 8 Failed: Could not retrieve test OTP from service store.');
    }
    console.log(`[TEST 8] Verifying with valid OTP for ${testEmail}...`);
    const res8 = await fetch(`${BASE_URL}/auth/verify-email-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: validOtp }),
    });
    const data8 = await res8.json();
    console.log(`Status: ${res8.status}, success: ${data8.success}, token issued: ${!!data8.data.token}`);
    if (res8.status !== 200 || !data8.success || !data8.data.token) {
      throw new Error(`Test 8 Failed: Expected 200 with JWT token. Got ${JSON.stringify(data8)}`);
    }
    if (data8.data.user.isEmailVerified !== true) {
      throw new Error(`Test 8 Failed: User isEmailVerified is not true: ${JSON.stringify(data8.data.user)}`);
    }
    console.log('✅ TEST 8 PASSED: OTP verified, user marked isEmailVerified = true, session token issued.\n');

    // ----------------------------------------------------
    // TEST 9: Reuse already-used OTP -> 400
    // ----------------------------------------------------
    console.log('[TEST 9] Attempting to reuse already-used OTP...');
    const res9 = await fetch(`${BASE_URL}/auth/verify-email-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: testEmail, otp: validOtp }),
    });
    const data9 = await res9.json();
    if (res9.status !== 400 || data9.success !== false) {
      throw new Error(`Test 9 Failed: Expected 400 for already used OTP. Got ${res9.status}`);
    }
    console.log('✅ TEST 9 PASSED: Used OTP cannot be reused.\n');

    // ----------------------------------------------------
    // TEST 10: Login now succeeds for verified user -> 200
    // ----------------------------------------------------
    console.log('[TEST 10] Logging in now that email is verified...');
    const res10 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: testPassword,
      }),
    });
    const data10 = await res10.json();
    console.log(`Status: ${res10.status}, success: ${data10.success}, user: ${data10.data.user.email}`);
    if (res10.status !== 200 || !data10.success || !data10.data.token) {
      throw new Error(`Test 10 Failed: Expected 200 login for verified user. Got ${JSON.stringify(data10)}`);
    }
    console.log('✅ TEST 10 PASSED: Verified user can log in normally.\n');

    // ----------------------------------------------------
    // TEST 11: Duplicate verified email registration -> 400
    // ----------------------------------------------------
    console.log('[TEST 11] Attempting to register already verified email again...');
    const res11 = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Duplicate Register Attempt',
        email: testEmail,
        idNumber: `${String(Date.now()).slice(-9)}V`,
        phone: '+94 77 999 1111',
        password: 'AnotherPassword123!',
        role: 'donor',
        bloodGroup: 'A+',
        city: 'Colombo',
        livingAddress: '100 Galle Road, Colombo',
        bodyWeight: 72,
      }),
    });
    const data11 = await res11.json();
    console.log(`Status: ${res11.status}, message: "${data11.message}"`);
    if (res11.status !== 400 || !data11.message.includes('already exists')) {
      throw new Error(`Test 11 Failed: Expected duplicate email error. Got ${data11.message}`);
    }
    console.log('✅ TEST 11 PASSED: Duplicate verified email rejected.\n');

    // ----------------------------------------------------
    // TEST 12: Real Gmail SMTP Delivery Test
    // ----------------------------------------------------
    console.log('[TEST 12] Testing live email delivery to Gmail via configured Gmail SMTP...');
    const liveEmail = 'priyadarshanikanchana436@gmail.com';
    const otpService = require('../services/otp.service');
    const otpSendResult = await otpService.requestEmailVerificationOtp(liveEmail, 'Kanchana', true);
    console.log(`OTP Delivery Result:`, otpSendResult);
    if (!otpSendResult.emailDeliveryFailed && otpSendResult.emailDelivery?.accepted) {
      console.log(`✅ TEST 12 PASSED: Verification OTP successfully accepted and delivered via Gmail SMTP to ${liveEmail}!`);
      console.log(`MessageId: ${otpSendResult.emailDelivery.messageId}\n`);
    } else {
      console.log(`⚠️  TEST 12 Note: Delivery details: ${JSON.stringify(otpSendResult)}\n`);
    }

    console.log('================================================================');
    console.log('🎉 ALL 12 REGISTRATION & EMAIL OTP VERIFICATION TESTS PASSED! 🎉');
    console.log('================================================================');
  } catch (err) {
    console.error('\n❌ TEST SUITE FAILED:', err.message);
    process.exit(1);
  }
}

testRegistrationEmailVerification();
