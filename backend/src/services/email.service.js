require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const nodemailer = require('nodemailer');

let transporter = null;

/**
 * Mask an email address for safe logging (e.g., j***e@example.com)
 */
function maskEmail(email) {
  if (!email || typeof email !== 'string') return '';
  const parts = email.split('@');
  if (parts.length !== 2) return email;
  const name = parts[0];
  const domain = parts[1];
  if (name.length <= 2) {
    return `${name[0]}*@${domain}`;
  }
  return `${name[0]}${'*'.repeat(Math.max(1, name.length - 2))}${name[name.length - 1]}@${domain}`;
}

/**
 * Checks whether SMTP/Email provider is configured in environment variables
 */
function isEmailServiceConfigured() {
  const user = (process.env.SMTP_USER || process.env.EMAIL_USER || '').trim();
  const pass = (process.env.SMTP_PASS || process.env.SMTP_PASSWORD || process.env.EMAIL_PASSWORD || '').trim();
  const host = (process.env.SMTP_HOST || '').trim();

  // For public SMTP providers (Gmail, Outlook, etc.), non-empty user AND password are required
  if (user && pass) return true;

  // Unauthenticated local relay (only if explicitly opted into)
  if (host && process.env.SMTP_AUTH_REQUIRED === 'false') return true;

  return false;
}

/**
 * Returns configuration metadata (without exposing secrets)
 */
function getEmailConfigSummary() {
  const configured = isEmailServiceConfigured();
  const user = (process.env.SMTP_USER || process.env.EMAIL_USER || '').trim();
  const pass = (process.env.SMTP_PASS || process.env.SMTP_PASSWORD || process.env.EMAIL_PASSWORD || '').trim();
  const host = (process.env.SMTP_HOST || (user.toLowerCase().endsWith('@gmail.com') ? 'smtp.gmail.com' : 'none')).trim();
  const port = process.env.SMTP_PORT || '587';
  const service = process.env.SMTP_SERVICE || process.env.EMAIL_SERVICE || (user.toLowerCase().endsWith('@gmail.com') ? 'gmail' : 'smtp');

  const missing = [];
  if (!user) missing.push('SMTP_USER');
  if (!pass) missing.push('SMTP_PASSWORD');

  return {
    configured,
    service,
    host,
    port,
    sender: maskEmail(user) || 'unconfigured',
    missingCredentials: missing,
  };
}

/**
 * Creates and initializes the nodemailer transporter
 */
function getTransporter() {
  if (transporter) return transporter;

  const user = (process.env.SMTP_USER || process.env.EMAIL_USER || '').trim();
  const rawPass = process.env.SMTP_PASS || process.env.SMTP_PASSWORD || process.env.EMAIL_PASSWORD || '';
  // Automatically strip spaces from Google 16-character App Passwords
  const pass = rawPass.replace(/\s+/g, '').trim();
  const host = (process.env.SMTP_HOST || '').trim();
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;
  const service = process.env.SMTP_SERVICE || process.env.EMAIL_SERVICE;

  if (host && user && pass) {
    transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass },
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 20000,
    });
  } else if ((service && user && pass) || (user && pass && user.toLowerCase().endsWith('@gmail.com'))) {
    transporter = nodemailer.createTransport({
      service: service || 'gmail',
      auth: { user, pass },
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 20000,
    });
  } else if (user && pass) {
    transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: { user, pass },
      connectionTimeout: 10000,
    });
  }

  return transporter;
}

/**
 * Verify email connection with SMTP server (safe diagnostics)
 */
async function verifyEmailConnection() {
  const summary = getEmailConfigSummary();
  if (!summary.configured) {
    console.warn('[EmailService] ⚠️ SMTP credentials not configured in backend/.env. Email delivery will be unavailable.');
    return { success: false, message: 'SMTP credentials not configured in backend/.env' };
  }

  try {
    const activeTransporter = getTransporter();
    if (!activeTransporter) {
      throw new Error('Unable to construct email transport');
    }
    console.log(`[EmailService] 🔌 Verifying SMTP connection to ${summary.host}:${summary.port}...`);
    await activeTransporter.verify();
    console.log(`[EmailService] ✅ SMTP connection verified successfully with ${summary.host}`);
    return { success: true, message: 'SMTP connection verified' };
  } catch (err) {
    console.error(`[EmailService] ❌ SMTP connection verification failed: ${err.message}`);
    return { success: false, error: err.message };
  }
}

/**
 * Sends a 6-digit OTP verification email for LifeLink password reset.
 * 
 * Requirements:
 * - Clear subject: "LifeLink Password Reset OTP"
 * - 6-digit OTP
 * - OTP expiration time: 5 minutes
 * - Clear instructions: "Do not share this OTP with anyone."
 * - Returns { success: true, messageId } on verified dispatch
 * - Returns { success: false, error } on delivery failure
 */
