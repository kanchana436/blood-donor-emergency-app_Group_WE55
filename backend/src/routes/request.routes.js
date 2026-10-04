const express = require('express');
const router = express.Router();
const { prisma, db } = require('../prisma');
const { findSuitableDonors } = require('../utils/matching');

function formatRequest(req) {
  if (!req) return null;
  const responses = req.responses || [];
  const acceptedResponses = responses.filter(r => r.status && r.status.toLowerCase() === 'accepted');

  return {
    ...req,
    matchedDonorsCount: req.matchedDonorsCount !== undefined ? req.matchedDonorsCount : responses.length,
    acceptedDonorsCount: req.acceptedDonorsCount !== undefined ? req.acceptedDonorsCount : acceptedResponses.length,
    matchedDonors: req.matchedDonors || responses,
  };
}

// GET /api/requests/me
router.get('/me', async (req, res) => {
  try {
    const { userId } = req.query;

    if (prisma) {
      try {
        const whereClause = userId ? { requesterId: userId } : {};
        const requests = await prisma.bloodRequest.findMany({
          where: whereClause,
          include: { responses: true },
          orderBy: { createdAt: 'desc' },
        });

        if (requests.length > 0 || userId) {
          return res.json({ success: true, data: requests.map(formatRequest) });
        }
      } catch (dbError) {
        console.error('Prisma GET /me error:', dbError.message);
      }
    }

    return res.json({ success: true, data: db.bloodRequests });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/requests
router.get('/', async (req, res) => {
  try {
    const { bloodGroup, urgency, status } = req.query;

    if (prisma) {
      try {
        const where = {};
        if (bloodGroup) where.bloodGroup = bloodGroup;
        if (urgency && urgency !== 'All') {
          where.urgency = { equals: urgency, mode: 'insensitive' };
        }
        if (status && status !== 'All') {
          where.status = { equals: status, mode: 'insensitive' };
        }

        const requests = await prisma.bloodRequest.findMany({
          where,
          include: { responses: true },
          orderBy: { createdAt: 'desc' },
        });

        return res.json({ success: true, data: requests.map(formatRequest) });
      } catch (dbError) {
        console.error('Prisma GET /requests error:', dbError.message);
      }
    }

    // In-memory fallback
    let results = [...db.bloodRequests];
    if (bloodGroup) {
      results = results.filter(r => r.bloodGroup === bloodGroup);
    }
    if (urgency && urgency !== 'All') {
      results = results.filter(r => r.urgency.toLowerCase() === urgency.toLowerCase());
    }
    if (status && status !== 'All') {
      results = results.filter(r => r.status.toLowerCase() === status.toLowerCase());
    }

    return res.json({ success: true, data: results });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/requests/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        const request = await prisma.bloodRequest.findUnique({
          where: { id },
          include: { responses: true },
        });

        if (request) {
          return res.json({ success: true, data: formatRequest(request) });
        }
      } catch (dbError) {
        console.error('Prisma GET /requests/:id error:', dbError.message);
      }
    }

    const item = db.bloodRequests.find(r => r.id === id);
    if (!item) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }
    return res.json({ success: true, data: item });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/requests/:id/matching-donors
router.get('/:id/matching-donors', async (req, res) => {
  try {
    const { id } = req.params;
    let request = null;

    if (prisma) {
      try {
        request = await prisma.bloodRequest.findUnique({
          where: { id },
          include: { responses: true },
        });
      } catch (_) {}
    }

    if (!request) {
      request = db.bloodRequests.find(r => r.id === id);
    }

    if (!request) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }

    if (request.matchedDonors && request.matchedDonors.length > 0) {
      return res.json({ success: true, data: request.matchedDonors });
    }

    // Run matching algorithm against candidates
    let availableCandidates = [];
    if (prisma) {
      try {
        const profiles = await prisma.donorProfile.findMany({
          include: { user: true },
        });
        availableCandidates = profiles.map(p => ({
          ...p,
          userName: p.user ? p.user.name : 'Donor',
          userPhone: p.user ? p.user.phone : '',
        }));
      } catch (_) {}
    }

    if (availableCandidates.length === 0) {
      availableCandidates = db.donorProfiles.map(p => {
        const user = db.users.find(u => u.id === p.userId) || {};
        return {
          ...p,
          userName: user.name,
          userPhone: user.phone,
        };
      });
    }

    const matched = findSuitableDonors(request, availableCandidates);
    return res.json({ success: true, data: matched });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/requests
router.post('/', async (req, res) => {
  try {
    const {
      requesterId,
      requesterName,
      patientName,
      bloodGroup,
      unitsRequired,
      urgency,
      hospitalName,
      hospitalAddress,
      contactPhone,
      additionalNotes,
      latitude,
      longitude,
    } = req.body;

    if (prisma) {
      try {
        // Resolve valid requester ID for foreign key constraint
        let validRequesterId = requesterId;

        if (validRequesterId) {
          const userExists = await prisma.user.findUnique({ where: { id: validRequesterId } });
          if (!userExists) {
            validRequesterId = null;
          }
        }

        if (!validRequesterId) {
          // Find first recipient or any existing user
          const existingUser = await prisma.user.findFirst();
          if (existingUser) {
            validRequesterId = existingUser.id;
          } else {
            // Auto-create a recipient user
            const newUser = await prisma.user.create({
              data: {
                name: requesterName || 'Default Requester',
                email: `requester_${Date.now()}@lifelink.org`,
                phone: contactPhone || '+94 71 987 6543',
                password: 'lifelink_default_hash',
                role: 'recipient',
              },
            });
            validRequesterId = newUser.id;
          }
        }

        const createdRequest = await prisma.bloodRequest.create({
          data: {
            requesterId: validRequesterId,
            requesterName: requesterName || 'Sarah Perera',
            patientName: patientName || 'Emergency Patient',
            bloodGroup: bloodGroup || 'O+',
            unitsRequired: parseInt(unitsRequired) || 1,
            urgency: urgency || 'Emergency',
            hospitalName: hospitalName || 'National Hospital of Sri Lanka',
            hospitalAddress: hospitalAddress || 'Colombo 10',
            contactPhone: contactPhone || '+94 71 987 6543',
            additionalNotes: additionalNotes || '',
            latitude: latitude !== undefined ? parseFloat(latitude) : 6.9271,
            longitude: longitude !== undefined ? parseFloat(longitude) : 79.8612,
            status: 'Open',
          },
          include: {
            responses: true,
          },
        });

        // Mirror in in-memory for fallback
        const formatted = formatRequest(createdRequest);
        db.bloodRequests.unshift(formatted);

        return res.status(201).json({
          success: true,
          message: 'Blood request dispatched successfully',
          data: formatted,
        });
      } catch (dbError) {
        console.error('Prisma POST /requests error, falling back to memory:', dbError.message);
      }
    }

    // In-memory fallback
    const newRequest = {
      id: `req_${Date.now()}`,
      requesterId: requesterId || 'usr_recip_202',
      requesterName: requesterName || 'Sarah Perera',
      patientName: patientName || 'Emergency Patient',
      bloodGroup: bloodGroup || 'O+',
      unitsRequired: parseInt(unitsRequired) || 1,
      urgency: urgency || 'Emergency',
      hospitalName: hospitalName || 'National Hospital of Sri Lanka',
      hospitalAddress: hospitalAddress || 'Colombo 10',
      contactPhone: contactPhone || '+94 71 987 6543',
      additionalNotes: additionalNotes || '',
      latitude: latitude !== undefined ? parseFloat(latitude) : 6.9271,
      longitude: longitude !== undefined ? parseFloat(longitude) : 79.8612,
      status: 'Open',
      createdAt: new Date().toISOString(),
      matchedDonorsCount: 0,
      acceptedDonorsCount: 0,
      matchedDonors: [],
    };

    db.bloodRequests.unshift(newRequest);

    return res.status(201).json({
      success: true,
      message: 'Blood request dispatched successfully (in-memory mode)',
      data: newRequest,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/requests/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { unitsRequired, urgency, hospitalName, hospitalAddress, additionalNotes, status } = req.body;

    if (prisma) {
      try {
        const updateData = {};
        if (unitsRequired !== undefined) updateData.unitsRequired = parseInt(unitsRequired);
        if (urgency) updateData.urgency = urgency;
        if (hospitalName) updateData.hospitalName = hospitalName;
        if (hospitalAddress) updateData.hospitalAddress = hospitalAddress;
        if (additionalNotes !== undefined) updateData.additionalNotes = additionalNotes;
        if (status) updateData.status = status;

        const updated = await prisma.bloodRequest.update({
          where: { id },
          data: updateData,
          include: { responses: true },
        });

        return res.json({ success: true, message: 'Request updated', data: formatRequest(updated) });
      } catch (dbError) {
        console.error('Prisma PUT /requests/:id error:', dbError.message);
      }
    }

    const request = db.bloodRequests.find(r => r.id === id);
    if (!request) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }

    if (unitsRequired) request.unitsRequired = parseInt(unitsRequired);
    if (urgency) request.urgency = urgency;
    if (hospitalName) request.hospitalName = hospitalName;
    if (hospitalAddress) request.hospitalAddress = hospitalAddress;
    if (additionalNotes !== undefined) request.additionalNotes = additionalNotes;
    if (status) request.status = status;

    return res.json({ success: true, message: 'Request updated', data: request });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/requests/:id/cancel
router.post('/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        await prisma.bloodRequest.update({
          where: { id },
          data: { status: 'Cancelled' },
        });
        return res.json({ success: true, message: 'Request cancelled' });
      } catch (dbError) {
        console.error('Prisma cancel error:', dbError.message);
      }
    }

    const request = db.bloodRequests.find(r => r.id === id);
    if (request) {
      request.status = 'Cancelled';
    }
    return res.json({ success: true, message: 'Request cancelled' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/requests/:id/fulfill
router.post('/:id/fulfill', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        await prisma.bloodRequest.update({
          where: { id },
          data: { status: 'Fulfilled' },
        });
        return res.json({ success: true, message: 'Request fulfilled' });
      } catch (dbError) {
        console.error('Prisma fulfill error:', dbError.message);
      }
    }

    const request = db.bloodRequests.find(r => r.id === id);
    if (request) {
      request.status = 'Fulfilled';
    }
    return res.json({ success: true, message: 'Request fulfilled' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
