require('dotenv').config();
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function fixAndVerify() {
  const hash = await bcrypt.hash('password123', 10);
  
  // 1. Fix Alexander
  const alex = await prisma.user.upsert({
    where: { id: 'usr_donor_101' },
    update: {
      email: 'alexander@lifelink.org',
      name: 'Alexander Silva',
      password: hash,
      role: 'donor',
      isActive: true,
    },
    create: {
      id: 'usr_donor_101',
      email: 'alexander@lifelink.org',
      name: 'Alexander Silva',
      phone: '+94 77 123 4567',
      password: hash,
      role: 'donor',
      isActive: true,
    },
  });
  console.log('✅ Demo Donor Updated in Supabase:', alex.email, 'isActive:', alex.isActive);

  // 2. Fix Sarah
  const sarah = await prisma.user.upsert({
    where: { id: 'usr_recip_202' },
    update: {
      email: 'sarah.p@lifelink.org',
      name: 'Sarah Perera',
      password: hash,
      role: 'recipient',
      isActive: true,
    },
    create: {
      id: 'usr_recip_202',
      email: 'sarah.p@lifelink.org',
      name: 'Sarah Perera',
      phone: '+94 71 987 6543',
      password: hash,
      role: 'recipient',
      isActive: true,
    },
  });
  console.log('✅ Demo Recipient Updated in Supabase:', sarah.email, 'isActive:', sarah.isActive);

  // Ensure donor profile is available
  await prisma.donorProfile.upsert({
    where: { userId: 'usr_donor_101' },
    update: { isAvailable: true, bloodGroup: 'O+', city: 'Colombo' },
    create: {
      userId: 'usr_donor_101',
      bloodGroup: 'O+',
      isAvailable: true,
      city: 'Colombo',
      address: 'No 45, Galle Road, Colombo 03',
      totalDonations: 4,
      livesSaved: 12,
      eligibilityStatus: 'Eligible',
    },
  });
  console.log('✅ Demo Donor Profile ready and available in Supabase.');
}

fixAndVerify()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
