const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { prisma, db } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');

const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

function sanitizeUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  return {
    ...safeUser,
    status: safeUser.isActive === false ? 'DEACTIVATED' : 'ACTIVE',
  };
}

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { name, email, phone, password, role } = req.body;

    if (!name || !email || !phone) {
      return res.status(400).json({ success: false, message: 'Name, email, and phone are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // 1. Try Prisma / Supabase
    if (prisma) {
      try {
        // Case-insensitive email existence check before creating user
        const existing = await prisma.user.findFirst({
          where: {
            email: {
              equals: normalizedEmail,
              mode: 'insensitive',
            },
          },
        });

        if (existing) {
          return res.status(400).json({
            success: false,
            message: 'An account with this email already exists.',
          });
        }

        const hashedPassword = await bcrypt.hash(password || 'lifelink123', 10);
        const createdUser = await prisma.user.create({
          data: {
            name: name.trim(),
            email: normalizedEmail,
            phone: phone.trim(),
            password: hashedPassword,
            role: role || 'donor',
            isActive: true,
          },
        });

        // Mirror in in-memory store for fallback parity
        const safe = sanitizeUser(createdUser);
        const memoryUserRecord = {
          ...safe,
          password: hashedPassword,
        };
        const existingIndex = db.users.findIndex(u => u.email.toLowerCase() === normalizedEmail);
        if (existingIndex !== -1) {
          db.users[existingIndex] = memoryUserRecord;
        } else {
          db.users.push(memoryUserRecord);
        }

        const token = jwt.sign({ id: createdUser.id, role: createdUser.role }, JWT_SECRET, { expiresIn: '30d' });

        return res.status(201).json({
          success: true,
          message: 'Account registered successfully',
          data: { user: safe, token },
        });
      } catch (dbError) {
        // Handle database-level unique constraint error (P2002 or Postgres duplicate key)
        if (
          dbError.code === 'P2002' ||
          (dbError.message && (
            dbError.message.includes('Unique constraint failed') ||
            dbError.message.includes('unique constraint') ||
            dbError.message.includes('User_email_lower_key') ||
            dbError.message.includes('User_email_key')
          ))
        ) {
          return res.status(400).json({
            success: false,
            message: 'An account with this email already exists.',
          });
        }

        console.error('Prisma register error, falling back to memory:', dbError.message);
      }
    }

    // In-memory fallback (only used if PostgreSQL/Supabase is unreachable)
    const existingMemory = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    if (existingMemory) {
      return res.status(400).json({
        success: false,
        message: 'An account with this email already exists.',
      });
    }

    const hashedPasswordFallback = await bcrypt.hash(password || 'lifelink123', 10);
    const newUser = {
      id: `usr_${Date.now()}`,
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      password: hashedPasswordFallback,
      role: role || 'donor',
      isActive: true,
      createdAt: new Date().toISOString(),
    };

    db.users.push(newUser);
    const token = jwt.sign({ id: newUser.id, role: newUser.role }, JWT_SECRET, { expiresIn: '30d' });

    return res.status(201).json({
      success: true,
      message: 'Account registered successfully (in-memory mode)',
      data: { user: sanitizeUser(newUser), token },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || typeof email !== 'string' || !email.trim()) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    if (!password || typeof password !== 'string' || !password.trim()) {
      return res.status(400).json({ success: false, message: 'Password is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // 1. Try Prisma / Supabase PostgreSQL
    if (prisma) {
      try {
        const user = await prisma.user.findFirst({
          where: {
            email: {
              equals: normalizedEmail,
              mode: 'insensitive',
            },
          },
        });

        if (user) {
          // Compare password securely using bcrypt
          const isMatch = await bcrypt.compare(password, user.password).catch(() => false);
          if (!isMatch) {
            return res.status(401).json({
              success: false,
              message: 'Invalid email or password.',
            });
          }

          if (user.isActive === false) {
            return res.status(403).json({
              success: false,
              message: 'Your account has been deactivated. Please contact support to reactivate your account.',
            });
          }

          const safeUser = sanitizeUser(user);
          const token = jwt.sign(
            { id: user.id, role: user.role },
            JWT_SECRET,
            { expiresIn: '30d' }
          );

          return res.json({
            success: true,
            message: 'Login successful',
            data: { user: safeUser, token },
          });
        }
      } catch (dbError) {
        console.error('Prisma login error, checking fallback store:', dbError.message);
      }
    }

    // In-memory fallback (only for standalone execution or offline fallback)
    // NEVER auto-provision non-existent accounts on login!
    const memoryUser = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    if (!memoryUser) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    let isMatch = false;
    if (memoryUser.password) {
      if (memoryUser.password.startsWith('$2')) {
        isMatch = await bcrypt.compare(password, memoryUser.password).catch(() => false);
      } else {
        isMatch = (memoryUser.password === password);
      }
    } else {
      isMatch = (password === 'password123' || password === 'lifelink123');
    }

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    if (memoryUser.isActive === false) {
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Please contact support to reactivate your account.',
      });
    }

    const safeUser = sanitizeUser(memoryUser);
    const token = jwt.sign(
      { id: memoryUser.id, role: memoryUser.role },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Login successful',
      data: { user: safeUser, token },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred during login. Please try again.',
    });
  }
});

// GET /api/auth/me
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    let userId = null;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = jwt.verify(authHeader.split(' ')[1], JWT_SECRET);
        userId = decoded.id;
      } catch (_) {}
    }

    if (prisma) {
      try {
        let user = null;
        if (userId) {
          user = await prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user) {
          user = await prisma.user.findFirst({ orderBy: { createdAt: 'desc' } });
        }
        if (user) {
          return res.json({ success: true, data: sanitizeUser(user) });
        }
      } catch (dbError) {
        console.error('Prisma get /me error:', dbError.message);
      }
    }

    const user = db.users[0] || null;
    return res.json({ success: true, data: sanitizeUser(user) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/user/:id or /api/auth/users/:id
router.get(['/user/:id', '/users/:id'], async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        const user = await prisma.user.findUnique({
          where: { id },
        });
        if (user) {
          return res.json({ success: true, data: sanitizeUser(user) });
        }
      } catch (dbError) {
        console.error('Prisma find user error:', dbError.message);
      }
    }

    const memoryUser = db.users.find(u => u.id === id);
    if (!memoryUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    return res.json({ success: true, data: sanitizeUser(memoryUser) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/users
router.get('/users', async (req, res) => {
  try {
    if (prisma) {
      try {
        const users = await prisma.user.findMany({
          orderBy: { createdAt: 'desc' },
        });
        return res.json({ success: true, data: users.map(sanitizeUser) });
      } catch (dbError) {
        console.error('Prisma findMany users error:', dbError.message);
      }
    }

    return res.json({ success: true, data: db.users.map(sanitizeUser) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/auth/profile
router.put('/profile', async (req, res) => {
  try {
    const { userId, name, phone, email } = req.body;
    const normalizedEmail = email ? email.toLowerCase().trim() : undefined;

    if (prisma && userId) {
      try {
        if (normalizedEmail) {
          const emailConflict = await prisma.user.findFirst({
            where: {
              email: { equals: normalizedEmail, mode: 'insensitive' },
              id: { not: userId },
            },
          });
          if (emailConflict) {
            return res.status(400).json({
              success: false,
              message: 'An account with this email already exists.',
            });
          }
        }

        const updated = await prisma.user.update({
          where: { id: userId },
          data: {
            ...(name ? { name: name.trim() } : {}),
            ...(phone ? { phone: phone.trim() } : {}),
            ...(normalizedEmail ? { email: normalizedEmail } : {}),
          },
        });
        return res.json({ success: true, message: 'Profile updated', data: sanitizeUser(updated) });
      } catch (dbError) {
        if (
          dbError.code === 'P2002' ||
          (dbError.message && (
            dbError.message.includes('Unique constraint failed') ||
            dbError.message.includes('unique constraint') ||
            dbError.message.includes('User_email_lower_key') ||
            dbError.message.includes('User_email_key')
          ))
        ) {
          return res.status(400).json({
            success: false,
            message: 'An account with this email already exists.',
          });
        }
        console.error('Prisma update profile error:', dbError.message);
      }
    }

    const user = db.users.find(u => u.id === userId) || db.users[0];
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (normalizedEmail) {
      const emailConflict = db.users.find(u => u.id !== userId && u.email.toLowerCase() === normalizedEmail);
      if (emailConflict) {
        return res.status(400).json({
          success: false,
          message: 'An account with this email already exists.',
        });
      }
    }

    if (name) user.name = name.trim();
    if (phone) user.phone = phone.trim();
    if (normalizedEmail) user.email = normalizedEmail;

    return res.json({ success: true, message: 'Profile updated', data: sanitizeUser(user) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/deactivate
router.post('/deactivate', authenticateToken, async (req, res) => {
  try {
    let targetUserId = req.user?.id;
    if (req.body?.userId && req.body.userId !== req.user?.id) {
      if (req.user?.role !== 'admin' && req.user?.role !== 'manager') {
        return res.status(403).json({
          success: false,
          message: 'You are not authorized to deactivate this account.',
        });
      }
      targetUserId = req.body.userId;
    }

    if (!targetUserId) {
      return res.status(400).json({ success: false, message: 'User ID is required' });
    }

    if (prisma) {
      try {
        const existing = await prisma.user.findUnique({
          where: { id: targetUserId },
        });

        if (!existing) {
          const memoryUser = db.users.find(u => u.id === targetUserId);
          if (!memoryUser) {
            return res.status(404).json({ success: false, message: 'User not found' });
          }
          if (memoryUser.isActive === false) {
            return res.status(400).json({ success: false, message: 'Account is already deactivated.' });
          }
          memoryUser.isActive = false;
          return res.json({
            success: true,
            message: 'Your account has been deactivated.',
          });
        }

        if (existing.isActive === false) {
          return res.status(400).json({ success: false, message: 'Account is already deactivated.' });
        }

        // Soft-deactivate: update status to false without deleting user or donation/request history
        await prisma.user.update({
          where: { id: targetUserId },
          data: { isActive: false },
        });

        // Set donor availability to false if donor profile exists
        try {
          await prisma.donorProfile.updateMany({
            where: { userId: targetUserId },
            data: { isAvailable: false },
          });
        } catch (_) {}

        // Mirror in memory store
        const memoryUser = db.users.find(u => u.id === targetUserId || (existing.email && u.email.toLowerCase() === existing.email.toLowerCase()));
        if (memoryUser) memoryUser.isActive = false;

        return res.json({
          success: true,
          message: 'Your account has been deactivated.',
        });
      } catch (dbError) {
        console.error('Prisma deactivate error, using fallback:', dbError.message);
      }
    }

    // In-memory fallback
    const user = db.users.find(u => u.id === targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (user.isActive === false) {
      return res.status(400).json({ success: false, message: 'Account is already deactivated.' });
    }

    user.isActive = false;

    const donorProf = db.donorProfiles && db.donorProfiles.find(dp => dp.userId === targetUserId);
    if (donorProf) donorProf.isAvailable = false;

    return res.json({
      success: true,
      message: 'Your account has been deactivated.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Internal server error while deactivating account.',
    });
  }
});

module.exports = router;
