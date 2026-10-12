const { prisma } = require('../prisma');
const { stageProfileChanges } = require('../services/verification-profile.service');
// Runs after JWT authentication, before legacy profile handlers and their memory fallbacks.
function verificationProfile(medical) {
  return async (req, res, next) => {
    try {
      if (!prisma) throw new Error('Database unavailable');
      const user = req.user?.id ? await prisma.user.findUnique({ where: { id: req.user.id } }) : null;
      if (!user) return res.status(401).json({ success: false, message: 'Authenticated account not found' });
      if (!user.isActive) return res.status(403).json({ success: false, message: 'An active account is required' });
      if (req.body?.userId && req.body.userId !== user.id) return res.status(403).json({ success: false, message: 'You can only edit your own profile' });
      if (user.role !== 'donor') {
        if (medical) return res.status(403).json({ success: false, message: 'A donor account is required' });
        return next();
      }
      const result = await stageProfileChanges(prisma, user.id, req.body || {}, medical);
      return res.json({ success: true, data: result.data, verification: result.verification,
        message: result.verification ? 'Your profile changes are waiting for Blood Bank verification.' : 'No verification-sensitive changes submitted.' });
    } catch (error) {
      console.error('Profile verification submission failed:', error.message);
      return res.status(error.status || 500).json({ success: false, message: error.status ? error.message : 'Unable to submit profile changes for verification' });
    }
  };
}
module.exports = { verificationProfile };
