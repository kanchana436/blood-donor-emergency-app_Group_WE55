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

    const isDeactivateEndpoint = req.path === '/deactivate' || (req.originalUrl && req.originalUrl.endsWith('/deactivate'));

    // Verify user still exists and isActive in database
    if (prisma && decoded.id) {
      try {
        const user = await prisma.user.findUnique({ where: { id: decoded.id } });
        if (user) {
          if (user.isActive === false && !isDeactivateEndpoint) {
            return res.status(403).json({
              success: false,
              message: 'Your account has been deactivated. Please contact support to reactivate your account.',
            });
          }
          req.dbUser = user;
          return next();
        }
      } catch (dbErr) {
        console.error('Error fetching user in auth middleware:', dbErr.message);
      }
    }

    // In-memory fallback
    const memoryUser = db.users.find(u => u.id === decoded.id);
    if (memoryUser) {
      if (memoryUser.isActive === false && !isDeactivateEndpoint) {
        return res.status(403).json({
          success: false,
          message: 'Your account has been deactivated. Please contact support to reactivate your account.',
        });
      }
      req.dbUser = memoryUser;
      return next();
    }

    next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired authentication token',
    });
  }
}

async function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.split(' ')[1] : null;

  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;

    if (prisma && decoded.id) {
      try {
        const user = await prisma.user.findUnique({ where: { id: decoded.id } });
        if (user && user.isActive === false) {
          return res.status(403).json({
            success: false,
            message: 'Your account has been deactivated. Please contact support to reactivate your account.',
          });
        }
      } catch (_) {}
    }

    const memoryUser = db.users.find(u => u.id === decoded.id);
    if (memoryUser && memoryUser.isActive === false) {
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Please contact support to reactivate your account.',
      });
    }
  } catch (_) {}

  next();
}

module.exports = {
  authenticateToken,
  optionalAuth,
  JWT_SECRET,
};
