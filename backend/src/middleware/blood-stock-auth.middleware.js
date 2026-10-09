const { prisma } = require('../prisma');

// Runs after authenticateToken. Re-check against PostgreSQL because the shared
// middleware intentionally permits a memory fallback for existing features.
async function authorizeBloodStock(req, res, next) {
  try {
    if (!prisma) throw new Error('Prisma unavailable');
    const user = req.user?.id
      ? await prisma.user.findUnique({ where: { id: req.user.id }, include: { branch: true } })
      : null;
    if (!user) {
      return res.status(401).json({ success: false, message: 'Authenticated account not found' });
    }
    if (!user.isActive || !['manager', 'admin'].includes(user.role)) {
      return res.status(403).json({ success: false, message: 'An active manager or admin account is required' });
    }
    if (!user.branch || !user.branch.name.trim() || !user.branch.city.trim()) {
      return res.status(403).json({ success: false, message: 'A verified branch with a city must be assigned to your account before managing stock' });
    }
    req.stockManager = user;
    return next();
  } catch (error) {
    console.error('Blood stock authorization failed:', error.message);
    return res.status(500).json({ success: false, message: 'Blood stock database is unavailable' });
  }
}

module.exports = { authorizeBloodStock };
