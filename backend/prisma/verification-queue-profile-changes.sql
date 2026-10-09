-- Additive only. Review and apply manually; existing records remain unchanged.
BEGIN;
ALTER TABLE "public"."VerificationQueue"
  ADD COLUMN "oldValues" JSONB,
  ADD COLUMN "newValues" JSONB,
  ADD COLUMN "changedFields" JSONB;
COMMIT;
