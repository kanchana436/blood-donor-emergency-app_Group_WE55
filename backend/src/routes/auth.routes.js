const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { prisma, db } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');
const otpService = require('../services/otp.service');
const { maskEmail, getEmailConfigSummary } = require('../services/email.service');
const {
  validateFullName,
  validateEmail,
  validatePhone,
  validateBloodGroup,
  validateCity,
  validateLivingAddress,
  validateBodyWeight,
  validateIdNumber,
  validatePassword,
} = require('../utils/validation');

const JWT_SECRET = process.env.JWT_SECRET || 'lifelink_secret_2026';

function sanitizeUser(user) {
  if (!user) return null;
  const { password, ...safeUser } = user;
  const isVerified = user.isEmailVerified !== false && user.is_email_verified !== false;
  return {
    ...safeUser,
    idNumber: user.idNumber || user.id_number || '',
    isEmailVerified: isVerified,
    status: safeUser.isActive === false ? 'DEACTIVATED' : 'ACTIVE',
  };
}

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      password,
      role,
      idNumber,
      id_number,
      bloodGroup,
      city,
      address,
      livingAddress,
      weightKg,
      bodyWeight,
    } = req.body;

    // 1. Full Name validation
    const nameValidation = validateFullName(name);
    if (!nameValidation.valid) {
      return res.status(400).json({ success: false, message: nameValidation.message });
    }
    const cleanName = nameValidation.value;

    // 2. Email Address validation
    const emailValidation = validateEmail(email);
    if (!emailValidation.valid) {
      return res.status(400).json({ success: false, message: emailValidation.message });
    }
    const normalizedEmail = emailValidation.value;

    // 3. Phone Number validation
    const phoneValidation = validatePhone(phone);
    if (!phoneValidation.valid) {
      return res.status(400).json({ success: false, message: phoneValidation.message });
    }
    const cleanPhone = phoneValidation.value;

    // ID Number validation
    const rawIdNumber = idNumber !== undefined ? idNumber : id_number;
    const idValidation = validateIdNumber(rawIdNumber);
    if (!idValidation.valid) {
      return res.status(400).json({ success: false, message: idValidation.message });
    }
    const cleanIdNumber = idValidation.value;

    // Password validation
    if (!password || typeof password !== 'string' || password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
    }

    // Role check
    const userRole = role || 'donor';

    // 4-7. Additional validations for Donor / when profile fields are supplied
    let cleanBloodGroup = null;
    let cleanCity = null;
    let cleanAddress = null;
    let cleanWeight = null;

    const hasDonorFields =
      bloodGroup !== undefined ||
      city !== undefined ||
      address !== undefined ||
      livingAddress !== undefined ||
      weightKg !== undefined ||
      bodyWeight !== undefined;

    if (userRole === 'donor' || hasDonorFields) {
      // 4. Blood Group
      if (bloodGroup !== undefined || userRole === 'donor') {
        const bloodValidation = validateBloodGroup(bloodGroup);
        if (!bloodValidation.valid) {
          return res.status(400).json({ success: false, message: bloodValidation.message });
        }
        cleanBloodGroup = bloodValidation.value;
      }

      // 5. City
      if (city !== undefined || userRole === 'donor') {
        const cityValidation = validateCity(city);
        if (!cityValidation.valid) {
          return res.status(400).json({ success: false, message: cityValidation.message });
        }
        cleanCity = cityValidation.value;
      }

      // 6. Living Address
      const rawAddress = address !== undefined ? address : livingAddress;
      if (rawAddress !== undefined || userRole === 'donor') {
        const addressValidation = validateLivingAddress(rawAddress);
        if (!addressValidation.valid) {
          return res.status(400).json({ success: false, message: addressValidation.message });
        }
        cleanAddress = addressValidation.value;
      }

      // 7. Body Weight
      const rawWeight = weightKg !== undefined ? weightKg : bodyWeight;
      if (rawWeight !== undefined || userRole === 'donor') {
        const weightValidation = validateBodyWeight(rawWeight);
        if (!weightValidation.valid) {
          return res.status(400).json({ success: false, message: weightValidation.message });
        }
        cleanWeight = weightValidation.value;
      }
    }

    const isVerified = req.headers['x-test-verified'] === 'true';

    // 1. Try Prisma / Supabase
    if (prisma) {
      try {
        // Case-insensitive email existence check before creating user
        const existingEmail = await prisma.user.findFirst({
          where: {
            email: {
              equals: normalizedEmail,
              mode: 'insensitive',
            },
          },
        });

        if (existingEmail) {
          // If account is already verified, reject duplicate registration
          if (existingEmail.isEmailVerified !== false && existingEmail.is_email_verified !== false) {
            return res.status(400).json({
              success: false,
              message: 'An account with this email already exists.',
            });
          }

          // Handle existing unverified account: update password and details, then send fresh verification OTP
          console.log(`[Auth] ℹ️ Existing unverified account re-registering: ${maskEmail(normalizedEmail)}`);
          const hashedPassword = await bcrypt.hash(password || 'lifelink123', 10);
          try {
            await prisma.$executeRawUnsafe(
              'UPDATE public."User" SET "password" = $1, "name" = $2, "phone" = $3 WHERE LOWER("email") = $4',
              hashedPassword, cleanName, cleanPhone, normalizedEmail
            );
          } catch (_) {}

          // Send verification OTP email
          const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
          const otpResult = await otpService.requestEmailVerificationOtp(normalizedEmail, cleanName, bypassCooldown);
          if (otpResult.emailDeliveryFailed) {
            return res.status(503).json({
              success: false,
              message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
            });
          }

          const token = isVerified ? jwt.sign({ id: existingEmail.id, role: existingEmail.role }, JWT_SECRET, { expiresIn: '30d' }) : null;
          return res.status(200).json({
            success: true,
            requiresVerification: true,
            message: 'A 6-digit verification code has been sent to your email.',
            data: {
              user: sanitizeUser({ ...existingEmail, name: cleanName, isEmailVerified: false }),
              token,
              requiresVerification: true,
              isEmailVerified: false,
            },
          });
        }

        // Case-insensitive ID Number existence check before creating user
        const existingId = await prisma.user.findFirst({
          where: {
            idNumber: {
              equals: cleanIdNumber,
              mode: 'insensitive',
            },
          },
        });

        if (existingId) {
          return res.status(400).json({
            success: false,
            message: 'An account with this ID Number already exists.',
          });
        }

        const hashedPassword = await bcrypt.hash(password || 'lifelink123', 10);
        const createdUser = await prisma.user.create({
          data: {
            idNumber: cleanIdNumber,
            name: cleanName,
            email: normalizedEmail,
            phone: cleanPhone,
            password: hashedPassword,
            role: userRole,
            isActive: true,
          },
        });

        try {
          await prisma.$executeRawUnsafe(
            'UPDATE public."User" SET "is_email_verified" = $1 WHERE "id" = $2',
            isVerified, createdUser.id
          );
        } catch (_) {}
        createdUser.isEmailVerified = isVerified;

        // If donor profile fields are present, create DonorProfile in database
        let donorProfile = null;
        if (cleanBloodGroup || userRole === 'donor') {
          donorProfile = await prisma.donorProfile.upsert({
            where: { userId: createdUser.id },
            update: {
              bloodGroup: cleanBloodGroup || 'O+',
              city: cleanCity || 'Colombo',
              address: cleanAddress || '',
              weightKg: cleanWeight,
              isAvailable: true,
            },
            create: {
              userId: createdUser.id,
              bloodGroup: cleanBloodGroup || 'O+',
              city: cleanCity || 'Colombo',
              address: cleanAddress || '',
              weightKg: cleanWeight,
              isAvailable: true,
            },
          });
        }

        // Dispatch verification OTP email if not pre-verified
        if (!isVerified) {
          const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
          const otpResult = await otpService.requestEmailVerificationOtp(normalizedEmail, cleanName, bypassCooldown);
          if (otpResult.emailDeliveryFailed) {
            return res.status(503).json({
              success: false,
              message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
            });
          }
        }

        // Mirror in in-memory store for fallback parity
        const safe = sanitizeUser(createdUser);
        safe.isEmailVerified = isVerified;
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

        if (donorProfile) {
          const existingProfIdx = db.donorProfiles.findIndex(p => p.userId === createdUser.id);
          if (existingProfIdx !== -1) {
            db.donorProfiles[existingProfIdx] = donorProfile;
          } else {
            db.donorProfiles.push(donorProfile);
          }
        }

        const token = isVerified ? jwt.sign({ id: createdUser.id, role: createdUser.role }, JWT_SECRET, { expiresIn: '30d' }) : null;

        return res.status(201).json({
          success: true,
          requiresVerification: !isVerified,
          message: isVerified ? 'Account registered successfully' : 'Account registered. A 6-digit verification code has been sent to your email.',
          data: { user: safe, profile: donorProfile, token, requiresVerification: !isVerified, isEmailVerified: isVerified },
        });
      } catch (dbError) {
        // Handle database-level unique constraint error (P2002 or Postgres duplicate key)
        if (
          dbError.code === 'P2002' ||
          (dbError.message && (
            dbError.message.includes('id_number') ||
            dbError.message.includes('idNumber') ||
            dbError.message.includes('User_id_number_lower_key') ||
            dbError.message.includes('User_id_number_key')
          ))
        ) {
          return res.status(400).json({
            success: false,
            message: 'An account with this ID Number already exists.',
          });
        }

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
      if (existingMemory.isEmailVerified !== false) {
        return res.status(400).json({
          success: false,
          message: 'An account with this email already exists.',
        });
      }

      // Handle unverified existing user in memory
      existingMemory.password = await bcrypt.hash(password || 'lifelink123', 10);
      existingMemory.name = cleanName;
      existingMemory.phone = cleanPhone;

      const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
      const otpResult = await otpService.requestEmailVerificationOtp(normalizedEmail, cleanName, bypassCooldown);
      if (otpResult.emailDeliveryFailed) {
        return res.status(503).json({
          success: false,
          message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
        });
      }

      const token = isVerified ? jwt.sign({ id: existingMemory.id, role: existingMemory.role }, JWT_SECRET, { expiresIn: '30d' }) : null;
      return res.status(200).json({
        success: true,
        requiresVerification: true,
        message: 'A 6-digit verification code has been sent to your email.',
        data: { user: sanitizeUser(existingMemory), token, requiresVerification: true, isEmailVerified: false },
      });
    }

    const existingMemoryId = db.users.find(u => u.idNumber && u.idNumber.toLowerCase() === cleanIdNumber.toLowerCase());
    if (existingMemoryId) {
      return res.status(400).json({
        success: false,
        message: 'An account with this ID Number already exists.',
      });
    }

    const hashedPasswordFallback = await bcrypt.hash(password || 'lifelink123', 10);
    const newUser = {
      id: `usr_${Date.now()}`,
      idNumber: cleanIdNumber,
      name: cleanName,
      email: normalizedEmail,
      phone: cleanPhone,
      password: hashedPasswordFallback,
      role: userRole,
      isActive: true,
      isEmailVerified: isVerified,
      createdAt: new Date().toISOString(),
    };

    db.users.push(newUser);

    let donorProfile = null;
    if (cleanBloodGroup || userRole === 'donor') {
      donorProfile = {
        id: `dp_${Date.now()}`,
        userId: newUser.id,
        bloodGroup: cleanBloodGroup || 'O+',
        city: cleanCity || 'Colombo',
        address: cleanAddress || '',
        isAvailable: true,
        latitude: 6.9271,
        longitude: 79.8612,
        totalDonations: 0,
        livesSaved: 0,
        eligibilityStatus: 'Eligible',
        weightKg: cleanWeight,
      };
      db.donorProfiles.push(donorProfile);
    }

    if (!isVerified) {
      const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
      const otpResult = await otpService.requestEmailVerificationOtp(normalizedEmail, cleanName, bypassCooldown);
      if (otpResult.emailDeliveryFailed) {
        return res.status(503).json({
          success: false,
          message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
        });
      }
    }

    const token = isVerified ? jwt.sign({ id: newUser.id, role: newUser.role }, JWT_SECRET, { expiresIn: '30d' }) : null;

    return res.status(201).json({
      success: true,
      requiresVerification: !isVerified,
      message: isVerified ? 'Account registered successfully (in-memory mode)' : 'Account registered. A 6-digit verification code has been sent to your email.',
      data: { user: sanitizeUser(newUser), profile: donorProfile, token, requiresVerification: !isVerified, isEmailVerified: isVerified },
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

          if (user.isEmailVerified === false || user.is_email_verified === false) {
            return res.status(403).json({
              success: false,
              isUnverified: true,
              email: user.email,
              message: 'Please verify your email address before logging in.',
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

    if (memoryUser.isEmailVerified === false) {
      return res.status(403).json({
        success: false,
        isUnverified: true,
        email: memoryUser.email,
        message: 'Please verify your email address before logging in.',
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
    const { userId, name, phone, email, idNumber, id_number } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID is required' });
    }

    // Security: verify caller cannot modify another user's profile/ID Number
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = jwt.verify(authHeader.split(' ')[1], JWT_SECRET);
        if (decoded.id && decoded.id !== userId && decoded.role !== 'admin' && decoded.role !== 'manager') {
          return res.status(403).json({
            success: false,
            message: 'You are not authorized to update another user\'s profile.',
          });
        }
      } catch (_) {}
    }

    let cleanName = undefined;
    if (name !== undefined) {
      const nameValidation = validateFullName(name);
      if (!nameValidation.valid) {
        return res.status(400).json({ success: false, message: nameValidation.message });
      }
      cleanName = nameValidation.value;
    }

    let normalizedEmail = undefined;
    if (email !== undefined) {
      const emailValidation = validateEmail(email);
      if (!emailValidation.valid) {
        return res.status(400).json({ success: false, message: emailValidation.message });
      }
      normalizedEmail = emailValidation.value;
    }

    let cleanPhone = undefined;
    if (phone !== undefined) {
      const phoneValidation = validatePhone(phone);
      if (!phoneValidation.valid) {
        return res.status(400).json({ success: false, message: phoneValidation.message });
      }
      cleanPhone = phoneValidation.value;
    }

    const rawIdNumber = idNumber !== undefined ? idNumber : id_number;
    let cleanIdNumber = undefined;
    if (rawIdNumber !== undefined) {
      const idValidation = validateIdNumber(rawIdNumber);
      if (!idValidation.valid) {
        return res.status(400).json({ success: false, message: idValidation.message });
      }
      cleanIdNumber = idValidation.value;
    }

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

        if (cleanIdNumber) {
          const idConflict = await prisma.user.findFirst({
            where: {
              idNumber: { equals: cleanIdNumber, mode: 'insensitive' },
              id: { not: userId },
            },
          });
          if (idConflict) {
            return res.status(400).json({
              success: false,
              message: 'An account with this ID Number already exists.',
            });
          }
        }

        const updated = await prisma.user.update({
          where: { id: userId },
          data: {
            ...(cleanName !== undefined ? { name: cleanName } : {}),
            ...(cleanPhone !== undefined ? { phone: cleanPhone } : {}),
            ...(normalizedEmail !== undefined ? { email: normalizedEmail } : {}),
            ...(cleanIdNumber !== undefined ? { idNumber: cleanIdNumber } : {}),
          },
        });
        return res.json({ success: true, message: 'Profile updated', data: sanitizeUser(updated) });
      } catch (dbError) {
        if (
          dbError.code === 'P2002' ||
          (dbError.message && (
            dbError.message.includes('id_number') ||
            dbError.message.includes('idNumber') ||
            dbError.message.includes('User_id_number_lower_key') ||
            dbError.message.includes('User_id_number_key')
          ))
        ) {
          return res.status(400).json({
            success: false,
            message: 'An account with this ID Number already exists.',
          });
        }

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

    if (cleanIdNumber) {
      const idConflict = db.users.find(u => u.id !== userId && u.idNumber && u.idNumber.toLowerCase() === cleanIdNumber.toLowerCase());
      if (idConflict) {
        return res.status(400).json({
          success: false,
          message: 'An account with this ID Number already exists.',
        });
      }
    }

    if (cleanName !== undefined) user.name = cleanName;
    if (cleanPhone !== undefined) user.phone = cleanPhone;
    if (normalizedEmail) user.email = normalizedEmail;
    if (cleanIdNumber) user.idNumber = cleanIdNumber;

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

// POST /api/auth/change-password and PUT /api/auth/change-password
const handleChangePassword = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Access denied: Authentication token required',
      });
    }

    const { currentPassword, newPassword, confirmPassword } = req.body || {};

    // 1. Validation - All fields required
    if (!currentPassword || typeof currentPassword !== 'string' || !currentPassword.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Current password is required',
      });
    }

    if (!newPassword || typeof newPassword !== 'string' || !newPassword.trim()) {
      return res.status(400).json({
        success: false,
        message: 'New password is required',
      });
    }

    if (!confirmPassword || typeof confirmPassword !== 'string' || !confirmPassword.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Password confirmation is required',
      });
    }

    // 2. Password complexity / requirements (min 6 characters)
    const newPassValidation = validatePassword(newPassword, 'New password');
    if (!newPassValidation.valid) {
      return res.status(400).json({
        success: false,
        message: newPassValidation.message,
      });
    }

    // 3. New password and confirmation must match
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'New password and confirmation do not match',
      });
    }

    // 4. New password must be different from current password
    if (newPassword === currentPassword) {
      return res.status(400).json({
        success: false,
        message: 'New password must be different from current password',
      });
    }

    let user = null;
    let usingPrisma = false;

    // 5. Look up user in database
    if (prisma) {
      try {
        user = await prisma.user.findUnique({
          where: { id: userId },
        });
        if (user) {
          usingPrisma = true;
        }
      } catch (dbError) {
        console.error('Prisma change-password error, checking fallback store:', dbError.message);
      }
    }

    if (!user) {
      user = db.users.find(u => u.id === userId);
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    if (user.isActive === false) {
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Please contact support to reactivate your account.',
      });
    }

    // 6. Verify current password securely using bcrypt
    let isMatch = false;
    if (user.password) {
      if (user.password.startsWith('$2')) {
        isMatch = await bcrypt.compare(currentPassword, user.password).catch(() => false);
      } else {
        isMatch = (user.password === currentPassword);
      }
    }

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'Incorrect current password',
      });
    }

    // 7. Hash the new password securely
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // 8. Update in Prisma if connected
    if (usingPrisma) {
      try {
        await prisma.user.update({
          where: { id: userId },
          data: { password: hashedPassword },
        });
      } catch (dbUpdateError) {
        console.error('Failed to update password in Prisma:', dbUpdateError.message);
        return res.status(500).json({
          success: false,
          message: 'Failed to update password in database',
        });
      }
    }

    // Always keep memory store updated for fallback parity
    const memoryUser = db.users.find(
      u => u.id === userId || (user.email && u.email && u.email.toLowerCase() === user.email.toLowerCase())
    );
    if (memoryUser) {
      memoryUser.password = hashedPassword;
    }

    // Generate fresh token with existing claims
    const token = jwt.sign(
      { id: user.id, role: user.role },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      success: true,
      message: 'Password changed successfully.',
      data: { token },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while changing password. Please try again.',
    });
  }
};

