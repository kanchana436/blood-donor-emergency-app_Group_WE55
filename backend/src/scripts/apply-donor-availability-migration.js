require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  console.log('Applying DonorAvailability schema to Supabase database...');

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "public"."DonorAvailability" (
      "id" TEXT NOT NULL,
      "donorId" TEXT NOT NULL,
      "status" TEXT NOT NULL DEFAULT 'Available',
      "availableFrom" TIMESTAMP(3) NOT NULL,
      "availableUntil" TIMESTAMP(3),
      "city" TEXT,
      "notes" TEXT,
      "isActive" BOOLEAN NOT NULL DEFAULT true,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "DonorAvailability_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "DonorAvailability_donorId_fkey" FOREIGN KEY ("donorId")
        REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT "DonorAvailability_status_check" CHECK ("status" IN ('Available', 'Unavailable')),
      CONSTRAINT "DonorAvailability_date_check" CHECK ("availableUntil" IS NULL OR "availableUntil" >= "availableFrom")
    );
  `);
  console.log('✅ Table created or already exists');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "DonorAvailability_donorId_isActive_idx"
      ON "public"."DonorAvailability"("donorId", "isActive");
  `);
  console.log('✅ Index on donorId, isActive created');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "DonorAvailability_status_dates_idx"
      ON "public"."DonorAvailability"("status", "availableFrom", "availableUntil");
  `);
  console.log('✅ Index on status, availableFrom, availableUntil created');

  console.log('🎉 Migration applied successfully!');
  await prisma.$disconnect();
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
