-- Additive schema migration for DonorAvailability.
-- Does not alter or remove any existing tables or data.
BEGIN;

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

CREATE INDEX IF NOT EXISTS "DonorAvailability_donorId_isActive_idx"
  ON "public"."DonorAvailability"("donorId", "isActive");

CREATE INDEX IF NOT EXISTS "DonorAvailability_status_dates_idx"
  ON "public"."DonorAvailability"("status", "availableFrom", "availableUntil");

COMMIT;