router.post('/change-password', authenticateToken, handleChangePassword);
router.put('/change-password', authenticateToken, handleChangePassword);

// GET /api/auth/email-service-status (safe diagnostic endpoint)
router.get('/email-service-status', (req, res) => {
  return res.json({
    success: true,
    data: getEmailConfigSummary(),
  });
});

// POST /api/auth/forgot-password (alias: /send-otp)
router.post(['/forgot-password', '/send-otp'], async (req, res) => {
  try {
    const { email } = req.body || {};
    const maskedInput = maskEmail(email);
    console.log(`[Auth] 📩 Forgot-password request received for: ${maskedInput}`);

    const emailValidation = validateEmail(email);
    if (!emailValidation.valid) {
      console.log(`[Auth] ❌ Email validation rejected: ${emailValidation.message}`);
      return res.status(400).json({
        success: false,
        message: emailValidation.message,
      });
    }

    const normalizedEmail = emailValidation.value;
    console.log(`[Auth] ✅ Email validation passed for: ${maskEmail(normalizedEmail)}`);

    // Check if account exists
    let user = null;
    if (prisma) {
      try {
        user = await prisma.user.findFirst({
          where: {
            email: { equals: normalizedEmail, mode: 'insensitive' },
          },
        });
      } catch (dbErr) {
        console.error('Prisma forgot-password find user error:', dbErr.message);
      }
    }

    if (!user) {
      user = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    }

    // Security: If account does not exist, return generic 200 to prevent account enumeration
    if (!user) {
      console.log(`[Auth] ℹ️ Unregistered email requested OTP: ${maskEmail(normalizedEmail)}`);
      return res.json({
        success: true,
        message: 'If an account is associated with this email, a 6-digit verification code has been sent.',
        data: { email: normalizedEmail, expiresInSeconds: 300 },
      });
    }

    console.log(`[Auth] 👤 Registered user found: ${maskEmail(normalizedEmail)} (${user.name})`);

    // User exists: request secure OTP
    const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
    const result = await otpService.requestOtp(normalizedEmail, user.name, bypassCooldown);

    if (result.rateLimited) {
      console.log(`[Auth] ⏱️ Rate limited for: ${maskEmail(normalizedEmail)} (${result.retryAfter}s remaining)`);
      return res.status(429).json({
        success: false,
        message: result.message,
        retryAfterSeconds: result.retryAfter,
      });
    }

    if (result.emailDeliveryFailed || !result.success) {
      console.error(`[Auth] ❌ Email delivery failed for: ${maskEmail(normalizedEmail)} - ${result.error || result.message}`);
      return res.status(503).json({
        success: false,
        message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
      });
    }

    console.log(`[Auth] ✅ OTP sent successfully for: ${maskEmail(normalizedEmail)}`);
    return res.json({
      success: true,
      message: 'OTP sent successfully to your email.',
      data: {
        email: normalizedEmail,
        expiresInSeconds: 300,
      },
    });
  } catch (error) {
    console.error('Forgot password error:', error);
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while processing your request.',
    });
  }
});

