const { getEmailConfigSummary, verifyEmailConnection } = require('../services/email.service');

async function main() {
  const summary = getEmailConfigSummary();
  if (!summary.configured) {
    console.error(`Email delivery unavailable. Set ${summary.missingCredentials.join(' and ')} in backend/.env.`);
    process.exitCode = 1;
    return;
  }
  const result = await verifyEmailConnection();
  if (!result.success) process.exitCode = 1;
}

main().catch(() => {
  console.error('Email connection check failed. Check backend/.env SMTP settings.');
  process.exitCode = 1;
});
