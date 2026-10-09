const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function ensureConstraints() {
  console.log('--- Ensuring Database Constraints ---');
  try {
    // 1. Ensure case-insensitive unique index on LOWER(email)
    await prisma.$executeRawUnsafe(`
      CREATE UNIQUE INDEX IF NOT EXISTS "User_email_lower_key" ON public."User" (LOWER(email));
    `);
    console.log('✅ Case-insensitive unique index on LOWER(email) verified/created.');

    // 2. Verify all indexes on User table
    const indexes = await prisma.$queryRawUnsafe(`
      SELECT indexname, indexdef 
      FROM pg_indexes 
      WHERE tablename = 'User';
    `);
    console.log('Current indexes on User table:', indexes);
  } catch (err) {
    console.error('Error ensuring constraints:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  ensureConstraints();
}

module.exports = { ensureConstraints };