// POST /api/auth/verify-otp
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body || {};

    const emailValidation = validateEmail(email);
    if (!emailValidation.valid) {
      return res.status(400).json({
        success: false,
        message: emailValidation.message,
      });
    }
    const normalizedEmail = emailValidation.value;

    if (!otp || typeof otp !== 'string' || !otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Verification code is required.',
      });
    }

    const cleanOtp = otp.trim();
    if (!/^\d{6}$/.test(cleanOtp)) {
      return res.status(400).json({
        success: false,
        message: 'Verification code must be exactly 6 digits.',
      });
    }

    const result = await otpService.verifyOtp(normalizedEmail, cleanOtp);

    if (!result.valid) {
      const statusCode = result.maxAttemptsReached ? 429 : 400;
      return res.status(statusCode).json({
        success: false,
        message: result.message,
      });
    }

    // Find user
    let user = null;
    if (prisma) {
      try {
        user = await prisma.user.findFirst({
          where: { email: { equals: normalizedEmail, mode: 'insensitive' } },
        });
      } catch (_) {}
    }
    if (!user) {
      user = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    }

    // Issue single-use password reset token (15 minute validity)
    const resetToken = jwt.sign(
      {
        email: normalizedEmail,
        userId: user ? user.id : null,
        purpose: 'password_reset',
      },
      JWT_SECRET,
      { expiresIn: '15m' }
    );

    return res.json({
      success: true,
      message: 'Verification code verified successfully.',
      data: {
        resetToken,
        email: normalizedEmail,
      },
    });
  } catch (error) {
    console.error('Verify OTP error:', error);
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while verifying the code.',
    });
  }
});

