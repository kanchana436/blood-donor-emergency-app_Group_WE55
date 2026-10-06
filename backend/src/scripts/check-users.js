const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

async function main() {
  try {
    const users = await p.user.findMany({
      select: { id: true, name: true, email: true, role: true, isActive: true }
    });
    console.log('USERS IN DB:', JSON.stringify(users, null, 2));
  } catch (err) {
    console.error('Error fetching users:', err.message);
  } finally {
    await p.$disconnect();
  }
}

main();
