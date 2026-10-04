const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { prisma, db } = require('../prisma');

const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

function sanitizeUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  return safeUser;
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
        const existing = await prisma.user.findUnique({
          where: { email: normalizedEmail },
        });

        if (existing) {
          return res.status(400).json({ success: false, message: 'Email is already registered' });
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
        db.users.push(safe);

        const token = jwt.sign({ id: createdUser.id, role: createdUser.role }, JWT_SECRET, { expiresIn: '30d' });

        return res.status(201).json({
          success: true,
          message: 'Account registered successfully',
          data: { user: safe, token },
        });
      } catch (dbError) {
        console.error('Prisma register error, falling back to memory:', dbError.message);
      }
    }

    // In-memory fallback
    const existingMemory = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    if (existingMemory) {
      return res.status(400).json({ success: false, message: 'Email is already registered' });
    }

    const newUser = {
      id: `usr_${Date.now()}`,
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      role: role || 'donor',
      isActive: true,
      createdAt: new Date().toISOString(),
    };

    db.users.push(newUser);
    const token = jwt.sign({ id: newUser.id, role: newUser.role }, JWT_SECRET, { expiresIn: '30d' });

    return res.status(201).json({
      success: true,
      message: 'Account registered successfully (in-memory mode)',
      data: { user: newUser, token },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    if (prisma) {
      try {
        let user = await prisma.user.findUnique({
          where: { email: normalizedEmail },
        });

        if (user) {
          if (password) {
            const isMatch = await bcrypt.compare(password, user.password).catch(() => false);
            if (!isMatch && user.password !== password) {
              return res.status(401).json({ success: false, message: 'Invalid credentials' });
            }
          }

          const safeUser = sanitizeUser(user);
          const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
          return res.json({
            success: true,
            message: 'Login successful',
            data: { user: safeUser, token },
          });
        }
      } catch (dbError) {
        console.error('Prisma login error, using fallback:', dbError.message);
      }
    }

    // Fallback search or auto-provision
    let user = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    if (!user) {
      user = {
        id: `usr_${Date.now()}`,
        name: email.split('@')[0],
        email: normalizedEmail,
        phone: '+94 77 123 4567',
        role: email.includes('recip') ? 'recipient' : 'donor',
        isActive: true,
        createdAt: new Date().toISOString(),
      };
      db.users.push(user);
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    return res.json({
      success: true,
      message: 'Login successful',
      data: { user: sanitizeUser(user), token },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
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

    if (prisma && userId) {
      try {
        const updated = await prisma.user.update({
          where: { id: userId },
          data: {
            ...(name ? { name } : {}),
            ...(phone ? { phone } : {}),
            ...(email ? { email } : {}),
          },
        });
        return res.json({ success: true, message: 'Profile updated', data: sanitizeUser(updated) });
      } catch (dbError) {
        console.error('Prisma update profile error:', dbError.message);
      }
    }

    const user = db.users.find(u => u.id === userId) || db.users[0];
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (email) user.email = email;

    return res.json({ success: true, message: 'Profile updated', data: sanitizeUser(user) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/deactivate
router.post('/deactivate', async (req, res) => {
  try {
    const { userId } = req.body;

    if (prisma && userId) {
      try {
        await prisma.user.update({
          where: { id: userId },
          data: { isActive: false },
        });
        return res.json({ success: true, message: 'Account deactivated' });
      } catch (dbError) {
        console.error('Prisma deactivate error:', dbError.message);
      }
    }

    const user = db.users.find(u => u.id === userId);
    if (user) user.isActive = false;

    return res.json({ success: true, message: 'Account deactivated' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
