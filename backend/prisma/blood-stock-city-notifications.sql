-- ADDITIVE ONLY. Review and apply manually; never infer branches from location text.
BEGIN;
CREATE TABLE IF NOT EXISTS "public"."BloodBankBranch" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL CHECK (length(trim("name")) > 0),
  "city" TEXT NOT NULL CHECK (length(trim("city")) > 0),
  CONSTRAINT "BloodBankBranch_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."User" ADD COLUMN IF NOT EXISTS "branchId" TEXT;
ALTER TABLE "public"."BloodStock" ADD COLUMN IF NOT EXISTS "branchId" TEXT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'User_branchId_fkey' AND conrelid = 'public."User"'::regclass) THEN
    ALTER TABLE "public"."User" ADD CONSTRAINT "User_branchId_fkey"
      FOREIGN KEY ("branchId") REFERENCES "public"."BloodBankBranch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'BloodStock_branchId_fkey' AND conrelid = 'public."BloodStock"'::regclass) THEN
    ALTER TABLE "public"."BloodStock" ADD CONSTRAINT "BloodStock_branchId_fkey"
      FOREIGN KEY ("branchId") REFERENCES "public"."BloodBankBranch"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS "BloodStock_branchId_idx" ON "public"."BloodStock"("branchId");
COMMIT;