async function sendPasswordResetEmail(email, otp, recipientName = 'LifeLink User') {
  const normalizedEmail = (email || '').trim().toLowerCase();
  const maskedRecipient = maskEmail(normalizedEmail);
  const isTestAddress = normalizedEmail.endsWith('@lifelink-test.org') || process.env.NODE_ENV === 'test' || process.env.ALLOW_MOCK_EMAIL === 'true';

  console.log(`[EmailService] 📤 Email sending attempted for: ${maskedRecipient}`);

  // Check if email service is configured
  if (!isEmailServiceConfigured()) {
    // For automated test suites on mock domains (@lifelink-test.org), allow simulated delivery
    if (isTestAddress) {
      console.log(`[EmailService] 🧪 Test suite detected for ${maskedRecipient}. Simulating delivery via jsonTransport.`);
      const mockTransporter = nodemailer.createTransport({ jsonTransport: true });
      const info = await mockTransporter.sendMail({
        from: '"LifeLink Security" <test-noreply@lifelink.org>',
        to: normalizedEmail,
        subject: 'LifeLink Password Reset OTP',
        text: `Your LifeLink password reset OTP is: ${otp}\nThis OTP will expire in 5 minutes.\nDo not share this OTP with anyone.`,
      });
      console.log(`[EmailService] ✅ Email provider response: messageId=${info.messageId} status=simulated (test-suite)`);
      return { success: true, messageId: info.messageId, simulated: true };
    }

    // For real user addresses, fail honestly if email service is not configured
    const errorMsg = 'Email service is not configured. Missing SMTP_USER and SMTP_PASS/SMTP_PASSWORD in backend/.env.';
    console.error(`[EmailService] ❌ Email sending failure reason: ${errorMsg}`);
    return { success: false, error: errorMsg };
  }

  const activeTransporter = getTransporter();
  if (!activeTransporter) {
    const errorMsg = 'Failed to initialize email transport. Check SMTP configuration in backend/.env.';
    console.error(`[EmailService] ❌ Email sending failure reason: ${errorMsg}`);
    return { success: false, error: errorMsg };
  }

  const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER;
  const senderAddress = process.env.EMAIL_FROM || process.env.MAIL_FROM || (smtpUser ? `"LifeLink Security" <${smtpUser}>` : '"LifeLink Security" <noreply@lifelink.org>');

  const mailOptions = {
    from: senderAddress,
    to: normalizedEmail,
    subject: 'LifeLink Password Reset OTP',
    text: `Hello ${recipientName},\n\nYour LifeLink password reset OTP is: ${otp}\n\nThis OTP will expire in 5 minutes.\n\nDo not share this OTP with anyone.\n\nIf you did not request a password reset, please ignore this email or contact support.\n\nLifeLink Emergency Blood Donation Network`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px; background-color: #FFFFFF;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #E11D48; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">🩸 LifeLink</h2>
          <p style="color: #64748B; font-size: 13px; margin: 4px 0 0 0;">Emergency Blood Donation Network</p>
        </div>
        <div style="background-color: #FFF1F2; border-radius: 8px; padding: 16px; margin-bottom: 20px; border-left: 4px solid #E11D48;">
          <h3 style="margin: 0 0 8px 0; color: #9F1239; font-size: 16px;">LifeLink Password Reset OTP</h3>
          <p style="margin: 0; color: #475569; font-size: 14px; line-height: 1.5;">
            Hello <strong>${recipientName}</strong>, your LifeLink password reset OTP is:
          </p>
        </div>
        <div style="text-align: center; margin: 28px 0;">
          <div style="display: inline-block; background-color: #F8FAFC; border: 2px dashed #CBD5E1; border-radius: 12px; padding: 16px 36px;">
            <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #0F172A; font-family: monospace;">${otp}</span>
          </div>
          <p style="color: #64748B; font-size: 13px; margin-top: 12px; font-weight: 600;">⏳ This OTP will expire in <strong>5 minutes</strong>.</p>
        </div>
        <div style="border-top: 1px solid #E2E8F0; padding-top: 16px; margin-top: 24px; font-size: 12px; color: #94A3B8; line-height: 1.5;">
          <p style="margin: 0 0 6px 0; color: #DC2626; font-weight: 600;">🔒 Do not share this OTP with anyone.</p>
          <p style="margin: 0;">If you did not request a password reset, please ignore this email or contact support.</p>
        </div>
      </div>
    `,
  };

  try {
    const info = await activeTransporter.sendMail(mailOptions);
    console.log(`[EmailService] ✅ Email provider response: messageId=${info.messageId} status=sent to: ${maskedRecipient}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    const cleanError = error.message ? error.message.replace(/([a-zA-Z0-9_\-\.]{4,})@([a-zA-Z0-9_\-\.]+)/g, maskEmail) : 'Unknown SMTP delivery error';
    console.error(`[EmailService] ❌ Email sending failure reason: ${cleanError}`);
    return { success: false, error: cleanError };
  }
}

/**
 * Sends a 6-digit OTP verification email for new user registration.
 *
 * Subject: LifeLink Email Verification Code
 * Message:
 * Your LifeLink email verification code is: 123456
 * This code will expire in 5 minutes.
 * Do not share this code with anyone.
 */
