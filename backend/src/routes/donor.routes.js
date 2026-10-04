const express = require('express');
const router = express.Router();
const { prisma, db } = require('../prisma');
const { isCompatible } = require('../utils/matching');

// POST /api/donors/profile
router.post('/profile', async (req, res) => {
  try {
    const { userId, bloodGroup, city, address, isAvailable, latitude, longitude, weightKg } = req.body;

    const parsedWeight = (weightKg !== undefined && weightKg !== null && weightKg !== '' && !isNaN(parseFloat(weightKg)))
      ? parseFloat(weightKg)
      : null;

    const boolAvailable = isAvailable !== undefined ? (isAvailable === true || isAvailable === 'true') : true;

    if (prisma && userId) {
      try {
        let userExists = await prisma.user.findUnique({ where: { id: userId } });
        if (!userExists) {
          // Create dummy user record in Supabase so foreign key constraints pass
          userExists = await prisma.user.create({
            data: {
              id: userId,
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
            ...(bloodGroup ? { bloodGroup } : {}),
            ...(city ? { city } : {}),
            ...(address !== undefined ? { address } : {}),
            ...(isAvailable !== undefined ? { isAvailable: boolAvailable } : {}),
            ...(latitude !== undefined && !isNaN(parseFloat(latitude)) ? { latitude: parseFloat(latitude) } : {}),
            ...(longitude !== undefined && !isNaN(parseFloat(longitude)) ? { longitude: parseFloat(longitude) } : {}),
            ...(parsedWeight !== null ? { weightKg: parsedWeight } : {}),
          },
          create: {
            userId,
            bloodGroup: bloodGroup || 'O+',
            city: city || 'Colombo',
            address: address || '',
            isAvailable: boolAvailable,
            latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
            longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
            weightKg: parsedWeight,
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
        bloodGroup: bloodGroup || 'O+',
        city: city || 'Colombo',
        address: address || '',
        isAvailable: boolAvailable,
        latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
        longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
        totalDonations: 0,
        livesSaved: 0,
        eligibilityStatus: 'Eligible',
        weightKg: parsedWeight,
      };
      db.donorProfiles.push(profile);
    } else {
      if (bloodGroup) profile.bloodGroup = bloodGroup;
      if (city) profile.city = city;
      if (address) profile.address = address;
      if (isAvailable !== undefined) profile.isAvailable = boolAvailable;
      if (parsedWeight !== null) profile.weightKg = parsedWeight;
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
router.put('/profile', async (req, res) => {
  try {
    const { userId, bloodGroup, city, address, isAvailable, latitude, longitude, weightKg } = req.body;

    const parsedWeight = (weightKg !== undefined && weightKg !== null && weightKg !== '' && !isNaN(parseFloat(weightKg)))
      ? parseFloat(weightKg)
      : null;

    const boolAvailable = isAvailable !== undefined ? (isAvailable === true || isAvailable === 'true') : undefined;

    if (prisma && userId) {
      try {
        let userExists = await prisma.user.findUnique({ where: { id: userId } });
        if (!userExists) {
          userExists = await prisma.user.create({
            data: {
              id: userId,
              name: 'LifeLink Donor',
              email: `${userId.replace(/[^a-zA-Z0-9]/g, '')}@lifelink-app.org`,
              password: 'hashed_dummy_password',
              phone: '+94 77 123 4567',
              role: 'donor',
            },
          });
        }

        const updateData = {};
        if (bloodGroup) updateData.bloodGroup = bloodGroup;
        if (city) updateData.city = city;
        if (address !== undefined) updateData.address = address;
        if (boolAvailable !== undefined) updateData.isAvailable = boolAvailable;
        if (latitude !== undefined && !isNaN(parseFloat(latitude))) updateData.latitude = parseFloat(latitude);
        if (longitude !== undefined && !isNaN(parseFloat(longitude))) updateData.longitude = parseFloat(longitude);
        if (parsedWeight !== null) updateData.weightKg = parsedWeight;

        const updated = await prisma.donorProfile.upsert({
          where: { userId },
          update: updateData,
          create: {
            userId,
            bloodGroup: bloodGroup || 'O+',
            city: city || 'Colombo',
            address: address || '',
            isAvailable: boolAvailable !== undefined ? boolAvailable : true,
            latitude: latitude !== undefined && !isNaN(parseFloat(latitude)) ? parseFloat(latitude) : 6.9271,
            longitude: longitude !== undefined && !isNaN(parseFloat(longitude)) ? parseFloat(longitude) : 79.8612,
            weightKg: parsedWeight,
          },
        });
        return res.json({ success: true, data: updated });
      } catch (dbError) {
        console.error('Prisma update donor profile error:', dbError.message);
      }
    }

    let profile = db.donorProfiles.find(p => p.userId === userId) || db.donorProfiles[0];
    if (profile) {
      if (bloodGroup) profile.bloodGroup = bloodGroup;
      if (city) profile.city = city;
      if (address) profile.address = address;
      if (boolAvailable !== undefined) profile.isAvailable = boolAvailable;
      if (latitude && !isNaN(parseFloat(latitude))) profile.latitude = parseFloat(latitude);
      if (longitude && !isNaN(parseFloat(longitude))) profile.longitude = parseFloat(longitude);
      if (parsedWeight !== null) profile.weightKg = parsedWeight;

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
