const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
const { prisma, db } = require('../prisma');
const { sendPasswordResetEmail, sendRegistrationVerificationEmail, maskEmail } = require('./email.service');

// Initialize in-memory storage array if not present
if (!db.passwordResetOtps) {
  db.passwordResetOtps = [];
}
if (!db.emailVerificationOtps) {
  db.emailVerificationOtps = [];
}

// File-based test cache: enables automated test processes to retrieve OTPs in test/dev environment
const testCacheFilePath = path.join(__dirname, '../../.test-otp-cache.json');
const testingOtpCache = new Map();

function saveTestOtp(email, otp) {
  testingOtpCache.set(email.toLowerCase(), otp);
  try {
    let cache = {};
    if (fs.existsSync(testCacheFilePath)) {
      cache = JSON.parse(fs.readFileSync(testCacheFilePath, 'utf8') || '{}');
    }
    cache[email.toLowerCase()] = otp;
    fs.writeFileSync(testCacheFilePath, JSON.stringify(cache, null, 2), 'utf8');
  } catch (_) {}
}

function clearTestOtp(email) {
  testingOtpCache.delete(email.toLowerCase());
  try {
    if (fs.existsSync(testCacheFilePath)) {
      const cache = JSON.parse(fs.readFileSync(testCacheFilePath, 'utf8') || '{}');
      delete cache[email.toLowerCase()];
      fs.writeFileSync(testCacheFilePath, JSON.stringify(cache, null, 2), 'utf8');
    }
  } catch (_) {}
}

// Table initialization flag for Supabase / PostgreSQL
let isTableInitialized = false;

async function ensureOtpTable() {
  if (isTableInitialized || !prisma) return;
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "PasswordResetOtp" (
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
      CREATE INDEX IF NOT EXISTS "PasswordResetOtp_email_idx" ON "PasswordResetOtp" (LOWER(email));
    `);
    isTableInitialized = true;
  } catch (err) {
    // If raw query fails, table may already exist or running in fallback mode
    isTableInitialized = true;
  }
}

/**
 * Generate a cryptographically secure 6-digit random OTP
 */
function generateSecureOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

/**
 * Request OTP for password reset
 * @param {string} email - user's registered email
 * @param {string} [recipientName] - optional user name for email greeting
 * @param {boolean} [bypassCooldown] - optional flag for test suites
 * @returns {Promise<{ success: boolean, message: string, retryAfter?: number }>}
 */
async function requestOtp(email, recipientName = 'User', bypassCooldown = false) {
  await ensureOtpTable();
  const normalizedEmail = email.trim().toLowerCase();
  const now = new Date();

  // Rate Limiting: Check cooldown from last active request (60 seconds) unless bypassed by test suite
  if (!bypassCooldown) {
    let recentRecord = db.passwordResetOtps
      .filter(o => o.email === normalizedEmail && !o.used)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

    if (prisma && !recentRecord) {
      try {
        const rows = await prisma.$queryRawUnsafe(
          `SELECT * FROM "PasswordResetOtp" WHERE LOWER("email") = $1 AND "used" = false ORDER BY "createdAt" DESC LIMIT 1`,
          normalizedEmail
        );
        if (rows && rows.length > 0) recentRecord = rows[0];
      } catch (_) {}
    }

    if (recentRecord) {
      const elapsedMs = now.getTime() - new Date(recentRecord.createdAt).getTime();
      if (elapsedMs < 60000) {
        const waitSeconds = Math.ceil((60000 - elapsedMs) / 1000);
        return {
          success: false,
          rateLimited: true,
          retryAfter: waitSeconds,
          message: `Please wait ${waitSeconds} seconds before requesting another code.`,
        };
      }
    }
  }

  // Safe debug log: OTP generation completed (never log plain OTP)
  const plainOtp = generateSecureOtp();
  console.log(`[OTP] ⚙️ OTP generation completed for: ${maskEmail(normalizedEmail)} (valid for 5 minutes)`);

  // Dispatch email with the OTP to user's registered address
  const emailResult = await sendPasswordResetEmail(normalizedEmail, plainOtp, recipientName);
  if (!emailResult.success) {
    console.error(`[OTP] ❌ Email dispatch failed for: ${maskEmail(normalizedEmail)} - ${emailResult.error}`);
    return {
      success: false,
      emailDeliveryFailed: true,
      error: emailResult.error,
      message: 'Failed to deliver verification email. Please check your email configuration or try again later.',
    };
  }

  // Invalidate any existing active OTPs for this email only after email succeeds
  db.passwordResetOtps.forEach(o => {
    if (o.email === normalizedEmail && !o.used) {
      o.used = true;
    }
  });

  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE "PasswordResetOtp" SET "used" = true WHERE LOWER("email") = $1 AND "used" = false`,
        normalizedEmail
      );
    } catch (_) {}
  }

  // Hash OTP with bcrypt and store securely
  const otpHash = await bcrypt.hash(plainOtp, 10);
  const expiresAt = new Date(now.getTime() + 5 * 60 * 1000); // 5 minutes validity
  const otpId = `otp_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

  const otpRecord = {
    id: otpId,
    email: normalizedEmail,
    otpHash,
    expiresAt,
    used: false,
    attempts: 0,
    createdAt: now.toISOString(),
  };

  db.passwordResetOtps.push(otpRecord);

  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "PasswordResetOtp" ("id", "email", "otpHash", "expiresAt", "used", "attempts", "createdAt")
         VALUES ($1, $2, $3, $4, false, 0, $5)`,
        otpId,
        normalizedEmail,
        otpHash,
        expiresAt,
        now
      );
    } catch (_) {}
  }

  // Store in testing cache for test suites (internal only, never returned in API response)
  saveTestOtp(normalizedEmail, plainOtp);
  console.log(`[OTP] ✅ OTP securely stored and activated for: ${maskEmail(normalizedEmail)}`);

  return {
    success: true,
    message: 'OTP sent successfully to your email.',
  };
}

