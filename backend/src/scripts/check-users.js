const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

async function main() {
  try {
    const rows = await p.$queryRawUnsafe('SELECT id, name, email, is_email_verified FROM public."User" WHERE LOWER(email) = $1', 'priyadarshanik504@gmail.com');
    console.log('USER STATUS:', JSON.stringify(rows, null, 2));
    const otps = await p.$queryRawUnsafe('SELECT id, email, "expiresAt", used, attempts, "createdAt" FROM "EmailVerificationOtp" WHERE LOWER(email) = $1 ORDER BY "createdAt" DESC', 'priyadarshanik504@gmail.com');
    console.log('OTPS IN DB:', JSON.stringify(otps, null, 2));
  } catch (err) {
    console.error('Error fetching users:', err.message);
  } finally {
    await p.$disconnect();
  }
}

main();
