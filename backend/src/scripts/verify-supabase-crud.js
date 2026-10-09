require('dotenv').config();
const http = require('http');
const { PrismaClient } = require('@prisma/client');
const app = require('../server');

const prisma = new PrismaClient();

// Helper to make HTTP requests to the backend server
function makeRequest(serverPort, path, method = 'GET', data = null, headers = {}) {
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
        ...headers,
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

async function runVerification() {
  const summary = {
    supabaseConnection: 'FAILED',
    userCreate: 'FAILED',
    userRead: 'FAILED',
    bloodRequestCreate: 'FAILED',
    bloodRequestRead: 'FAILED',
    exactIssue: 'None',
  };

  let server;

  try {
    console.log('====================================================');
    console.log('   LifeLink Supabase Integration Verification');
    console.log('====================================================\n');

    // 1. Check Prisma Database Connection
    console.log('▶ [1/5] Checking Prisma Supabase Connection...');
    await prisma.$connect();
    const pingResult = await prisma.$queryRaw`SELECT 1 as connected`;
    if (pingResult && pingResult.length > 0) {
      summary.supabaseConnection = 'SUCCESS';
      console.log('  ✅ Supabase connection confirmed active and responsive.\n');
    } else {
      throw new Error('Supabase ping query did not return expected result');
    }

    // 2. Start the Backend API Server on a test port
    const TEST_PORT = 5055;
    await new Promise((resolve) => {
      server = app.listen(TEST_PORT, () => {
        console.log(`▶ [2/5] Backend API Server listening on port ${TEST_PORT} for testing...\n`);
        resolve();
      });
    });

    // 3. Create a Safe Test User through the Backend API Endpoint
    console.log('▶ [3/5] Testing User API Endpoint (POST /api/auth/register)...');
    const timestamp = Date.now();
    const testUserData = {
      name: `Test Donor ${timestamp}`,
      email: `test_donor_${timestamp}@lifelink-test.org`,
      phone: '+94 77 111 2233',
      password: 'SafeTestPassword#2026',
      role: 'donor',
    };

    const registerRes = await makeRequest(TEST_PORT, '/api/auth/register', 'POST', testUserData);
    console.log(`  API Response status: ${registerRes.status}`);

    if (registerRes.status === 201 && registerRes.data && registerRes.data.success) {
      const createdUserApi = registerRes.data.data.user;
      console.log(`  ✅ User created through backend API: ID=${createdUserApi.id}, Email=${createdUserApi.email}`);

      // Verify the user is actually stored in Supabase database
      const userInDb = await prisma.user.findUnique({
        where: { id: createdUserApi.id },
      });

      if (userInDb && userInDb.email === testUserData.email) {
        summary.userCreate = 'SUCCESS';
        console.log('  ✅ Confirmed: User record successfully inserted in Supabase `User` table.');
      } else {
        throw new Error('User was not found in Supabase User table after API registration');
      }

      // Verify reading back from the database via API
      console.log('\n▶ [4/5] Testing User READ (GET /api/auth/user/:id & Prisma Direct)...');
      const readUserApi = await makeRequest(TEST_PORT, `/api/auth/user/${createdUserApi.id}`, 'GET');
      if (readUserApi.status === 200 && readUserApi.data && readUserApi.data.data.id === createdUserApi.id) {
        summary.userRead = 'SUCCESS';
        console.log(`  ✅ User read back from API: Name="${readUserApi.data.data.name}", Role="${readUserApi.data.data.role}"`);
        console.log(`  ✅ User read back from Supabase Prisma query: Verified match for ${userInDb.id}\n`);
      } else {
        throw new Error('User read back via API failed');
      }

      // 4. Test creating a BloodRequest record through the Backend API Endpoint
      console.log('▶ [5/5] Testing BloodRequest API Endpoint (POST /api/requests)...');
      const testBloodRequestData = {
        requesterId: createdUserApi.id,
        requesterName: createdUserApi.name,
        patientName: `Emergency Patient ${timestamp}`,
        bloodGroup: 'O+',
        unitsRequired: 2,
        urgency: 'Emergency',
        hospitalName: 'National Hospital of Sri Lanka',
        hospitalAddress: 'Regent Street, Colombo 10',
        contactPhone: createdUserApi.phone,
        additionalNotes: 'Urgent verification test request',
        latitude: 6.9271,
        longitude: 79.8612,
      };

      const requestRes = await makeRequest(TEST_PORT, '/api/requests', 'POST', testBloodRequestData);
      console.log(`  API Response status: ${requestRes.status}`);

      if (requestRes.status === 201 && requestRes.data && requestRes.data.success) {
        const createdReqApi = requestRes.data.data;
        console.log(`  ✅ BloodRequest created through backend API: ID=${createdReqApi.id}`);

        // Verify the BloodRequest is actually stored in Supabase database
        const reqInDb = await prisma.bloodRequest.findUnique({
          where: { id: createdReqApi.id },
        });

        if (reqInDb && reqInDb.patientName === testBloodRequestData.patientName) {
          summary.bloodRequestCreate = 'SUCCESS';
          console.log('  ✅ Confirmed: BloodRequest record successfully inserted in Supabase `BloodRequest` table.');
        } else {
          throw new Error('BloodRequest was not found in Supabase BloodRequest table after API dispatch');
        }

        // Verify reading back the BloodRequest via API & Prisma
        const readReqApi = await makeRequest(TEST_PORT, `/api/requests/${createdReqApi.id}`, 'GET');
        if (readReqApi.status === 200 && readReqApi.data && readReqApi.data.data.id === createdReqApi.id) {
          summary.bloodRequestRead = 'SUCCESS';
          console.log(`  ✅ BloodRequest read back from API: Patient="${readReqApi.data.data.patientName}", Status="${readReqApi.data.data.status}"`);
          console.log(`  ✅ BloodRequest read back from Supabase Prisma query: Verified match for ${reqInDb.id}\n`);
        } else {
          throw new Error('BloodRequest read back via API failed');
        }
      } else {
        throw new Error(`BloodRequest creation API failed with status ${requestRes.status}: ${JSON.stringify(requestRes.data)}`);
      }
    } else {
      throw new Error(`User registration API failed with status ${registerRes.status}: ${JSON.stringify(registerRes.data)}`);
    }

  } catch (err) {
    console.error('❌ Verification Error encountered:', err.message);
    summary.exactIssue = err.message;
  } finally {
    if (server) {
      server.close();
    }
    await prisma.$disconnect();

    console.log('====================================================');
    console.log('               FINAL VERIFICATION RESULTS            ');
    console.log('====================================================');
    console.log(`* User CREATE: ${summary.userCreate}`);
    console.log(`* User READ: ${summary.userRead}`);
    console.log(`* BloodRequest CREATE: ${summary.bloodRequestCreate}`);
    console.log(`* BloodRequest READ: ${summary.bloodRequestRead}`);
    console.log(`* Supabase database connection: ${summary.supabaseConnection}`);
    console.log(`* Exact issue if anything failed: ${summary.exactIssue}`);
    console.log('====================================================');

    process.exit(summary.exactIssue === 'None' ? 0 : 1);
  }
}

runVerification();