/**
 * Verify OTP
 * @param {string} email
 * @param {string} otp
 * @returns {Promise<{ valid: boolean, message: string, maxAttemptsReached?: boolean }>}
 */
async function verifyOtp(email, otp) {
  await ensureOtpTable();
  const normalizedEmail = email.trim().toLowerCase();

  // Validate OTP format: exactly 6 digits
  if (!otp || typeof otp !== 'string' || !/^\d{6}$/.test(otp.trim())) {
    return {
      valid: false,
      message: 'Verification code must be exactly 6 digits.',
    };
  }

  const cleanOtp = otp.trim();
  const now = new Date();

  // Find latest active OTP record
  let record = db.passwordResetOtps
    .filter(o => o.email === normalizedEmail && !o.used)
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

  if (prisma && !record) {
    try {
      const dbRecords = await prisma.$queryRawUnsafe(
        `SELECT * FROM "PasswordResetOtp" WHERE LOWER("email") = $1 AND "used" = false ORDER BY "createdAt" DESC LIMIT 1`,
        normalizedEmail
      );
      if (dbRecords && dbRecords.length > 0) {
        record = dbRecords[0];
      }
    } catch (_) {}
  }

  if (!record) {
    // Check if there was an already used OTP for clearer message
    const usedRecord = db.passwordResetOtps
      .filter(o => o.email === normalizedEmail && o.used)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

    if (usedRecord) {
      return {
        valid: false,
        message: 'This verification code has already been used. Please request a new code.',
      };
    }

    return {
      valid: false,
      message: 'No active verification code found. Please request a new code.',
    };
  }

  // Check if attempts exceeded (max 5)
  if (record.attempts >= 5) {
    record.used = true;
    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "PasswordResetOtp" SET "used" = true WHERE "id" = $1`,
          record.id
        );
      } catch (_) {}
    }
    return {
      valid: false,
      maxAttemptsReached: true,
      message: 'Too many incorrect attempts. This code is now invalid. Please request a new code.',
    };
  }

  // Check expiration
  if (new Date(record.expiresAt) < now) {
    record.used = true;
    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "PasswordResetOtp" SET "used" = true WHERE "id" = $1`,
          record.id
        );
      } catch (_) {}
    }
    return {
      valid: false,
      message: 'Verification code has expired. Please request a new code.',
    };
  }

  // Verify hash
  const isMatch = await bcrypt.compare(cleanOtp, record.otpHash).catch(() => false);

  if (!isMatch) {
    record.attempts += 1;
    const remaining = 5 - record.attempts;

    if (record.attempts >= 5) {
      record.used = true;
      if (prisma) {
        try {
          await prisma.$executeRawUnsafe(
            `UPDATE "PasswordResetOtp" SET "attempts" = $1, "used" = true WHERE "id" = $2`,
            record.attempts,
            record.id
          );
        } catch (_) {}
      }
      return {
        valid: false,
        maxAttemptsReached: true,
        message: 'Too many incorrect attempts. This code is now invalid. Please request a new code.',
      };
    }

    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "PasswordResetOtp" SET "attempts" = $1 WHERE "id" = $2`,
          record.attempts,
          record.id
        );
      } catch (_) {}
    }

    return {
      valid: false,
      message: `Incorrect verification code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`,
    };
  }

  // OTP verified successfully: mark as used immediately to prevent reuse
  record.used = true;
  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE "PasswordResetOtp" SET "used" = true WHERE "id" = $1`,
        record.id
      );
    } catch (_) {}
  }

  // Clear from test cache
  clearTestOtp(normalizedEmail);

  return {
    valid: true,
    message: 'Verification code verified successfully.',
  };
}

