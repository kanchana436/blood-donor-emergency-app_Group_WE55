-- Additive setup: creates only EmergencyContact and its constraints/indexes.
-- Apply once after review. UUIDs and updatedAt are supplied by Prisma.
BEGIN;

CREATE TABLE "public"."EmergencyContact" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "fullName" TEXT NOT NULL,
  "relationship" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "alternatePhone" TEXT,
  "address" TEXT,
  "isPrimary" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "EmergencyContact_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "EmergencyContact_userId_fkey" FOREIGN KEY ("userId")
    REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "EmergencyContact_phone_check" CHECK ("phone" ~ '^[0-9]{9,15}$'),
  CONSTRAINT "EmergencyContact_alternatePhone_check"
    CHECK ("alternatePhone" IS NULL OR "alternatePhone" ~ '^[0-9]{9,15}$')
);

CREATE INDEX "EmergencyContact_userId_idx"
  ON "public"."EmergencyContact"("userId");
CREATE UNIQUE INDEX "EmergencyContact_userId_phone_key"
  ON "public"."EmergencyContact"("userId", "phone");
-- Prisma does not represent this partial index; retain it in SQL.
CREATE UNIQUE INDEX "EmergencyContact_one_primary_per_user_key"
  ON "public"."EmergencyContact"("userId") WHERE "isPrimary" = true;

COMMIT;
