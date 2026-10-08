-- Additive setup only. Apply manually; Prisma supplies UUIDs and updatedAt.
BEGIN;
CREATE TABLE "public"."VerificationQueue" (
  "id" TEXT NOT NULL,
  "submittedById" TEXT NOT NULL,
  "verificationType" TEXT NOT NULL,
  "referenceId" TEXT,
  "title" TEXT NOT NULL,
  "description" TEXT,
  "status" TEXT NOT NULL DEFAULT 'Pending',
  "managerNote" TEXT,
  "reviewedById" TEXT,
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "VerificationQueue_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "VerificationQueue_submittedById_fkey" FOREIGN KEY ("submittedById")
    REFERENCES "public"."User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "VerificationQueue_reviewedById_fkey" FOREIGN KEY ("reviewedById")
    REFERENCES "public"."User"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "VerificationQueue_status_check" CHECK ("status" IN ('Pending', 'Approved', 'Rejected')),
  CONSTRAINT "VerificationQueue_required_text_check" CHECK
    (length(trim("title")) > 0 AND length(trim("verificationType")) > 0),
  CONSTRAINT "VerificationQueue_review_check" CHECK
    (("status" = 'Pending' AND "reviewedById" IS NULL AND "reviewedAt" IS NULL)
     OR ("status" IN ('Approved', 'Rejected') AND "reviewedById" IS NOT NULL AND "reviewedAt" IS NOT NULL))
);
CREATE INDEX "VerificationQueue_status_createdAt_idx" ON "public"."VerificationQueue"("status", "createdAt");
CREATE INDEX "VerificationQueue_submittedById_idx" ON "public"."VerificationQueue"("submittedById");
CREATE INDEX "VerificationQueue_reviewedById_idx" ON "public"."VerificationQueue"("reviewedById");
COMMIT;
