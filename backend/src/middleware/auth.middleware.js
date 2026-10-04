const jwt = require('jsonwebtoken');
const { prisma, db } = require('../prisma');

const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.split(' ')[1] : null;

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access denied: Authentication token required',
    });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;

    // Verify user still exists and isActive in database
    if (prisma && decoded.id) {
      try {
        const user = await prisma.user.findUnique({ where: { id: decoded.id } });
        if (user && !user.isActive) {
          return res.status(403).json({
            success: false,
            message: 'User account is deactivated',
          });
        }
      } catch (_) {}
    }

    next();
  } catch (err) {
    return res.status(403).json({
      success: false,
      message: 'Invalid or expired authentication token',
    });
  }
}

function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.split(' ')[1] : null;

  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
  } catch (_) {}

  next();
}

module.exports = {
  authenticateToken,
  optionalAuth,
  JWT_SECRET,
};
