const BASE_URL = 'http://localhost:5000/api';

async function testChangePasswordFlow() {
  console.log('====================================================');
  console.log('🧪 Starting End-to-End Change Password Verification Tests');
  console.log('====================================================\n');

  const timestamp = Date.now();
  const testEmail = `chgpass_${timestamp}@lifelink-test.org`;
  const uniqueNic = `${String(timestamp).slice(-9)}V`;
  const initialPassword = 'InitialPass123!';
  const updatedPassword = 'NewSecretPass456!';
  let userToken = null;
  let userId = null;

  try {
    // ----------------------------------------------------
    // STEP 0: Register a dedicated test user
    // ----------------------------------------------------
    console.log(`[SETUP] Registering fresh test user: ${testEmail} (NIC: ${uniqueNic})...`);
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-test-verified': 'true',
      },
      body: JSON.stringify({
        name: 'Password Test User',
        email: testEmail,
        idNumber: uniqueNic,
        phone: '+94 77 123 9999',
        password: initialPassword,
        role: 'donor',
        bloodGroup: 'O+',
        city: 'Colombo',
        livingAddress: 'No 12, Galle Road, Colombo',
        bodyWeight: 65,
      }),
    });

    const regData = await regRes.json();
    if (regRes.status !== 201 || !regData.success) {
      throw new Error(`Setup Failed: Registration failed (${JSON.stringify(regData)})`);
    }

    userId = regData.data.user.id;
    userToken = regData.data.token;
    console.log(`✅ SETUP PASSED: Test user registered (ID: ${userId}, Token generated)\n`);

    // ----------------------------------------------------
    // TEST 1: Unauthenticated user attempts to change password -> REJECT (401)
    // ----------------------------------------------------
    console.log('[TEST 1] Unauthenticated request to /auth/change-password...');
    const res1 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: updatedPassword,
        confirmPassword: updatedPassword,
      }),
    });
    const data1 = await res1.json();
    console.log(`Response status: ${res1.status}, success: ${data1.success}, message: "${data1.message}"`);
    if (res1.status !== 401 || data1.success !== false) {
      throw new Error(`Test 1 Failed: Expected 401 Unauthorized without token. Got ${res1.status}`);
    }
    console.log('✅ TEST 1 PASSED: Unauthenticated user rejected with 401.\n');

    // ----------------------------------------------------
    // TEST 2: Empty current password -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 2] Changing password with empty current password...');
    const res2 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: '   ',
        newPassword: updatedPassword,
        confirmPassword: updatedPassword,
      }),
    });
    const data2 = await res2.json();
    console.log(`Response status: ${res2.status}, success: ${data2.success}, message: "${data2.message}"`);
    if (res2.status !== 400 || data2.success !== false || !data2.message.includes('Current password')) {
      throw new Error(`Test 2 Failed: Expected 400 with current password error. Got: ${JSON.stringify(data2)}`);
    }
    console.log('✅ TEST 2 PASSED: Empty current password rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 3: Empty new password -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 3] Changing password with empty new password...');
    const res3 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: '',
        confirmPassword: updatedPassword,
      }),
    });
    const data3 = await res3.json();
    console.log(`Response status: ${res3.status}, success: ${data3.success}, message: "${data3.message}"`);
    if (res3.status !== 400 || data3.success !== false || !data3.message.includes('New password')) {
      throw new Error(`Test 3 Failed: Expected 400 with new password error. Got: ${JSON.stringify(data3)}`);
    }
    console.log('✅ TEST 3 PASSED: Empty new password rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 4: Empty confirmation -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 4] Changing password with empty confirmation...');
    const res4 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: updatedPassword,
        confirmPassword: '',
      }),
    });
    const data4 = await res4.json();
    console.log(`Response status: ${res4.status}, success: ${data4.success}, message: "${data4.message}"`);
    if (res4.status !== 400 || data4.success !== false || !data4.message.includes('confirmation')) {
      throw new Error(`Test 4 Failed: Expected 400 with confirmation error. Got: ${JSON.stringify(data4)}`);
    }
    console.log('✅ TEST 4 PASSED: Empty confirmation rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 5: Weak/invalid new password (< 6 chars) -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 5] Changing password with weak new password (< 6 chars)...');
    const res5 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: '123',
        confirmPassword: '123',
      }),
    });
    const data5 = await res5.json();
    console.log(`Response status: ${res5.status}, success: ${data5.success}, message: "${data5.message}"`);
    if (res5.status !== 400 || data5.success !== false || !data5.message.includes('at least 6 characters')) {
      throw new Error(`Test 5 Failed: Expected 400 for password < 6 chars. Got: ${JSON.stringify(data5)}`);
    }
    console.log('✅ TEST 5 PASSED: Weak new password rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 6: New password and confirmation do not match -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 6] New password and confirmation mismatch...');
    const res6 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: updatedPassword,
        confirmPassword: 'DifferentPass999!',
      }),
    });
    const data6 = await res6.json();
    console.log(`Response status: ${res6.status}, success: ${data6.success}, message: "${data6.message}"`);
    if (res6.status !== 400 || data6.success !== false || !data6.message.includes('match')) {
      throw new Error(`Test 6 Failed: Expected 400 for password mismatch. Got: ${JSON.stringify(data6)}`);
    }
    console.log('✅ TEST 6 PASSED: Password mismatch rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 7: New password same as current password -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 7] New password identical to current password...');
    const res7 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: initialPassword,
        confirmPassword: initialPassword,
      }),
    });
    const data7 = await res7.json();
    console.log(`Response status: ${res7.status}, success: ${data7.success}, message: "${data7.message}"`);
    if (res7.status !== 400 || data7.success !== false || !data7.message.includes('different')) {
      throw new Error(`Test 7 Failed: Expected 400 for identical password. Got: ${JSON.stringify(data7)}`);
    }
    console.log('✅ TEST 7 PASSED: Identical password rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 8: Incorrect current password -> REJECT (400)
    // ----------------------------------------------------
    console.log('[TEST 8] Changing password with incorrect current password...');
    const res8 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: 'WrongCurrentPassword999!',
        newPassword: updatedPassword,
        confirmPassword: updatedPassword,
      }),
    });
    const data8 = await res8.json();
    console.log(`Response status: ${res8.status}, success: ${data8.success}, message: "${data8.message}"`);
    if (res8.status !== 400 || data8.success !== false || !data8.message.toLowerCase().includes('incorrect current password')) {
      throw new Error(`Test 8 Failed: Expected 400 for incorrect current password. Got: ${JSON.stringify(data8)}`);
    }
    console.log('✅ TEST 8 PASSED: Incorrect current password rejected with 400.\n');

    // ----------------------------------------------------
    // TEST 9: Correct current password + valid new password -> SUCCESS (200)
    // ----------------------------------------------------
    console.log('[TEST 9] Valid password change with correct current password...');
    const res9 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        currentPassword: initialPassword,
        newPassword: updatedPassword,
        confirmPassword: updatedPassword,
      }),
    });
    const data9 = await res9.json();
    console.log(`Response status: ${res9.status}, success: ${data9.success}, message: "${data9.message}"`);
    if (res9.status !== 200 || !data9.success) {
      throw new Error(`Test 9 Failed: Expected 200 OK. Got: ${JSON.stringify(data9)}`);
    }
    if (data9.message !== 'Password changed successfully.') {
      throw new Error(`Test 9 Failed: Expected exact message "Password changed successfully.". Got: "${data9.message}"`);
    }
    // Verify security: passwords must NOT be in the response
    if (data9.password || data9.data?.password || data9.data?.currentPassword || data9.data?.newPassword) {
      throw new Error('Test 9 Security Violation: Password was returned in API response!');
    }
    console.log('✅ TEST 9 PASSED: Password changed successfully without leaking sensitive fields.\n');

    // ----------------------------------------------------
    // TEST 10: Old password can NO LONGER be used to log in -> REJECT (401)
    // ----------------------------------------------------
    console.log('[TEST 10] Attempting login with OLD password...');
    const res10 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: initialPassword,
      }),
    });
    const data10 = await res10.json();
    console.log(`Response status: ${res10.status}, success: ${data10.success}, message: "${data10.message}"`);
    if (res10.status !== 401 || data10.success !== false) {
      throw new Error(`Test 10 Failed: Old password was accepted! Expected 401. Got: ${res10.status}`);
    }
    console.log('✅ TEST 10 PASSED: Old password rejected with 401.\n');

    // ----------------------------------------------------
    // TEST 11: Successfully changed NEW password CAN be used to log in -> SUCCESS (200)
    // ----------------------------------------------------
    console.log('[TEST 11] Attempting login with NEW password...');
    const res11 = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: testEmail,
        password: updatedPassword,
      }),
    });
    const data11 = await res11.json();
    console.log(`Response status: ${res11.status}, success: ${data11.success}, user: ${data11.data?.user?.email}`);
    if (res11.status !== 200 || !data11.success || !data11.data?.token) {
      throw new Error(`Test 11 Failed: Login with new password failed! Got: ${JSON.stringify(data11)}`);
    }
    console.log('✅ TEST 11 PASSED: Login with new password succeeded!\n');

    // ----------------------------------------------------
    // TEST 12: PUT method works identically to POST
    // ----------------------------------------------------
    console.log('[TEST 12] Changing password via PUT /auth/change-password...');
    const thirdPassword = 'ThirdPassword789!';
    const res12 = await fetch(`${BASE_URL}/auth/change-password`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${data11.data.token}`,
      },
      body: JSON.stringify({
        currentPassword: updatedPassword,
        newPassword: thirdPassword,
        confirmPassword: thirdPassword,
      }),
    });
    const data12 = await res12.json();
    if (res12.status !== 200 || !data12.success) {
      throw new Error(`Test 12 Failed: PUT /auth/change-password failed. Got: ${JSON.stringify(data12)}`);
    }
    console.log('✅ TEST 12 PASSED: PUT /auth/change-password succeeded!\n');

    console.log('====================================================');
    console.log('🎉 ALL 12 CHANGE PASSWORD TESTS PASSED PERFECTLY!');
    console.log('====================================================');
  } catch (err) {
    console.error('\n❌ TEST RUN FAILED:', err.message);
    process.exit(1);
  } finally {
    if (userId) {
      try {
        const { PrismaClient } = require('@prisma/client');
        const prisma = new PrismaClient();
        await prisma.donorProfile.deleteMany({ where: { userId } });
        await prisma.user.delete({ where: { id: userId } });
        await prisma.$disconnect();
        console.log(`🧹 Cleaned up test user ${testEmail} from database.`);
      } catch (_) {}
    }
  }
}

testChangePasswordFlow();

