const { authenticateToken } = require('../middleware/auth.middleware');
const { verificationProfile } = require('../middleware/verification-profile.middleware');
const express = require('express');
const router = express.Router();
const { prisma, db } = require('../prisma');
const { isCompatible } = require('../utils/matching');
const {
  validateBloodGroup,
  validateCity,
  validateLivingAddress,
  validateBodyWeight,
} = require('../utils/validation');

// Helper function to search and filter donors by city, blood group, availability
const handleSearchDonors = async (req, res) => {
  try {
    const { city, bloodGroup, isAvailable } = req.query;

    // Validate and sanitize search inputs:
    // Strip control characters, trim leading/trailing spaces
    let cleanCity = '';
    if (city !== undefined && city !== null) {
      cleanCity = city.toString().replace(/[\x00-\x1F\x7F]/g, '').trim();
    }

    // Sanitize blood group
    let cleanBloodGroup = '';
    if (bloodGroup !== undefined && bloodGroup !== null && typeof bloodGroup === 'string') {
      const trimmedBg = bloodGroup.trim().toUpperCase();
      if (['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].includes(trimmedBg)) {
        cleanBloodGroup = trimmedBg;
      }
    }

    // Availability filter:
    // "Do not display deactivated or unavailable donors."
    // Default to true. Allow filtering if explicitly passed.
    let targetAvailable = true;
    if (isAvailable !== undefined && isAvailable !== null) {
      const availStr = isAvailable.toString().trim().toLowerCase();
      if (availStr === 'false' || availStr === 'unavailable') {
        targetAvailable = false;
      } else if (availStr === 'all') {
        targetAvailable = undefined;
      } else {
        targetAvailable = true;
      }
    }

    if (prisma) {
      try {
        const where = {
          // Requirement: Never display deactivated donors
          user: {
            isActive: true,
          },
        };

        // Requirement: Do not display unavailable donors unless requested
        if (targetAvailable !== undefined) {
          where.isAvailable = targetAvailable;
        }

        // Blood group filter
        if (cleanBloodGroup) {
          where.bloodGroup = cleanBloodGroup;
        }

        // Location / City filter: case-insensitive, ignores leading/trailing spaces
        if (cleanCity) {
          where.city = {
            contains: cleanCity,
            mode: 'insensitive',
          };
        }

        const profiles = await prisma.donorProfile.findMany({
          where,
          include: {
            user: {
              select: {
                id: true,
                name: true,
                email: true,
                phone: true,
                role: true,
                isActive: true,
                donorAvailabilities: {
                  where: { isActive: true },
                  orderBy: { availableFrom: 'desc' },
                },
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        });

        const now = new Date();
        // Safe mapping with dynamic availability computation
        const formatted = profiles
          .map(p => {
            const availabilities = p.user?.donorAvailabilities || [];
            let effectiveAvailable;

            if (availabilities.length > 0) {
              const currentRecord = availabilities.find(a => {
                const from = new Date(a.availableFrom);
                const until = a.availableUntil ? new Date(a.availableUntil) : null;
                return from <= now && (!until || until >= now);
              });
              if (currentRecord) {
                effectiveAvailable = currentRecord.status === 'Available';
              } else {
                // If all active schedules expired or none valid right now
                effectiveAvailable = false;
              }
            } else {
              effectiveAvailable = p.isAvailable ?? true;
            }

            return {
              id: p.id,
              userId: p.userId,
              name: p.user?.name || 'LifeLink Donor',
              phone: p.user?.phone || '+94 77 123 4567',
              email: p.user?.email || '',
              bloodGroup: p.bloodGroup || 'O+',
              isAvailable: effectiveAvailable,
              city: p.city || 'Unspecified',
              address: p.address || '',
              latitude: p.latitude ?? 6.9271,
              longitude: p.longitude ?? 79.8612,
              lastDonationDate: p.lastDonationDate,
              totalDonations: p.totalDonations ?? 0,
              livesSaved: p.livesSaved ?? 0,
              eligibilityStatus: p.eligibilityStatus || 'Eligible',
              weightKg: p.weightKg,
              medicalConditions: p.medicalConditions,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              user: p.user,
            };
          })
          .filter(p => {
            if (targetAvailable !== undefined && p.isAvailable !== targetAvailable) {
              return false;
            }
            return true;
          });

        return res.json({
          success: true,
          count: formatted.length,
          data: formatted,
        });
      } catch (dbError) {
        console.error('Prisma search donors error:', dbError.message);
      }
    }

    // In-memory fallback
    const now = new Date();
    const filtered = db.donorProfiles.filter(p => {
      const user = db.users.find(u => u.id === p.userId);
      // Exclude deactivated
      if (!user || user.isActive === false) return false;

      const availabilities = (db.donorAvailabilities || []).filter(
        a => a.donorId === p.userId && a.isActive
      );
      let effectiveAvailable;
      if (availabilities.length > 0) {
        const currentRecord = availabilities.find(a => {
          const from = new Date(a.availableFrom);
          const until = a.availableUntil ? new Date(a.availableUntil) : null;
          return from <= now && (!until || until >= now);
        });
        effectiveAvailable = currentRecord ? currentRecord.status === 'Available' : false;
      } else {
        effectiveAvailable = p.isAvailable ?? true;
      }

      // Exclude unavailable (if filtering for available)
      if (targetAvailable !== undefined && effectiveAvailable !== targetAvailable) return false;

      // Filter by blood group
      if (cleanBloodGroup && p.bloodGroup.toUpperCase() !== cleanBloodGroup) return false;

      // Filter by city (case-insensitive substring, handles null/empty safely)
      if (cleanCity) {
        if (!p.city || typeof p.city !== 'string') return false;
        if (!p.city.toLowerCase().includes(cleanCity.toLowerCase())) return false;
      }

      return true;
    });

    const fallbackFormatted = filtered.map(p => {
      const user = db.users.find(u => u.id === p.userId);
      return {
        id: p.id,
        userId: p.userId,
        name: user?.name || 'LifeLink Donor',
        phone: user?.phone || '+94 77 123 4567',
        email: user?.email || '',
        bloodGroup: p.bloodGroup || 'O+',
        isAvailable: p.isAvailable ?? true,
        city: p.city || 'Unspecified',
        address: p.address || '',
        latitude: p.latitude ?? 6.9271,
        longitude: p.longitude ?? 79.8612,
        lastDonationDate: p.lastDonationDate,
        totalDonations: p.totalDonations ?? 0,
        livesSaved: p.livesSaved ?? 0,
        eligibilityStatus: p.eligibilityStatus || 'Eligible',
        weightKg: p.weightKg,
        medicalConditions: p.medicalConditions,
        createdAt: p.createdAt || new Date().toISOString(),
        user: user || null,
      };
    });

    return res.json({
      success: true,
      count: fallbackFormatted.length,
      data: fallbackFormatted,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/donors - Search / filter donors by location, blood group, availability
router.get('/', handleSearchDonors);
router.get('/search', handleSearchDonors);

// POST /api/donors/profile
router.post('/profile', authenticateToken, verificationProfile(true), async (req, res) => {
  try {
    const { userId, bloodGroup, city, address, isAvailable, latitude, longitude, weightKg } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID is required' });
    }

    const bloodValidation = validateBloodGroup(bloodGroup);
    if (!bloodValidation.valid) {
      return res.status(400).json({ success: false, message: bloodValidation.message });
    }
    const cleanBloodGroup = bloodValidation.value;

    const cityValidation = validateCity(city);
    if (!cityValidation.valid) {
      return res.status(400).json({ success: false, message: cityValidation.message });
    }
    const cleanCity = cityValidation.value;

    const addressValidation = validateLivingAddress(address);
    if (!addressValidation.valid) {
      return res.status(400).json({ success: false, message: addressValidation.message });
    }
    const cleanAddress = addressValidation.value;

    const weightValidation = validateBodyWeight(weightKg);
    if (!weightValidation.valid) {
      return res.status(400).json({ success: false, message: weightValidation.message });
    }
    const cleanWeight = weightValidation.value;

    const boolAvailable = isAvailable !== undefined ? (isAvailable === true || isAvailable === 'true') : true;

    if (prisma && userId) {
      try {
        let userExists = await prisma.user.findUnique({ where: { id: userId } });
        if (!userExists) {
          // Create dummy user record in Supabase so foreign key constraints pass
          userExists = await prisma.user.create({
            data: {
              id: userId,
              idNumber: `ID-${userId.replace(/[^a-zA-Z0-9]/g, '').substring(0, 10).toUpperCase() || Date.now()}`,
              name: 'LifeLink Donor',
              email: `${userId.replace(/[^a-zA-Z0-9]/g, '')}@lifelink-app.org`,
              password: 'hashed_dummy_password',
              phone: '+94 77 123 4567',
              role: 'donor',
            },
          });
        }

        const profile = await prisma.donorProfile.upsert({
          where: { userId },
          update: {
            bloodGroup: cleanBloodGroup,
            city: cleanCity,
            address: cleanAddress,
            ...(isAvailable !== undefined ? { isAvailable: boolAvailable } : {}),
            ...(latitude !== undefined && !isNaN(parseFloat(latitude)) ? { latitude: parseFloat(latitude) } : {}),
            ...(longitude !== undefined && !isNaN(parseFloat(longitude)) ? { longitude: parseFloat(longitude) } : {}),
            weightKg: cleanWeight,
          },
          create: {
            userId,
            bloodGroup: cleanBloodGroup,
            city: cleanCity,
            address: cleanAddress,
            isAvailable: boolAvailable,
            latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
            longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
            weightKg: cleanWeight,
          },
        });
        return res.json({ success: true, data: profile });
      } catch (dbError) {
        console.error('Prisma upsert donor profile error:', dbError.message);
      }
    }

    // In-memory fallback
    let profile = db.donorProfiles.find(p => p.userId === userId);
    if (!profile) {
      profile = {
        id: `dp_${Date.now()}`,
        userId: userId || 'usr_donor_101',
        bloodGroup: cleanBloodGroup,
        city: cleanCity,
        address: cleanAddress,
        isAvailable: boolAvailable,
        latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
        longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
        totalDonations: 0,
        livesSaved: 0,
        eligibilityStatus: 'Eligible',
        weightKg: cleanWeight,
      };
      db.donorProfiles.push(profile);
    } else {
      profile.bloodGroup = cleanBloodGroup;
      profile.city = cleanCity;
      profile.address = cleanAddress;
      if (isAvailable !== undefined) profile.isAvailable = boolAvailable;
      profile.weightKg = cleanWeight;
    }

    return res.json({ success: true, data: profile });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/donors/profile
router.get('/profile', async (req, res) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId query parameter is required' });
    }

    if (prisma) {
      try {
        const profile = await prisma.donorProfile.findUnique({ where: { userId } });
        if (profile) {
          return res.json({ success: true, data: profile });
        }
        return res.status(404).json({ success: false, message: 'Profile not found' });
      } catch (dbError) {
        console.error('Prisma GET /profile error:', dbError.message);
      }
    }

    const profile = db.donorProfiles.find(p => p.userId === userId);
    if (profile) {
      return res.json({ success: true, data: profile });
    }
    return res.status(404).json({ success: false, message: 'Profile not found' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/donors/profile
router.put('/profile', authenticateToken, verificationProfile(true), async (req, res) => {
  try {
    const { userId, bloodGroup, city, address, isAvailable, latitude, longitude, weightKg } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID is required' });
    }

    let cleanBloodGroup;
    if (bloodGroup !== undefined) {
      const bVal = validateBloodGroup(bloodGroup);
      if (!bVal.valid) return res.status(400).json({ success: false, message: bVal.message });
      cleanBloodGroup = bVal.value;
    }

    let cleanCity;
    if (city !== undefined) {
      const cVal = validateCity(city);
      if (!cVal.valid) return res.status(400).json({ success: false, message: cVal.message });
      cleanCity = cVal.value;
    }

    let cleanAddress;
    if (address !== undefined) {
      const aVal = validateLivingAddress(address);
      if (!aVal.valid) return res.status(400).json({ success: false, message: aVal.message });
      cleanAddress = aVal.value;
    }

    let cleanWeight = null;
    if (weightKg !== undefined && weightKg !== null && weightKg !== '') {
      const wVal = validateBodyWeight(weightKg);
      if (!wVal.valid) return res.status(400).json({ success: false, message: wVal.message });
      cleanWeight = wVal.value;
    }

    const boolAvailable = isAvailable !== undefined ? (isAvailable === true || isAvailable === 'true') : undefined;

    if (prisma && userId) {
      try {
        let userExists = await prisma.user.findUnique({ where: { id: userId } });
        if (!userExists) {
          userExists = await prisma.user.create({
            data: {
              id: userId,
              idNumber: `ID-${userId.replace(/[^a-zA-Z0-9]/g, '').substring(0, 10).toUpperCase() || Date.now()}`,
              name: 'LifeLink Donor',
              email: `${userId.replace(/[^a-zA-Z0-9]/g, '')}@lifelink-app.org`,
              password: 'hashed_dummy_password',
              phone: '+94 77 123 4567',
              role: 'donor',
            },
          });
        }

        const updateData = {};
        if (cleanBloodGroup) updateData.bloodGroup = cleanBloodGroup;
        if (cleanCity) updateData.city = cleanCity;
        if (cleanAddress !== undefined) updateData.address = cleanAddress;
        if (boolAvailable !== undefined) updateData.isAvailable = boolAvailable;
        if (latitude !== undefined && !isNaN(parseFloat(latitude))) updateData.latitude = parseFloat(latitude);
        if (longitude !== undefined && !isNaN(parseFloat(longitude))) updateData.longitude = parseFloat(longitude);
        if (cleanWeight !== null) updateData.weightKg = cleanWeight;

        const updated = await prisma.donorProfile.upsert({
          where: { userId },
          update: updateData,
          create: {
            userId,
            bloodGroup: cleanBloodGroup || 'O+',
            city: cleanCity || 'Colombo',
            address: cleanAddress || '',
            isAvailable: boolAvailable !== undefined ? boolAvailable : true,
            latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
            longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
            weightKg: cleanWeight,
          },
        });
        return res.json({ success: true, data: updated });
      } catch (dbError) {
        console.error('Prisma update donor profile error:', dbError.message);
      }
    }

    let profile = db.donorProfiles.find(p => p.userId === userId) || db.donorProfiles[0];
    if (profile) {
      if (cleanBloodGroup) profile.bloodGroup = cleanBloodGroup;
      if (cleanCity) profile.city = cleanCity;
      if (cleanAddress !== undefined) profile.address = cleanAddress;
      if (boolAvailable !== undefined) profile.isAvailable = boolAvailable;
      if (latitude && !isNaN(parseFloat(latitude))) profile.latitude = parseFloat(latitude);
      if (longitude && !isNaN(parseFloat(longitude))) profile.longitude = parseFloat(longitude);
      if (cleanWeight !== null) profile.weightKg = cleanWeight;

      return res.json({ success: true, data: profile });
    }

    return res.status(404).json({ success: false, message: 'Profile not found' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/donors/requests/compatible
router.get('/requests/compatible', async (req, res) => {
  try {
    let donorGroup = 'O+';

    if (prisma) {
      try {
        const firstProfile = await prisma.donorProfile.findFirst();
        if (firstProfile) donorGroup = firstProfile.bloodGroup;

        const requests = await prisma.bloodRequest.findMany({
          where: { status: { not: 'Cancelled' } },
        });

        const compatible = requests.filter(reqItem => isCompatible(donorGroup, reqItem.bloodGroup));
        return res.json({ success: true, data: compatible });
      } catch (dbError) {
        console.error('Prisma compatible requests error:', dbError.message);
      }
    }

    const profile = db.donorProfiles[0];
    donorGroup = profile ? profile.bloodGroup : 'O+';
    const compatible = db.bloodRequests.filter(reqItem => {
      if (reqItem.status && reqItem.status.toLowerCase() === 'cancelled') return false;
      return isCompatible(donorGroup, reqItem.bloodGroup);
    });

    return res.json({ success: true, data: compatible });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/donors/responses
router.get('/responses', async (req, res) => {
  try {
    if (prisma) {
      try {
        const responses = await prisma.donorResponse.findMany({
          orderBy: { respondedAt: 'desc' },
        });
        return res.json({ success: true, data: responses });
      } catch (dbError) {
        console.error('Prisma responses error:', dbError.message);
      }
    }

    const responses = [];
    for (const r of db.bloodRequests) {
      if (r.matchedDonors) {
        responses.push(...r.matchedDonors);
      }
    }
    return res.json({ success: true, data: responses });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/donors/requests/respond
router.post('/requests/respond', async (req, res) => {
  try {
    const { requestId, donorId, status, note } = req.body;

    if (prisma && requestId && donorId) {
      try {
        const donorUser = await prisma.user.findUnique({
          where: { id: donorId },
          include: { donorProfile: true },
        });

        const donorName = donorUser ? donorUser.name : 'LifeLink Donor';
        const donorPhone = donorUser ? donorUser.phone : '+94 77 123 4567';
        const donorBloodGroup = donorUser && donorUser.donorProfile ? donorUser.donorProfile.bloodGroup : 'O+';

        const createdResponse = await prisma.donorResponse.create({
          data: {
            requestId,
            donorId,
            donorName,
            donorPhone,
            donorBloodGroup,
            status: status || 'Accepted',
            note: note || '',
          },
        });

        if (status && status.toLowerCase() === 'accepted') {
          await prisma.bloodRequest.update({
            where: { id: requestId },
            data: { status: 'InProgress' },
          });
        }

        return res.json({ success: true, data: createdResponse });
      } catch (dbError) {
        console.error('Prisma respond error:', dbError.message);
      }
    }

    // In-memory fallback
    const request = db.bloodRequests.find(r => r.id === requestId);
    if (!request) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }

    const responseObj = {
      id: `dr_${Date.now()}`,
      requestId,
      donorId,
      donorName: 'Alexander Silva',
      donorPhone: '+94 77 123 4567',
      donorBloodGroup: 'O+',
      status: status || 'Accepted',
      distanceKm: 2.1,
      note,
      respondedAt: new Date().toISOString(),
    };

    if (!request.matchedDonors) request.matchedDonors = [];
    const existingIdx = request.matchedDonors.findIndex(d => d.donorId === donorId);
    if (existingIdx !== -1) {
      request.matchedDonors[existingIdx] = responseObj;
    } else {
      request.matchedDonors.push(responseObj);
    }

    if (status && status.toLowerCase() === 'accepted') {
      request.status = 'InProgress';
      request.acceptedDonorsCount = (request.acceptedDonorsCount || 0) + 1;
    }

    return res.json({ success: true, data: responseObj });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
