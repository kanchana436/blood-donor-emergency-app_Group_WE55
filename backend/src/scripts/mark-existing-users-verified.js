const { prisma } = require('../prisma');

async function markExistingUsersVerified() {
  if (!prisma) {
    console.log('Prisma not available.');
    process.exit(0);
  }

  try {
    // Mark all existing users who were created prior to the new feature as verified,
    // especially demo users sarah.p@lifelink.org and alexander@lifelink.org
    const count = await prisma.$executeRawUnsafe(`
      UPDATE public."User" 
      SET "is_email_verified" = true 
      WHERE "is_email_verified" = false
        AND "email" NOT LIKE 'newreg_%';
    `);

    console.log(`✅ Successfully updated ${count} existing users to is_email_verified = true.`);

    const demoUsers = await prisma.user.findMany({
      where: {
        email: {
          in: ['sarah.p@lifelink.org', 'alexander@lifelink.org', 'priyadarshanikanchana436@gmail.com'],
        },
      },
      select: {
        email: true,
        role: true,
        isEmailVerified: true,
      },
    });

    console.log('Demo Users Status:', demoUsers);
  } catch (err) {
    console.error('Error updating users:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

markExistingUsersVerified();
