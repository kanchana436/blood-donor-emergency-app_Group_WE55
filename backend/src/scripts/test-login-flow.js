const BASE_URL = 'http://127.0.0.1:5000/api';

async function testLoginFlow() {
  console.log('====================================================');
  console.log('🧪 Starting End-to-End Login Verification Tests');
  console.log('====================================================\n');

  try {
    // ----------------------------------------------------
    // TEST 1: Valid email + valid password (Donor) -> SUCCESS
    // ----------------------------------------------------
    console.log('[TEST 1] Logging in with valid donor credentials (alexander@lifelink.org + password123)...');
    const res1 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'alexander@lifelink.org',
        password: 'password123',
      }),
    });

    const data1 = await res1.json();
    console.log(`Response status: ${res1.status}, success: ${data1.success}`);
    if (res1.status !== 200 || !data1.success || !data1.data?.token || data1.data?.user?.role !== 'donor') {
      throw new Error(`Test 1 Failed: Expected 200 OK with donor role. Got: ${JSON.stringify(data1)}`);
    }
    // Verify password or hash is NOT exposed
    if (data1.data.user.password) {
      throw new Error('Test 1 Security Failed: Password/hash was exposed in user object!');
    }
    console.log(`✅ TEST 1 PASSED: Valid donor login succeeded (Role: ${data1.data.user.role}, User: ${data1.data.user.name}, Token generated)\n`);

    // ----------------------------------------------------
    // TEST 2: Valid email + WRONG password -> REJECT
    // ----------------------------------------------------
    console.log('[TEST 2] Logging in with valid email + WRONG password...');
    const res2 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'alexander@lifelink.org',
        password: 'IncorrectPassword999!',
      }),
    });

    const data2 = await res2.json();
    console.log(`Response status: ${res2.status}, success: ${data2.success}, message: "${data2.message}"`);
    if (res2.status !== 401 || data2.success !== false) {
      throw new Error(`Test 2 Failed: Expected 401 Unauthorized. Got status ${res2.status}`);
    }
    if (data2.message !== 'Invalid email or password.') {
      throw new Error(`Test 2 Failed: Expected message "Invalid email or password.". Got "${data2.message}"`);
    }
    if (data2.data?.token) {
      throw new Error('Test 2 Failed: Token was issued on failed login attempt!');
    }
    console.log('✅ TEST 2 PASSED: Wrong password correctly rejected with 401 and generic message.\n');

    // ----------------------------------------------------
    // TEST 3: Non-existent email + any password -> REJECT (No auto-provisioning!)
    // ----------------------------------------------------
    const fakeEmail = `nonexistent_user_${Date.now()}@domain-fake.test`;
    console.log(`[TEST 3] Logging in with non-existent email: ${fakeEmail}...`);
    const res3 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: fakeEmail,
        password: 'password123',
      }),
    });

    const data3 = await res3.json();
    console.log(`Response status: ${res3.status}, success: ${data3.success}, message: "${data3.message}"`);
    if (res3.status !== 401 || data3.success !== false) {
      throw new Error(`Test 3 Failed: Expected 401 Unauthorized. Got status ${res3.status} (${JSON.stringify(data3)})`);
    }
    if (data3.message !== 'Invalid email or password.') {
      throw new Error(`Test 3 Failed: Expected generic message "Invalid email or password.". Got "${data3.message}"`);
    }
    console.log('✅ TEST 3 PASSED: Non-existent email correctly rejected without auto-provisioning.\n');

    // ----------------------------------------------------
    // TEST 4: Both email and password incorrect -> Generic message (No field leakage)
    // ----------------------------------------------------
    console.log('[TEST 4] Logging in with both email and password incorrect...');
    const res4 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'random_unknown@test.com',
        password: 'random_wrong_password',
      }),
    });

    const data4 = await res4.json();
    console.log(`Response status: ${res4.status}, success: ${data4.success}, message: "${data4.message}"`);
    if (res4.status !== 401 || data4.message !== 'Invalid email or password.') {
      throw new Error(`Test 4 Failed: Expected 401 with generic message. Got: ${JSON.stringify(data4)}`);
    }
    console.log('✅ TEST 4 PASSED: Identical generic message prevents field enumeration.\n');

    // ----------------------------------------------------
    // TEST 5: Case-insensitive login (UPPERCASE email)
    // ----------------------------------------------------
    console.log('[TEST 5] Logging in with UPPERCASE email: ALEXANDER@LIFELINK.ORG...');
    const res5 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'ALEXANDER@LIFELINK.ORG',
        password: 'password123',
      }),
    });

    const data5 = await res5.json();
    console.log(`Response status: ${res5.status}, success: ${data5.success}`);
    if (res5.status !== 200 || !data5.success) {
      throw new Error(`Test 5 Failed: Case-insensitive login failed. Got: ${JSON.stringify(data5)}`);
    }
    console.log('✅ TEST 5 PASSED: Case-insensitive email login works seamlessly.\n');

    // ----------------------------------------------------
    // TEST 6: Recipient login (Role check)
    // ----------------------------------------------------
    console.log('[TEST 6] Logging in with recipient credentials (sarah.p@lifelink.org)...');
    const res6 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'sarah.p@lifelink.org',
        password: 'password123',
      }),
    });

    const data6 = await res6.json();
    console.log(`Response status: ${res6.status}, success: ${data6.success}, role: ${data6.data?.user?.role}`);
    if (res6.status !== 200 || data6.data?.user?.role !== 'recipient') {
      throw new Error(`Test 6 Failed: Expected recipient login. Got: ${JSON.stringify(data6)}`);
    }
    console.log('✅ TEST 6 PASSED: Recipient login succeeded with correct role.\n');

    // ----------------------------------------------------
    // TEST 7: Empty field validation
    // ----------------------------------------------------
    console.log('[TEST 7] Testing empty email and empty password rejection...');
    const resEmptyEmail = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: '', password: 'password123' }),
    });
    const resEmptyPass = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'alexander@lifelink.org', password: '' }),
    });

    if (resEmptyEmail.status !== 400 || resEmptyPass.status !== 400) {
      throw new Error(`Test 7 Failed: Expected 400 Bad Request for empty fields. Got ${resEmptyEmail.status} and ${resEmptyPass.status}`);
    }
    console.log('✅ TEST 7 PASSED: Empty fields correctly rejected with 400 Bad Request.\n');

    console.log('====================================================');
    console.log('🎉 ALL 7 LOGIN VERIFICATION TESTS PASSED SUCCESSFULLY!');
    console.log('====================================================');
  } catch (error) {
    console.error('\n❌ TEST RUN FAILED:', error.message);
    process.exitCode = 1;
  }
}

testLoginFlow();
