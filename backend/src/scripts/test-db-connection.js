require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

async function testConnection() {
  const rawUrl = process.env.DATABASE_URL || '';
  
  // Mask credentials for display
  const maskedUrl = rawUrl.replace(/:([^:@]+)@/, ':****@');
  console.log(`Testing connection to: ${maskedUrl}`);

  if (rawUrl.includes(':PASSWORD@') || rawUrl.includes('[YOUR-PASSWORD]')) {
    console.log('\n⚠️  Notice: The placeholder "PASSWORD" is still set in backend/.env.');
    console.log('   Please replace "PASSWORD" in backend/.env with your actual Supabase database password.\n');
    process.exit(2);
  }

  const prisma = new PrismaClient();

  try {
    console.log('Connecting to Supabase PostgreSQL...');
    await prisma.$connect();
    
    // Execute simple test query
    const result = await prisma.$queryRaw`SELECT 1 as connected`;
    console.log('✅ Successfully connected to Supabase PostgreSQL database!');
    console.log('   Result:', result);
    const user = await prisma.user.findFirst();
    console.log('   First user in DB:', user ? { id: user.id, email: user.email, isActive: user.isActive } : null);
    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Connection Failed:');
    if (error.code === 'P1001') {
      console.error('   Error P1001: Can\'t reach database server at aws-0-ap-southeast-1.pooler.supabase.com:5432');
      console.error('\n💡 Troubleshooting Steps:');
      console.error('   1. Check if your Supabase project is PAUSED:');
      console.error('      Log into https://supabase.com/dashboard and click "Restore project" if paused.');
      console.error('   2. Note: LifeLink has an automatic in-memory database fallback.');
      console.error('      The server and all features (campaigns, stock, queue, auth) will run normally even without Supabase.');
    } else if (error.code === 'P1000' || error.message.includes('Authentication failed')) {
      console.error('   Error P1000: Authentication failed. Please verify password in backend/.env.');
    } else {
      console.error('   Details:', error.message.split('\n')[0]);
    }
    await prisma.$disconnect();
    process.exit(1);
  }
}

testConnection();
