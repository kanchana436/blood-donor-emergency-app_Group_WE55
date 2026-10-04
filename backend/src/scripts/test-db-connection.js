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
    await prisma.$disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Connection Failed:');
    if (error.code === 'P1001') {
      console.error('   Error P1001: Can\'t reach database server at host/port.');
    } else if (error.code === 'P1000' || error.message.includes('Authentication failed')) {
      console.error('   Error P1000: Authentication failed. Please verify username and database password in .env.');
    } else {
      console.error('   Details:', error.message.split('\n')[0]);
    }
    await prisma.$disconnect();
    process.exit(1);
  }
}

testConnection();
