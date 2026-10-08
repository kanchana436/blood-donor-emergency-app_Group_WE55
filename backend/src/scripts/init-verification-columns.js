const { prisma } = require('../prisma');

async function init() {
  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        'ALTER TABLE public."User" ADD COLUMN IF NOT EXISTS "is_email_verified" BOOLEAN DEFAULT false;'
      );
      // Mark pre-existing active users as verified so existing logins do not break
      await prisma.$executeRawUnsafe(
        'UPDATE public."User" SET "is_email_verified" = true WHERE "is_email_verified" IS NULL;'
      );
      console.log('✅ User table is_email_verified column initialized successfully');

      // Create EmailVerificationOtp table if not exists
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS "EmailVerificationOtp" (
          "id" TEXT PRIMARY KEY,
          "email" TEXT NOT NULL,
          "userId" TEXT,
          "otpHash" TEXT NOT NULL,
          "expiresAt" TIMESTAMP(3) NOT NULL,
          "used" BOOLEAN NOT NULL DEFAULT false,
          "attempts" INTEGER NOT NULL DEFAULT 0,
          "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
      `);
      await prisma.$executeRawUnsafe(`
        CREATE INDEX IF NOT EXISTS "EmailVerificationOtp_email_idx" ON "EmailVerificationOtp" (LOWER(email));
      `);
      console.log('✅ EmailVerificationOtp table initialized successfully');
    } catch (e) {
      console.error('Migration error:', e.message);
    }
  }
}

init().then(() => process.exit(0));
