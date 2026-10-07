const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function migrate() {
  console.log('🔄 Checking and applying database migration for id_number...');
  try {
    // 1. Check if column exists
    const cols = await prisma.$queryRawUnsafe(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'User' AND column_name = 'id_number';"
    );

    if (cols.length === 0) {
      console.log('➕ Column id_number does not exist. Adding id_number column...');
      await prisma.$executeRawUnsafe(
        'ALTER TABLE "User" ADD COLUMN "id_number" TEXT;'
      );
      console.log('✅ Column id_number added.');
    } else {
      console.log('ℹ️  Column id_number already exists.');
    }

    // 2. Safely populate existing users who have NULL or empty id_number
    console.log('🔄 Backfilling existing users with unique default ID numbers if null...');
    await prisma.$executeRawUnsafe(`
      UPDATE "User"
      SET "id_number" = 'ID-' || UPPER(SUBSTRING(MD5(id || email) FROM 1 FOR 9)) || 'V'
      WHERE "id_number" IS NULL OR TRIM("id_number") = '';
    `);
    console.log('✅ Existing users safely backfilled.');

    // 3. Make column NOT NULL
    console.log('🔒 Applying NOT NULL constraint on id_number...');
    await prisma.$executeRawUnsafe(
      'ALTER TABLE "User" ALTER COLUMN "id_number" SET NOT NULL;'
    );
    console.log('✅ NOT NULL constraint applied.');

    // 4. Create case-insensitive UNIQUE INDEX
    console.log('🔒 Creating UNIQUE index on id_number...');
    await prisma.$executeRawUnsafe(
      'CREATE UNIQUE INDEX IF NOT EXISTS "User_id_number_lower_key" ON "User" (LOWER(TRIM("id_number")));'
    );
    await prisma.$executeRawUnsafe(
      'CREATE UNIQUE INDEX IF NOT EXISTS "User_id_number_key" ON "User" ("id_number");'
    );
    console.log('✅ UNIQUE index created.');

    // 5. Verify users
    const sampleUsers = await prisma.$queryRawUnsafe(
      'SELECT id, name, email, "id_number" FROM "User" LIMIT 5;'
    );
    console.log('📋 Sample users after migration:', sampleUsers);

    console.log('🎉 Migration completed successfully!');
  } catch (err) {
    console.error('❌ Migration failed:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

migrate();
