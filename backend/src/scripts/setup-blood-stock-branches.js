// Trusted operator utility. Never called by the API or tests; does not apply SQL.
require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const [command, ...args] = process.argv.slice(2);
const options = {};
for (let i = 0; i < args.length; i += 2) {
  if (!args[i].startsWith('--') || !args[i + 1] || args[i + 1].startsWith('--')) throw new Error('Expected --option value pairs');
  options[args[i].slice(2)] = args[i + 1].trim();
}
function required(key) { if (!options[key]) throw new Error(`--${key} is required`); return options[key]; }
async function run() {
  if (command === 'inspect') {
    console.log(JSON.stringify({
      branches: await prisma.bloodBankBranch.findMany(),
      managers: await prisma.user.findMany({ where: { role: { in: ['manager', 'admin'] } }, select: { id: true, name: true, role: true, isActive: true, branchId: true } }),
      stocks: await prisma.bloodStock.findMany(),
    }, null, 2));
    return;
  }
  if (command === 'create-branch') {
    const data = { id: required('id'), name: required('name'), city: required('city') };
    const branch = await prisma.bloodBankBranch.upsert({ where: { id: data.id }, create: data, update: {} });
    if (branch.name !== data.name || branch.city !== data.city) throw new Error('That branch ID already has different details. Review it; no changes made.');
    console.log(JSON.stringify(branch)); return;
  }
  if (!['assign-manager', 'assign-stock'].includes(command)) {
    throw new Error('Use inspect, create-branch, assign-manager, or assign-stock. See docs/blood-stock-city-notifications.md.');
  }
  const branchId = required('branch-id');
  await prisma.$transaction(async tx => {
    const branch = await tx.bloodBankBranch.findUnique({ where: { id: branchId } });
    if (!branch?.name.trim() || !branch.city.trim()) throw new Error('Branch must exist with a verified name and city');
    if (command === 'assign-manager') {
      const id = required('manager-id');
      await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${id} FOR UPDATE`;
      const user = await tx.user.findUnique({ where: { id } });
      if (!user || !['manager', 'admin'].includes(user.role)) throw new Error('Select an existing manager/admin account');
      if (user.branchId && user.branchId !== branchId) throw new Error('Manager is already assigned elsewhere; no reassignment performed');
      await tx.user.update({ where: { id }, data: { branchId } });
      console.log(`Assigned manager ${id} to ${branchId}`);
    } else {
      const id = required('stock-id');
      await tx.$queryRaw`SELECT "id" FROM "BloodStock" WHERE "id" = ${id} FOR UPDATE`;
      const stock = await tx.bloodStock.findUnique({ where: { id } });
      if (!stock) throw new Error('Stock record not found');
      if (stock.branchId && stock.branchId !== branchId) throw new Error('Stock is already assigned elsewhere; no reassignment performed');
      await tx.bloodStock.update({ where: { id }, data: { branchId } });
      console.log(`Assigned stock ${id} to ${branchId}; units, status, blood group and location preserved`);
    }
  });
}
run().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => prisma.$disconnect());
