const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

async function syncWithRetry(retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    const prisma = new PrismaClient();
    try {
      console.log(`[Attempt ${attempt}/${retries}] Connecting to database...`);
      await prisma.$connect();
      console.log('Connected.');

      const hashedPassword = await bcrypt.hash('password123', 10);

      // 1. Sync Alexander Silva (Donor) - usr_donor_101
      console.log('Syncing usr_donor_101 (alexander@lifelink.org)...');
      
      // Update existing usr_donor_101 directly
      const donorUser = await prisma.user.upsert({
        where: { id: 'usr_donor_101' },
        update: {
          idNumber: '851234567V',
          name: 'Alexander Silva',
          email: 'alexander@lifelink.org',
          phone: '+94 77 123 4567',
          password: hashedPassword,
          role: 'donor',
          isActive: true,
        },
        create: {
          id: 'usr_donor_101',
          idNumber: '851234567V',
          name: 'Alexander Silva',
          email: 'alexander@lifelink.org',
          phone: '+94 77 123 4567',
          password: hashedPassword,
          role: 'donor',
          isActive: true,
        },
      });

      // Ensure donor profile for usr_donor_101
      await prisma.donorProfile.upsert({
        where: { userId: 'usr_donor_101' },
        update: {
          bloodGroup: 'O+',
          isAvailable: true,
          city: 'Colombo',
          address: 'No 45, Galle Road, Colombo 03',
        },
        create: {
          id: 'dp_101',
          userId: 'usr_donor_101',
          bloodGroup: 'O+',
          isAvailable: true,
          city: 'Colombo',
          address: 'No 45, Galle Road, Colombo 03',
        },
      });
      console.log('✅ usr_donor_101 synced:', donorUser.email, 'isActive:', donorUser.isActive);

      // 2. Sync Sarah Perera (Recipient) - usr_recip_202
      console.log('Syncing usr_recip_202 (sarah.p@lifelink.org)...');
      const recipUser = await prisma.user.upsert({
        where: { id: 'usr_recip_202' },
        update: {
          idNumber: '921234567V',
          name: 'Sarah Perera',
          email: 'sarah.p@lifelink.org',
          phone: '+94 71 987 6543',
          password: hashedPassword,
          role: 'recipient',
          isActive: true,
        },
        create: {
          id: 'usr_recip_202',
          idNumber: '921234567V',
          name: 'Sarah Perera',
          email: 'sarah.p@lifelink.org',
          phone: '+94 71 987 6543',
          password: hashedPassword,
          role: 'recipient',
          isActive: true,
        },
      });
      console.log('✅ usr_recip_202 synced:', recipUser.email, 'isActive:', recipUser.isActive);

      await prisma.$disconnect();
      console.log('\n🎉 Demo users synchronized successfully in Supabase PostgreSQL!');
      return;
    } catch (err) {
      console.error(`Attempt ${attempt} error:`, err.message);
      await prisma.$disconnect().catch(() => {});
      if (attempt < retries) {
        console.log('Waiting 2 seconds before retry...');
        await new Promise(r => setTimeout(r, 2000));
      } else {
        process.exitCode = 1;
      }
    }
  }
}

syncWithRetry();
