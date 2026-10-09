// Reuses the profile city collected for both donor and recipient registration.
const normalizeCity = city => typeof city === 'string' ? city.trim().toLowerCase() : '';
function meaningfulChange(stock, previousStock) {
  return previousStock
    ? ['availableUnits', 'status', 'bloodGroup'].some(field => stock[field] !== previousStock[field])
    : stock.status === 'Available' && stock.availableUnits > 0;
}
async function notifyLocalUsersOfBloodStockUpdate(tx, { stock, previousStock, manager }) {
  if (!meaningfulChange(stock, previousStock)) return 0;
  const city = normalizeCity(manager.branch.city);
  if (!city) return 0;
  // Exact normalized equality; addresses and BloodRequest hospitals are never used.
  const users = await tx.user.findMany({
    where: { isActive: true, role: { in: ['donor', 'recipient'] }, id: { not: manager.id }, donorProfile: { isNot: null } },
    select: { id: true, donorProfile: { select: { city: true } } },
  });
  const ids = [...new Set(users.filter(user => normalizeCity(user.donorProfile?.city) === city).map(user => user.id))];
  if (!ids.length) return 0;
  const { branch } = manager;
  const result = await tx.notification.createMany({ data: ids.map(userId => ({
    userId, type: 'BLOOD_STOCK_UPDATE', title: `${stock.bloodGroup} Blood Stock Update`,
    message: `${stock.bloodGroup} blood is now ${stock.status} at ${branch.name.trim()} - ${branch.city.trim()}. ${stock.availableUnits} units currently available.`,
    isRead: false,
  })) });
  return result.count;
}
module.exports = { normalizeCity, meaningfulChange, notifyLocalUsersOfBloodStockUpdate };
