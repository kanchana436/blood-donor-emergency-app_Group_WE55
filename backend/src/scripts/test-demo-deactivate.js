const BASE_URL = 'http://127.0.0.1:5000/api';

async function testDemoUserDeactivation() {
  console.log('Testing demo user deactivation flow for alexander@lifelink.org...');

  // 1. Log in as Alexander
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'alexander@lifelink.org',
      password: 'password123',
    }),
  });

  const loginData = await loginRes.json();
  if (loginRes.status !== 200 || !loginData.success) {
    throw new Error(`Login failed: ${JSON.stringify(loginData)}`);
  }
  console.log('✅ Alexander logged in successfully. ID:', loginData.data.user.id);
  const token = loginData.data.token;

  // 2. Deactivate Alexander
  const deactRes = await fetch(`${BASE_URL}/auth/deactivate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({ userId: loginData.data.user.id }),
  });

  const deactData = await deactRes.json();
  console.log('Deactivation response:', deactRes.status, deactData);
  if (deactRes.status !== 200 || !deactData.success) {
    throw new Error(`Deactivation failed: ${JSON.stringify(deactData)}`);
  }
  console.log('✅ Alexander deactivated successfully!');

  // 3. Try to log in again -> MUST BE REJECTED with 403
  const rejectLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'alexander@lifelink.org',
      password: 'password123',
    }),
  });

  const rejectLoginData = await rejectLoginRes.json();
  console.log('Rejected login response:', rejectLoginRes.status, rejectLoginData);
  if (rejectLoginRes.status !== 403) {
    throw new Error(`Expected 403. Got ${rejectLoginRes.status}`);
  }
  if (rejectLoginData.message !== 'Your account has been deactivated. Please contact support to reactivate your account.') {
    throw new Error(`Unexpected message: ${rejectLoginData.message}`);
  }
  console.log('✅ Deactivated login properly rejected with 403 and support message!');

  // 4. Try to access protected endpoint with old token -> MUST BE REJECTED with 403
  const verifyRes = await fetch(`${BASE_URL}/auth/verify`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });
  const verifyData = await verifyRes.json();
  console.log('Verify response with old token:', verifyRes.status, verifyData);
  if (verifyRes.status !== 403) {
    throw new Error(`Expected 403 for old token. Got ${verifyRes.status}`);
  }
  console.log('✅ Protected endpoint blocked with 403!');

  // 5. Try calling /deactivate again -> MUST BE REJECTED with 400
  const deactAgainRes = await fetch(`${BASE_URL}/auth/deactivate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
  });
  const deactAgainData = await deactAgainRes.json();
  console.log('Deactivate again response:', deactAgainRes.status, deactAgainData);
  if (deactAgainRes.status !== 400) {
    throw new Error(`Expected 400 for already deactivated account. Got ${deactAgainRes.status}`);
  }
  console.log('✅ Repeated deactivation properly rejected with 400 "Account is already deactivated."!');

  console.log('\n🎉 ALL DEMO DEACTIVATION TESTS PASSED!');
}

testDemoUserDeactivation().catch(err => {
  console.error('❌ Test failed:', err.message);
  process.exitCode = 1;
});
