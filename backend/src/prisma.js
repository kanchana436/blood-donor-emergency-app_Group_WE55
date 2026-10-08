const { PrismaClient } = require('@prisma/client');

let prisma;
let isPrismaConnected = false;

try {
  prisma = new PrismaClient();
  prisma.$connect()
    .then(async () => {
      isPrismaConnected = true;
      console.log('✅ Connected to PostgreSQL / Supabase Database via Prisma');
      try {
        await prisma.$executeRawUnsafe(
          'CREATE UNIQUE INDEX IF NOT EXISTS "User_email_lower_key" ON public."User" (LOWER(email));'
        );
        await prisma.$executeRawUnsafe(
          'CREATE UNIQUE INDEX IF NOT EXISTS "User_id_number_lower_key" ON public."User" (LOWER(TRIM("id_number")));'
        );
        console.log('🔒 Case-insensitive unique constraints on email and id_number verified at database level.');
      } catch (idxErr) {
        console.warn('Notice: Could not verify unique index:', idxErr.message);
      }
    })
    .catch((err) => {
      isPrismaConnected = false;
      console.log('ℹ️  PostgreSQL not reachable. Running with in-memory database fallback.');
    });
} catch (_) {
  console.log('ℹ️  Running in-memory database fallback mode.');
}

// In-Memory Database store for standalone execution
const db = {
  users: [
    {
      id: 'usr_donor_101',
      idNumber: '851234567V',
      name: 'Alexander Silva',
      email: 'alexander@lifelink.org',
      password: '$2b$10$ptyCpgrP1zFvd5ZkvOBlfuSitg6nal24yUMVxSTuLxC.iYuwnvioC', // password123
      phone: '+94 77 123 4567',
      role: 'donor',
      isActive: true,
      isEmailVerified: true,
      createdAt: new Date().toISOString(),
    },
    {
      id: 'usr_recip_202',
      idNumber: '921234567V',
      name: 'Sarah Perera',
      email: 'sarah.p@lifelink.org',
      password: '$2b$10$ptyCpgrP1zFvd5ZkvOBlfuSitg6nal24yUMVxSTuLxC.iYuwnvioC', // password123
      phone: '+94 71 987 6543',
      role: 'recipient',
      isActive: true,
      isEmailVerified: true,
      createdAt: new Date().toISOString(),
    },
  ],
  emailVerificationOtps: [],
  passwordResetOtps: [],
  donorProfiles: [
    {
      id: 'dp_101',
      userId: 'usr_donor_101',
      bloodGroup: 'O+',
      isAvailable: true,
      city: 'Colombo',
      address: 'No 45, Galle Road, Colombo 03',
      latitude: 6.9271,
      longitude: 79.8612,
      lastDonationDate: new Date(Date.now() - 95 * 86400000).toISOString(),
      totalDonations: 4,
      livesSaved: 12,
      eligibilityStatus: 'Eligible',
      weightKg: 72.5,
    },
    {
      id: 'dp_102',
      userId: 'usr_donor_102',
      bloodGroup: 'O+',
      isAvailable: true,
      city: 'Colombo',
      address: 'Colombo 10',
      latitude: 6.9240,
      longitude: 79.8655,
      totalDonations: 2,
      livesSaved: 6,
      eligibilityStatus: 'Eligible',
    },
  ],
  bloodRequests: [
    {
      id: 'req_001',
      requesterId: 'usr_recip_202',
      requesterName: 'Sarah Perera',
      patientName: 'Kavindu Perera (Emergency Surgery)',
      bloodGroup: 'O+',
      unitsRequired: 2,
      urgency: 'Emergency',
      hospitalName: 'National Hospital of Sri Lanka',
      hospitalAddress: 'Regent Street, Colombo 10',
      latitude: 6.9202,
      longitude: 79.8687,
      contactPhone: '+94 71 987 6543',
      additionalNotes: 'Immediate bypass surgery scheduled. 2 units O+ required urgently.',
      status: 'Open',
      createdAt: new Date(Date.now() - 50 * 60000).toISOString(),
      matchedDonorsCount: 3,
      acceptedDonorsCount: 1,
      matchedDonors: [
        {
          id: 'dr_01',
          requestId: 'req_001',
          donorId: 'usr_donor_101',
          donorName: 'Alexander Silva',
          donorPhone: '+94 77 123 4567',
          donorBloodGroup: 'O+',
          status: 'Pending',
          distanceKm: 1.8,
          respondedAt: new Date().toISOString(),
        },
        {
          id: 'dr_02',
          requestId: 'req_001',
          donorId: 'usr_donor_102',
          donorName: 'Kasun Fernando',
          donorPhone: '+94 76 555 4321',
          donorBloodGroup: 'O+',
          status: 'Accepted',
          distanceKm: 3.2,
          respondedAt: new Date().toISOString(),
          note: 'On the way to hospital, ETA 20 mins',
        },
      ],
    },
  ],
  donationRecords: [
    {
      id: 'don_001',
      donorId: 'usr_donor_101',
      requestId: 'req_001',
      hospitalName: 'National Hospital of Sri Lanka',
      patientName: 'Chaminda Rathnayake',
      bloodGroup: 'O+',
      units: 1,
      donationDate: new Date(Date.now() - 95 * 86400000).toISOString(),
      status: 'Completed',
    },
  ],
  notifications: [
    {
      id: 'notif_001',
      userId: 'usr_donor_101',
      title: 'Emergency Blood Request Nearby!',
      message: 'A patient at National Hospital urgently needs 2 units of O+ blood (1.8 km away).',
      type: 'emergency',
      timestamp: new Date(Date.now() - 40 * 60000).toISOString(),
      isRead: false,
      relatedRequestId: 'req_001',
    },
  ],
};

module.exports = {
  prisma,
  isPrismaConnected: () => isPrismaConnected,
  db,
};