async function sendRegistrationVerificationEmail(email, otp, recipientName = 'LifeLink User') {
  const normalizedEmail = (email || '').trim().toLowerCase();
  const maskedRecipient = maskEmail(normalizedEmail);
  const isTestAddress = normalizedEmail.endsWith('@lifelink-test.org') || process.env.NODE_ENV === 'test' || process.env.ALLOW_MOCK_EMAIL === 'true';

  console.log(`[EmailService] 📤 Registration verification email sending attempted for: ${maskedRecipient}`);

  // Check if email service is configured
  if (!isEmailServiceConfigured()) {
    if (isTestAddress) {
      console.log(`[EmailService] 🧪 Test suite detected for ${maskedRecipient}. Simulating delivery via jsonTransport.`);
      const mockTransporter = nodemailer.createTransport({ jsonTransport: true });
      const info = await mockTransporter.sendMail({
        from: '"LifeLink Security" <test-noreply@lifelink.org>',
        to: normalizedEmail,
        subject: 'LifeLink Email Verification Code',
        text: `Your LifeLink email verification code is: ${otp}\nThis code will expire in 5 minutes.\nDo not share this code with anyone.`,
      });
      console.log(`[EmailService] ✅ Email provider response: messageId=${info.messageId} status=simulated (test-suite)`);
      return { success: true, messageId: info.messageId, simulated: true };
    }

    const errorMsg = 'Email service is not configured. Missing SMTP_USER and SMTP_PASS/SMTP_PASSWORD in backend/.env.';
    console.error(`[EmailService] ❌ Email sending failure reason: ${errorMsg}`);
    return { success: false, error: errorMsg };
  }

  const activeTransporter = getTransporter();
  if (!activeTransporter) {
    const errorMsg = 'Failed to initialize email transport. Check SMTP configuration in backend/.env.';
    console.error(`[EmailService] ❌ Email sending failure reason: ${errorMsg}`);
    return { success: false, error: errorMsg };
  }

  const smtpUser = (process.env.SMTP_USER || process.env.EMAIL_USER || '').trim();
  const senderAddress = process.env.EMAIL_FROM || process.env.MAIL_FROM || (smtpUser ? `"LifeLink Security" <${smtpUser}>` : '"LifeLink Security" <noreply@lifelink.org>');

  const mailOptions = {
    from: senderAddress,
    to: normalizedEmail,
    subject: 'LifeLink Email Verification Code',
    text: `Hello ${recipientName},\n\nYour LifeLink email verification code is: ${otp}\n\nThis code will expire in 5 minutes.\n\nDo not share this code with anyone.\n\nLifeLink Emergency Blood Donation Network`,
    html: `
      <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px; background-color: #FFFFFF;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #E11D48; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">🩸 LifeLink</h2>
          <p style="color: #64748B; font-size: 13px; margin: 4px 0 0 0;">Emergency Blood Donation Network</p>
        </div>
        <div style="background-color: #FFF1F2; border-radius: 8px; padding: 16px; margin-bottom: 20px; border-left: 4px solid #E11D48;">
          <h3 style="margin: 0 0 8px 0; color: #9F1239; font-size: 16px;">Verify Your Email Address</h3>
          <p style="margin: 0; color: #475569; font-size: 14px; line-height: 1.5;">
            Hello <strong>${recipientName}</strong>, thank you for registering with LifeLink! To complete your registration and activate your account, use the verification code below:
          </p>
        </div>
        <div style="text-align: center; margin: 28px 0;">
          <div style="display: inline-block; background-color: #F8FAFC; border: 2px dashed #CBD5E1; border-radius: 12px; padding: 16px 36px;">
            <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #0F172A; font-family: monospace;">${otp}</span>
          </div>
          <p style="color: #64748B; font-size: 13px; margin-top: 12px; font-weight: 600;">⏳ This code will expire in <strong>5 minutes</strong>.</p>
        </div>
        <div style="border-top: 1px solid #E2E8F0; padding-top: 16px; margin-top: 24px; font-size: 12px; color: #94A3B8; line-height: 1.5;">
          <p style="margin: 0 0 6px 0; color: #DC2626; font-weight: 600;">🔒 Do not share this code with anyone.</p>
          <p style="margin: 0;">If you did not create an account on LifeLink, please ignore this email.</p>
        </div>
      </div>
    `,
  };

  try {
    const info = await activeTransporter.sendMail(mailOptions);
    console.log(`[EmailService] ✅ Email provider response: messageId=${info.messageId} status=sent to: ${maskedRecipient}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    const cleanError = error.message ? error.message.replace(/([a-zA-Z0-9_\-\.]{4,})@([a-zA-Z0-9_\-\.]+)/g, maskEmail) : 'Unknown SMTP delivery error';
    console.error(`[EmailService] ❌ Email sending failure reason: ${cleanError}`);
    return { success: false, error: cleanError };
  }
}

module.exports = {
  sendPasswordResetEmail,
  sendRegistrationVerificationEmail,
  verifyEmailConnection,
  isEmailServiceConfigured,
  getEmailConfigSummary,
  maskEmail,
};