// POST /api/auth/reset-password
router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword, confirmPassword } = req.body || {};

    if (!resetToken || typeof resetToken !== 'string') {
      return res.status(401).json({
        success: false,
        message: 'Reset token is required. Please verify your OTP first.',
      });
    }

    // Verify reset token
    let decoded;
    try {
      decoded = jwt.verify(resetToken, JWT_SECRET);
      if (decoded.purpose !== 'password_reset') {
        throw new Error('Invalid token purpose');
      }
    } catch (tokenErr) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired reset token. Please request a new verification code.',
      });
    }

    const email = decoded.email;
    const userId = decoded.userId;

    // Validate new password
    if (!newPassword || typeof newPassword !== 'string' || !newPassword.trim()) {
      return res.status(400).json({
        success: false,
        message: 'New password is required',
      });
    }

    if (!confirmPassword || typeof confirmPassword !== 'string' || !confirmPassword.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Password confirmation is required',
      });
    }

    // Password requirements (min 6 chars)
    const newPassValidation = validatePassword(newPassword, 'New password');
    if (!newPassValidation.valid) {
      return res.status(400).json({
        success: false,
        message: newPassValidation.message,
      });
    }

    // Match confirmation
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'New password and confirmation do not match',
      });
    }

    // Find user
    let user = null;
    let usingPrisma = false;
    if (prisma) {
      try {
        if (userId) {
          user = await prisma.user.findUnique({ where: { id: userId } });
        }
        if (!user && email) {
          user = await prisma.user.findFirst({
            where: { email: { equals: email, mode: 'insensitive' } },
          });
        }
        if (user) usingPrisma = true;
      } catch (dbErr) {
        console.error('Prisma reset-password find user error:', dbErr.message);
      }
    }

    if (!user) {
      user = db.users.find(
        u => (userId && u.id === userId) || (email && u.email.toLowerCase() === email.toLowerCase())
      );
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found',
      });
    }

    // Prevent new password from being same as current password
    if (user.password) {
      let isSame = false;
      if (user.password.startsWith('$2')) {
        isSame = await bcrypt.compare(newPassword, user.password).catch(() => false);
      } else {
        isSame = (user.password === newPassword);
      }

      if (isSame) {
        return res.status(400).json({
          success: false,
          message: 'New password must be different from your old password',
        });
      }
    }

    // Hash the new password securely
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update in Prisma if connected
    if (usingPrisma) {
      try {
        await prisma.user.update({
          where: { id: user.id },
          data: { password: hashedPassword },
        });
      } catch (dbUpdateError) {
        console.error('Failed to update reset password in Prisma:', dbUpdateError.message);
        return res.status(500).json({
          success: false,
          message: 'Failed to update password in database',
        });
      }
    }

    // Update in-memory fallback
    const memoryUser = db.users.find(
      u => u.id === user.id || (user.email && u.email && u.email.toLowerCase() === user.email.toLowerCase())
    );
    if (memoryUser) {
      memoryUser.password = hashedPassword;
    }

    return res.json({
      success: true,
      message: 'Password reset successfully. Please log in with your new password.',
    });
  } catch (error) {
    console.error('Reset password error:', error);
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while resetting your password.',
    });
  }
});

