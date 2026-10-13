-- Additive schema setup only. Does not alter any existing table or record.
-- UUIDs and updatedAt values are supplied by Prisma.
BEGIN;

CREATE TABLE "public"."BloodStock" (
  "id" TEXT NOT NULL,
  "bloodGroup" TEXT NOT NULL,
  "availableUnits" INTEGER NOT NULL DEFAULT 0,
  "location" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'Available',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "BloodStock_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "BloodStock_bloodGroup_location_key"
ON "public"."BloodStock"("bloodGroup", "location");

COMMIT;