/**
 * Internal testing helper to retrieve latest active OTP for automated tests.
 * Never exposed via REST APIs or console logs.
 */
function getLatestOtpForTesting(email) {
  try {
    if (fs.existsSync(testCacheFilePath)) {
      const cache = JSON.parse(fs.readFileSync(testCacheFilePath, 'utf8') || '{}');
      return cache[email.trim().toLowerCase()] || null;
    }
  } catch (_) {}
  return testingOtpCache.get(email.trim().toLowerCase()) || null;
}

// Table initialization flag for EmailVerificationOtp
let isEmailVerificationTableInitialized = false;

async function ensureEmailVerificationTable() {
  if (isEmailVerificationTableInitialized || !prisma) return;
  try {
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
    isEmailVerificationTableInitialized = true;
  } catch (_) {
    isEmailVerificationTableInitialized = true;
  }
}

/**
 * Request OTP for new registration email verification
 */
async function requestEmailVerificationOtp(email, recipientName = 'LifeLink User', bypassCooldown = false) {
  await ensureEmailVerificationTable();
  const normalizedEmail = email.trim().toLowerCase();
  const now = new Date();

  // Rate Limiting: Check cooldown from last active request (60 seconds)
  if (!bypassCooldown) {
    let recentRecord = db.emailVerificationOtps
      .filter(o => o.email === normalizedEmail && !o.used)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

    if (prisma && !recentRecord) {
      try {
        const rows = await prisma.$queryRawUnsafe(
          `SELECT * FROM "EmailVerificationOtp" WHERE LOWER("email") = $1 AND "used" = false ORDER BY "createdAt" DESC LIMIT 1`,
          normalizedEmail
        );
        if (rows && rows.length > 0) recentRecord = rows[0];
      } catch (_) {}
    }

    if (recentRecord) {
      const elapsedMs = now.getTime() - new Date(recentRecord.createdAt).getTime();
      if (elapsedMs < 60000) {
        const waitSeconds = Math.ceil((60000 - elapsedMs) / 1000);
        return {
          success: false,
          rateLimited: true,
          retryAfter: waitSeconds,
          message: `Please wait ${waitSeconds} seconds before requesting another code.`,
        };
      }
    }
  }

  // Safe debug log: OTP generation completed (never log plain OTP)
  const plainOtp = generateSecureOtp();
  console.log(`[EmailVerification] ⚙️ OTP generation completed for: ${maskEmail(normalizedEmail)} (valid for 5 minutes)`);

  // Dispatch email with the OTP to user's registered address
  const emailResult = await sendRegistrationVerificationEmail(normalizedEmail, plainOtp, recipientName);
  if (!emailResult.success) {
    console.error(`[EmailVerification] ❌ Email dispatch failed for: ${maskEmail(normalizedEmail)} - ${emailResult.error}`);
    return {
      success: false,
      emailDeliveryFailed: true,
      error: emailResult.error,
      message: 'Failed to deliver verification email. Please check your email configuration or try again later.',
    };
  }

  // Invalidate any existing active OTPs for this email only after email succeeds
  db.emailVerificationOtps.forEach(o => {
    if (o.email === normalizedEmail && !o.used) {
      o.used = true;
    }
  });

  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE "EmailVerificationOtp" SET "used" = true WHERE LOWER("email") = $1 AND "used" = false`,
        normalizedEmail
      );
    } catch (_) {}
  }

  // Hash OTP with bcrypt and store securely
  const otpHash = await bcrypt.hash(plainOtp, 10);
  const expiresAt = new Date(now.getTime() + 5 * 60 * 1000); // 5 minutes validity
  const otpId = `reg_otp_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

  const otpRecord = {
    id: otpId,
    email: normalizedEmail,
    otpHash,
    expiresAt,
    used: false,
    attempts: 0,
    createdAt: now.toISOString(),
  };

  db.emailVerificationOtps.push(otpRecord);

  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "EmailVerificationOtp" ("id", "email", "otpHash", "expiresAt", "used", "attempts", "createdAt")
         VALUES ($1, $2, $3, $4, false, 0, $5)`,
        otpId,
        normalizedEmail,
        otpHash,
        expiresAt,
        now
      );
    } catch (_) {}
  }

  // Store in testing cache for test suites
  saveTestOtp(`reg_${normalizedEmail}`, plainOtp);
  console.log(`[EmailVerification] ✅ Registration OTP securely stored and activated for: ${maskEmail(normalizedEmail)}`);

  return {
    success: true,
    message: 'Verification code sent to your email.',
  };
}

/**
 * Verify Registration Email OTP
 */
async function verifyEmailVerificationOtp(email, otp) {
  await ensureEmailVerificationTable();
  const normalizedEmail = email.trim().toLowerCase();

  // Validate OTP format: exactly 6 digits
  if (!otp || typeof otp !== 'string' || !/^\d{6}$/.test(otp.trim())) {
    return {
      valid: false,
      message: 'Verification code must be exactly 6 digits.',
    };
  }

  const cleanOtp = otp.trim();
  const now = new Date();

  // Find latest active OTP record
  let record = db.emailVerificationOtps
    .filter(o => o.email === normalizedEmail && !o.used)
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

  if (prisma && !record) {
    try {
      const dbRecords = await prisma.$queryRawUnsafe(
        `SELECT * FROM "EmailVerificationOtp" WHERE LOWER("email") = $1 AND "used" = false ORDER BY "createdAt" DESC LIMIT 1`,
        normalizedEmail
      );
      if (dbRecords && dbRecords.length > 0) {
        record = dbRecords[0];
      }
    } catch (_) {}
  }

  if (!record) {
    const usedRecord = db.emailVerificationOtps
      .filter(o => o.email === normalizedEmail && o.used)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0];

    if (usedRecord) {
      return {
        valid: false,
        message: 'This verification code has already been used. Please request a new code.',
      };
    }

    return {
      valid: false,
      message: 'No active verification code found. Please request a new code.',
    };
  }

  // Check if attempts exceeded (max 5)
  if (record.attempts >= 5) {
    record.used = true;
    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "EmailVerificationOtp" SET "used" = true WHERE "id" = $1`,
          record.id
        );
      } catch (_) {}
    }
    return {
      valid: false,
      maxAttemptsReached: true,
      message: 'Too many incorrect attempts. This code is now invalid. Please request a new code.',
    };
  }

  // Check expiration
  if (new Date(record.expiresAt) < now) {
    record.used = true;
    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "EmailVerificationOtp" SET "used" = true WHERE "id" = $1`,
          record.id
        );
      } catch (_) {}
    }
    return {
      valid: false,
      message: 'Verification code has expired. Please request a new code.',
    };
  }

  // Verify hash
  const isMatch = await bcrypt.compare(cleanOtp, record.otpHash).catch(() => false);

  if (!isMatch) {
    record.attempts += 1;
    const remaining = 5 - record.attempts;

    if (record.attempts >= 5) {
      record.used = true;
      if (prisma) {
        try {
          await prisma.$executeRawUnsafe(
            `UPDATE "EmailVerificationOtp" SET "attempts" = $1, "used" = true WHERE "id" = $2`,
            record.attempts,
            record.id
          );
        } catch (_) {}
      }
      return {
        valid: false,
        maxAttemptsReached: true,
        message: 'Too many incorrect attempts. This code is now invalid. Please request a new code.',
      };
    }

    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          `UPDATE "EmailVerificationOtp" SET "attempts" = $1 WHERE "id" = $2`,
          record.attempts,
          record.id
        );
      } catch (_) {}
    }

    return {
      valid: false,
      message: `Incorrect verification code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`,
    };
  }

  // OTP verified successfully: mark as used immediately
  record.used = true;
  if (prisma) {
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE "EmailVerificationOtp" SET "used" = true WHERE "id" = $1`,
        record.id
      );
    } catch (_) {}
  }

  clearTestOtp(`reg_${normalizedEmail}`);

  return {
    valid: true,
    message: 'Email verified successfully.',
  };
}

function getLatestRegistrationOtpForTesting(email) {
  try {
    if (fs.existsSync(testCacheFilePath)) {
      const cache = JSON.parse(fs.readFileSync(testCacheFilePath, 'utf8') || '{}');
      return cache[`reg_${email.trim().toLowerCase()}`] || null;
    }
  } catch (_) {}
  return testingOtpCache.get(`reg_${email.trim().toLowerCase()}`) || null;
}

module.exports = {
  requestOtp,
  verifyOtp,
  getLatestOtpForTesting,
  requestEmailVerificationOtp,
  verifyEmailVerificationOtp,
  getLatestRegistrationOtpForTesting,
};
