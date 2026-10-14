-- Additive only. Apply manually to the database used by this application.
BEGIN;
ALTER TABLE public."User"
  ADD COLUMN IF NOT EXISTS "managerRulesAcceptedAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "managerRulesVersion" TEXT;

CREATE TABLE IF NOT EXISTS public."ChatConversation" (
  "id" TEXT NOT NULL,
  "managerId" TEXT NOT NULL,
  "donorId" TEXT NOT NULL,
  "branchId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ChatConversation_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ChatConversation_managerId_fkey" FOREIGN KEY ("managerId") REFERENCES public."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ChatConversation_donorId_fkey" FOREIGN KEY ("donorId") REFERENCES public."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ChatConversation_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES public."BloodBankBranch"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE TABLE IF NOT EXISTS public."ChatMessage" (
  "id" TEXT NOT NULL,
  "conversationId" TEXT NOT NULL,
  "senderId" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "isRead" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ChatMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES public."ChatConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ChatMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES public."User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "ChatMessage_text_check" CHECK (char_length(btrim("message")) BETWEEN 1 AND 2000)
);
CREATE UNIQUE INDEX IF NOT EXISTS "ChatConversation_managerId_donorId_branchId_key" ON public."ChatConversation"("managerId", "donorId", "branchId");
CREATE INDEX IF NOT EXISTS "ChatConversation_managerId_idx" ON public."ChatConversation"("managerId");
CREATE INDEX IF NOT EXISTS "ChatConversation_donorId_idx" ON public."ChatConversation"("donorId");
CREATE INDEX IF NOT EXISTS "ChatConversation_branchId_idx" ON public."ChatConversation"("branchId");
CREATE INDEX IF NOT EXISTS "ChatMessage_conversationId_createdAt_idx" ON public."ChatMessage"("conversationId", "createdAt");
-- No Data API policies: private chat is available only through the authorized backend.
ALTER TABLE public."ChatConversation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ChatMessage" ENABLE ROW LEVEL SECURITY;
COMMIT;
-- UUIDs and updatedAt are supplied by Prisma, consistent with the existing schema.
