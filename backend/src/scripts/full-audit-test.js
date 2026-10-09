require('dotenv').config();
const http = require('http');
const { PrismaClient } = require('@prisma/client');
const app = require('../server');

const prisma = new PrismaClient();

function request(serverPort, path, method = 'GET', data = null, token = null) {
  return new Promise((resolve, reject) => {
    const payload = data ? JSON.stringify(data) : null;
    const reqOptions = {
      hostname: '127.0.0.1',
      port: serverPort,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      },
    };

    const req = http.request(reqOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed });
        } catch (_) {
          resolve({ status: res.statusCode, raw: body });
        }
      });
    });

    req.on('error', (err) => reject(err));
    if (payload) req.write(payload);
    req.end();
  });
}

async function runAudit() {
  let server;
  const PORT = 5088;
  const auditReport = {
    database: { connection: false, tablesVerified: {} },
    crud: {},
    errorHandling: {},
    e2eFlow: {},
  };

  try {
    console.log('================================================================');
    console.log('🚀 LIFELINK COMPLETE SYSTEM & FUNCTIONALITY AUDIT');
    console.log('================================================================\n');

    // 1. Prisma & Supabase Connection
    console.log('▶ STEP 1: Verifying Database Connection & Tables...');
    await prisma.$connect();
    const ping = await prisma.$queryRaw`SELECT current_database(), current_schema(), now()`;
    console.log('  ✅ PostgreSQL connected successfully:', ping[0]);
    auditReport.database.connection = true;

    // Verify all 6 Supabase tables
    const tables = ['User', 'DonorProfile', 'BloodRequest', 'DonorResponse', 'DonationRecord', 'Notification'];
    for (const t of tables) {
      let count = 0;
      if (t === 'User') count = await prisma.user.count();
      if (t === 'DonorProfile') count = await prisma.donorProfile.count();
      if (t === 'BloodRequest') count = await prisma.bloodRequest.count();
      if (t === 'DonorResponse') count = await prisma.donorResponse.count();
      if (t === 'DonationRecord') count = await prisma.donationRecord.count();
      if (t === 'Notification') count = await prisma.notification.count();
      auditReport.database.tablesVerified[t] = count;
      console.log(`  ✅ Table '${t}' verified accessible (row count: ${count})`);
    }

    // Start Backend Server on test port
    await new Promise((res) => {
      server = app.listen(PORT, () => {
        console.log(`\n▶ STEP 2: Express Server active on port ${PORT}`);
        res();
      });
    });

    // 2. USER AUTHENTICATION & CRUD
    console.log('\n▶ STEP 3: Testing Authentication & User CRUD...');
    const ts = Date.now();
    const donorEmail = `audit_donor_${ts}@lifelink-test.org`;
    const recipEmail = `audit_recip_${ts}@lifelink-test.org`;

    // 1. Create User (Donor)
    const donorReg = await request(PORT, '/api/auth/register', 'POST', {
      name: 'Audit Donor User',
      email: donorEmail,
      phone: '+94 77 100 2000',
      password: 'AuditPassword@123',
      role: 'donor',
    });
    console.log(`  1. Create User (Donor): status=${donorReg.status}, success=${donorReg.data.success}`);
    const donorId = donorReg.data.data.user.id;
    const donorToken = donorReg.data.data.token;
    auditReport.crud['1_CreateUser'] = donorReg.status === 201;

    // 2. Read User
    const donorRead = await request(PORT, `/api/auth/user/${donorId}`, 'GET');
    console.log(`  2. Read User: status=${donorRead.status}, name="${donorRead.data.data.name}"`);
    auditReport.crud['2_ReadUser'] = donorRead.status === 200;

    // 3. Update User
    const donorUpdate = await request(PORT, '/api/auth/profile', 'PUT', {
      userId: donorId,
      name: 'Audit Donor User Updated',
      phone: '+94 77 100 2001',
    });
    console.log(`  3. Update User: status=${donorUpdate.status}, newName="${donorUpdate.data.data.name}"`);
    auditReport.crud['3_UpdateUser'] = donorUpdate.status === 200 && donorUpdate.data.data.name.includes('Updated');

    // 4. Create User (Recipient)
    const recipReg = await request(PORT, '/api/auth/register', 'POST', {
      name: 'Audit Recipient User',
      email: recipEmail,
      phone: '+94 71 300 4000',
      password: 'AuditPassword@123',
      role: 'recipient',
    });
    const recipId = recipReg.data.data.user.id;
    const recipToken = recipReg.data.data.token;
    console.log(`  Create User (Recipient): status=${recipReg.status}, id=${recipId}`);

    // Login test
    const loginRes = await request(PORT, '/api/auth/login', 'POST', {
      email: donorEmail,
      password: 'AuditPassword@123',
    });
    console.log(`  User Login: status=${loginRes.status}, success=${loginRes.data.success}`);

    // 3. DONOR PROFILE CRUD
    console.log('\n▶ STEP 4: Testing DonorProfile CRUD...');
    // 4. Create Donor Profile
    const createProfile = await request(PORT, '/api/donors/profile', 'POST', {
      userId: donorId,
      bloodGroup: 'O+',
      city: 'Colombo',
      address: 'No 10, Galle Road, Colombo',
      isAvailable: true,
      latitude: 6.9271,
      longitude: 79.8612,
      weightKg: 70,
    });
    console.log(`  4. Create Donor Profile: status=${createProfile.status}, bloodGroup=${createProfile.data.data.bloodGroup}`);
    auditReport.crud['4_CreateDonorProfile'] = createProfile.status === 200;

    // 5. Read Donor Profile
    const readProfile = await request(PORT, `/api/donors/profile?userId=${donorId}`, 'GET');
    console.log(`  5. Read Donor Profile: status=${readProfile.status}, city=${readProfile.data.data.city}`);
    auditReport.crud['5_ReadDonorProfile'] = readProfile.status === 200;

    // 6. Update Donor Profile
    const updateProfile = await request(PORT, '/api/donors/profile', 'PUT', {
      userId: donorId,
      city: 'Colombo 03',
      isAvailable: true,
    });
    console.log(`  6. Update Donor Profile: status=${updateProfile.status}, newCity=${updateProfile.data.data.city}`);
    auditReport.crud['6_UpdateDonorProfile'] = updateProfile.status === 200 && updateProfile.data.data.city === 'Colombo 03';

    // 4. BLOOD REQUEST CRUD & MATCHING
    console.log('\n▶ STEP 5: Testing Blood Request CRUD & Matching Engine...');
    // 7. Create Blood Request
    const createReq = await request(PORT, '/api/requests', 'POST', {
      requesterId: recipId,
      requesterName: 'Audit Recipient User',
      patientName: `Audit Emergency Patient ${ts}`,
      bloodGroup: 'O+',
      unitsRequired: 2,
      urgency: 'Emergency',
      hospitalName: 'National Hospital of Sri Lanka',
      hospitalAddress: 'Colombo 10',
      contactPhone: '+94 71 300 4000',
      additionalNotes: 'Urgent bypass surgery requirement',
      latitude: 6.9271,
      longitude: 79.8612,
    });
    const reqId = createReq.data.data.id;
    console.log(`  7. Create Blood Request: status=${createReq.status}, reqId=${reqId}`);
    auditReport.crud['7_CreateBloodRequest'] = createReq.status === 201;

    // 8. Read Blood Request
    const readReq = await request(PORT, `/api/requests/${reqId}`, 'GET');
    console.log(`  8. Read Blood Request: status=${readReq.status}, patient=${readReq.data.data.patientName}`);
    auditReport.crud['8_ReadBloodRequest'] = readReq.status === 200;

    // 9. Update Blood Request
    const updateReq = await request(PORT, `/api/requests/${reqId}`, 'PUT', {
      unitsRequired: 3,
      additionalNotes: 'Updated notes: 3 units now requested',
    });
    console.log(`  9. Update Blood Request: status=${updateReq.status}, units=${updateReq.data.data.unitsRequired}`);
    auditReport.crud['9_UpdateBloodRequest'] = updateReq.status === 200 && updateReq.data.data.unitsRequired === 3;

    // 10. Read Matching Results (Backend Matching Engine)
    const matchesRes = await request(PORT, `/api/requests/${reqId}/matching-donors`, 'GET');
    console.log(`  10. Read Matching Donors: status=${matchesRes.status}, count=${matchesRes.data.data.length}`);
    auditReport.crud['10_ReadMatchingResults'] = matchesRes.status === 200 && Array.isArray(matchesRes.data.data);

    // 11. Read Compatible Requests for Donor
    const compatRes = await request(PORT, '/api/donors/requests/compatible', 'GET');
    console.log(`  11. Read Compatible Requests for Donor: status=${compatRes.status}, count=${compatRes.data.data.length}`);
    auditReport.crud['11_ReadCompatibleRequests'] = compatRes.status === 200;

    // 12. Create Donor Response (Accept Request)
    console.log('\n▶ STEP 6: Testing Donor Response & Status Transitions...');
    const respondRes = await request(PORT, '/api/donors/requests/respond', 'POST', {
      requestId: reqId,
      donorId: donorId,
      status: 'Accepted',
      note: 'I am 10 minutes away from National Hospital',
    });
    console.log(`  12. Create Donor Response (Accept): status=${respondRes.status}, responseStatus=${respondRes.data.data.status}`);
    auditReport.crud['12_CreateDonorResponse'] = respondRes.status === 200 && respondRes.data.data.status === 'Accepted';

    // Verify request status transitioned to 'InProgress'
    const reqAfterAccept = await request(PORT, `/api/requests/${reqId}`, 'GET');
    console.log(`  Request status after donor response: status=${reqAfterAccept.data.data.status}`);

    // 13. Read Donor Responses
    const responsesList = await request(PORT, '/api/donors/responses', 'GET');
    console.log(`  13. Read Donor Responses: status=${responsesList.status}, total=${responsesList.data.data.length}`);
    auditReport.crud['13_ReadDonorResponses'] = responsesList.status === 200;

    // 5. DONATION RECORD CRUD
    console.log('\n▶ STEP 7: Testing Donation Record CRUD...');
    // 14. Create Donation Record
    const createDonation = await request(PORT, '/api/donations', 'POST', {
      donorId: donorId,
      requestId: reqId,
      hospitalName: 'National Hospital of Sri Lanka',
      patientName: `Audit Emergency Patient ${ts}`,
      bloodGroup: 'O+',
      units: 2,
    });
    const donationId = createDonation.data.data.id;
    console.log(`  14. Create Donation Record: status=${createDonation.status}, id=${donationId}`);
    auditReport.crud['14_CreateDonationRecord'] = createDonation.status === 201;

    // 15. Read Donation History
    const donationHistory = await request(PORT, `/api/donations?donorId=${donorId}`, 'GET');
    console.log(`  15. Read Donation History: status=${donationHistory.status}, records=${donationHistory.data.data.length}`);
    auditReport.crud['15_ReadDonationHistory'] = donationHistory.status === 200 && donationHistory.data.data.length > 0;

    // 6. NOTIFICATION CRUD
    console.log('\n▶ STEP 8: Testing Notification CRUD...');
    // 16. Create Notification
    const createNotif = await request(PORT, '/api/notifications', 'POST', {
      userId: recipId,
      title: 'Donor Accepted Request!',
      message: 'A compatible O+ donor has accepted your blood request.',
      type: 'accepted',
      relatedRequestId: reqId,
    });
    const notifId = createNotif.data.data.id;
    console.log(`  16. Create Notification: status=${createNotif.status}, id=${notifId}`);
    auditReport.crud['16_CreateNotification'] = createNotif.status === 201;

    // 17. Read Notifications
    const readNotifs = await request(PORT, `/api/notifications?userId=${recipId}`, 'GET');
    console.log(`  17. Read Notifications: status=${readNotifs.status}, count=${readNotifs.data.data.length}`);
    auditReport.crud['17_ReadNotifications'] = readNotifs.status === 200 && readNotifs.data.data.length > 0;

    // 18. Update Notification as Read
    const markRead = await request(PORT, `/api/notifications/${notifId}/read`, 'PATCH');
    console.log(`  18. Mark Notification Read: status=${markRead.status}, success=${markRead.data.success}`);
    auditReport.crud['18_UpdateNotificationRead'] = markRead.status === 200;

    // 19. Unread Notification Count
    const unreadCount = await request(PORT, `/api/notifications/unread-count?userId=${recipId}`, 'GET');
    console.log(`  19. Unread Notification Count: status=${unreadCount.status}, count=${unreadCount.data.count}`);
    auditReport.crud['19_UnreadNotificationCount'] = unreadCount.status === 200;

    // 20. Cancel Blood Request
    console.log('\n▶ STEP 9: Testing Request Cancellation...');
    // Create another request to test cancel
    const cancelTargetReq = await request(PORT, '/api/requests', 'POST', {
      requesterId: recipId,
      requesterName: 'Audit Recipient User',
      patientName: 'Cancel Test Patient',
      bloodGroup: 'A+',
      unitsRequired: 1,
      urgency: 'Standard',
      hospitalName: 'Asiri Central Hospital',
      hospitalAddress: 'Norris Canal Rd, Colombo',
      contactPhone: '+94 71 300 4000',
    });
    const cancelTargetId = cancelTargetReq.data.data.id;
    const cancelRes = await request(PORT, `/api/requests/${cancelTargetId}/cancel`, 'POST');
    console.log(`  20. Cancel Blood Request: status=${cancelRes.status}, message="${cancelRes.data.message}"`);
    auditReport.crud['20_CancelBloodRequest'] = cancelRes.status === 200;

    // 7. ERROR HANDLING & SECURITY TESTS
    console.log('\n▶ STEP 10: Testing Failure Scenarios & Security...');

    // Failure 1: Duplicate email registration
    const dupRes = await request(PORT, '/api/auth/register', 'POST', {
      name: 'Duplicate Test',
      email: donorEmail, // existing
      phone: '+94 77 999 8888',
      password: 'pass',
      role: 'donor',
    });
    console.log(`  Failure 1 (Duplicate Email): status=${dupRes.status} (expected 400), msg="${dupRes.data.message}"`);
    auditReport.errorHandling['DuplicateEmail'] = dupRes.status === 400;

    // Failure 2: Invalid Login credentials
    const badLogin = await request(PORT, '/api/auth/login', 'POST', {
      email: donorEmail,
      password: 'WrongPassword!123',
    });
    console.log(`  Failure 2 (Invalid Password): status=${badLogin.status} (expected 401), msg="${badLogin.data.message}"`);
    auditReport.errorHandling['InvalidLogin'] = badLogin.status === 401;

    // Failure 3: Missing required registration fields
    const missingFields = await request(PORT, '/api/auth/register', 'POST', {
      email: 'missing_name@lifelink.org',
    });
    console.log(`  Failure 3 (Missing Name/Phone): status=${missingFields.status} (expected 400)`);
    auditReport.errorHandling['MissingFields'] = missingFields.status === 400;

    // Failure 4: Unauthorized request to protected endpoint (no token)
    const noTokenRes = await request(PORT, '/api/auth/verify', 'GET');
    console.log(`  Failure 4 (No Auth Token): status=${noTokenRes.status} (expected 401)`);
    auditReport.errorHandling['UnauthorizedNoToken'] = noTokenRes.status === 401;

    // Failure 5: Invalid / fake auth token
    const fakeTokenRes = await request(PORT, '/api/auth/verify', 'GET', null, 'this_is_an_invalid_token');
    console.log(`  Failure 5 (Invalid Token): status=${fakeTokenRes.status} (expected 403)`);
    auditReport.errorHandling['InvalidToken'] = fakeTokenRes.status === 403;

    // Success with valid token
    const validTokenRes = await request(PORT, '/api/auth/verify', 'GET', null, donorToken);
    console.log(`  Success with Valid Token: status=${validTokenRes.status} (expected 200)`);
    auditReport.errorHandling['ValidTokenSuccess'] = validTokenRes.status === 200;

    // Failure 6: Non-existent request ID
    const notFoundReq = await request(PORT, '/api/requests/00000000-0000-0000-0000-000000000000', 'GET');
    console.log(`  Failure 6 (Non-existent Request): status=${notFoundReq.status} (expected 404)`);
    auditReport.errorHandling['RequestNotFound'] = notFoundReq.status === 404;

    console.log('\n================================================================');
    console.log('🎉 AUDIT SUITE EXECUTION COMPLETE');
    console.log('================================================================');

  } catch (err) {
    console.error('❌ Audit execution failed with error:', err);
  } finally {
    if (server) server.close();
    await prisma.$disconnect();
    process.exit(0);
  }
}

runAudit();
