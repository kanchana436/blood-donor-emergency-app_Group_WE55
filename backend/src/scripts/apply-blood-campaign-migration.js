require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  console.log('Applying BloodCampaign schema to Supabase database...');

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "public"."BloodCampaign" (
      "id" TEXT NOT NULL,
      "campaignName" TEXT NOT NULL,
      "description" TEXT,
      "organizerId" TEXT NOT NULL,
      "organizerName" TEXT NOT NULL,
      "contactNumber" TEXT NOT NULL,
      "email" TEXT,
      "hospitalOrBloodBank" TEXT,
      "location" TEXT NOT NULL,
      "city" TEXT NOT NULL,
      "campaignDate" TIMESTAMP(3) NOT NULL,
      "startTime" TEXT NOT NULL,
      "endTime" TEXT NOT NULL,
      "targetDonors" INTEGER,
      "status" TEXT NOT NULL DEFAULT 'Upcoming',
      "isActive" BOOLEAN NOT NULL DEFAULT true,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "BloodCampaign_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "BloodCampaign_organizerId_fkey" FOREIGN KEY ("organizerId")
        REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT "BloodCampaign_status_check" CHECK ("status" IN ('Upcoming', 'Ongoing', 'Completed', 'Cancelled')),
      CONSTRAINT "BloodCampaign_targetDonors_check" CHECK ("targetDonors" IS NULL OR "targetDonors" > 0)
    );
  `);
  console.log('✅ Table BloodCampaign created or already exists');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "BloodCampaign_city_idx"
      ON "public"."BloodCampaign"("city");
  `);
  console.log('✅ Index on city created');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "BloodCampaign_campaignDate_idx"
      ON "public"."BloodCampaign"("campaignDate");
  `);
  console.log('✅ Index on campaignDate created');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "BloodCampaign_status_idx"
      ON "public"."BloodCampaign"("status");
  `);
  console.log('✅ Index on status created');

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "BloodCampaign_organizerId_isActive_idx"
      ON "public"."BloodCampaign"("organizerId", "isActive");
  `);
  console.log('✅ Index on organizerId, isActive created');

  console.log('🎉 BloodCampaign migration applied successfully!');
  await prisma.$disconnect();
}

main().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