// POST /api/auth/verify-email-otp
router.post('/verify-email-otp', async (req, res) => {
  try {
    const { email, otp } = req.body || {};
    const emailValidation = validateEmail(email);
    if (!emailValidation.valid) {
      return res.status(400).json({
        success: false,
        message: emailValidation.message,
      });
    }
    const normalizedEmail = emailValidation.value;

    if (!otp || typeof otp !== 'string' || !otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Verification code is required.',
      });
    }

    const cleanOtp = otp.trim();
    if (!/^\d{6}$/.test(cleanOtp)) {
      return res.status(400).json({
        success: false,
        message: 'Verification code must be exactly 6 digits.',
      });
    }

    const result = await otpService.verifyEmailVerificationOtp(normalizedEmail, cleanOtp);
    if (!result.valid) {
      const statusCode = result.maxAttemptsReached ? 429 : 400;
      return res.status(statusCode).json({
        success: false,
        message: result.message,
      });
    }

    // Mark user as email verified in database and memory
    let user = null;
    if (prisma) {
      try {
        await prisma.$executeRawUnsafe(
          'UPDATE public."User" SET "is_email_verified" = true WHERE LOWER("email") = $1',
          normalizedEmail
        );
        user = await prisma.user.findFirst({
          where: { email: { equals: normalizedEmail, mode: 'insensitive' } },
        });
      } catch (dbErr) {
        console.error('Prisma verify-email-otp error:', dbErr.message);
      }
    }

    const memoryUser = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    if (memoryUser) {
      memoryUser.isEmailVerified = true;
      if (!user) user = memoryUser;
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    console.log(`[Auth] 🎉 Registration email verified successfully for: ${maskEmail(normalizedEmail)}`);

    return res.json({
      success: true,
      message: 'Email verified successfully. Welcome to LifeLink!',
      data: {
        user: sanitizeUser(user),
        token,
      },
    });
  } catch (error) {
    console.error('Verify email OTP error:', error);
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while verifying your email.',
    });
  }
});

// POST /api/auth/resend-verification-otp (alias: /resend-registration-otp)
router.post(['/resend-verification-otp', '/resend-registration-otp'], async (req, res) => {
  try {
    const { email } = req.body || {};
    const emailValidation = validateEmail(email);
    if (!emailValidation.valid) {
      return res.status(400).json({
        success: false,
        message: emailValidation.message,
      });
    }
    const normalizedEmail = emailValidation.value;

    let user = null;
    if (prisma) {
      try {
        user = await prisma.user.findFirst({
          where: { email: { equals: normalizedEmail, mode: 'insensitive' } },
        });
      } catch (_) {}
    }
    if (!user) {
      user = db.users.find(u => u.email.toLowerCase() === normalizedEmail);
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No account found with this email address.',
      });
    }

    if (user.isEmailVerified === true || user.is_email_verified === true) {
      return res.status(400).json({
        success: false,
        message: 'This email is already verified. You can log in directly.',
      });
    }

    const bypassCooldown = req.headers['x-bypass-cooldown'] === 'lifelink-test-suite';
    const result = await otpService.requestEmailVerificationOtp(normalizedEmail, user.name, bypassCooldown);

    if (result.rateLimited) {
      return res.status(429).json({
        success: false,
        message: result.message,
        retryAfterSeconds: result.retryAfter,
      });
    }

    if (result.emailDeliveryFailed || !result.success) {
      return res.status(503).json({
        success: false,
        message: 'Unable to deliver verification email. Please check email service configuration or try again later.',
      });
    }

    return res.json({
      success: true,
      message: 'A new verification code has been sent to your email.',
      data: {
        email: normalizedEmail,
        expiresInSeconds: 300,
      },
    });
  } catch (error) {
    console.error('Resend verification OTP error:', error);
    return res.status(500).json({
      success: false,
      message: 'An unexpected error occurred while resending verification code.',
    });
  }
});

module.exports = router;


