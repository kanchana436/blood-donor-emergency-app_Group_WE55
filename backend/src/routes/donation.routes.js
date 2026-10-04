const express = require('express');
const router = express.Router();
const { prisma, db } = require('../prisma');

// GET /api/donations
router.get('/', async (req, res) => {
  try {
    const { donorId } = req.query;

    if (prisma) {
      try {
        const whereClause = donorId ? { donorId } : {};
        const records = await prisma.donationRecord.findMany({
          where: whereClause,
          orderBy: { donationDate: 'desc' },
          include: {
            donor: {
              select: { id: true, name: true, phone: true, email: true },
            },
          },
        });
        return res.json({ success: true, data: records });
      } catch (dbError) {
        console.error('Prisma GET /donations error:', dbError.message);
      }
    }

    const filtered = donorId
      ? db.donationRecords.filter(d => d.donorId === donorId)
      : db.donationRecords;
    return res.json({ success: true, data: filtered });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/donations/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        const record = await prisma.donationRecord.findUnique({
          where: { id },
          include: {
            donor: {
              select: { id: true, name: true, phone: true, email: true },
            },
          },
        });
        if (record) {
          return res.json({ success: true, data: record });
        }
      } catch (dbError) {
        console.error('Prisma GET /donations/:id error:', dbError.message);
      }
    }

    const record = db.donationRecords.find(d => d.id === id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Donation record not found' });
    }
    return res.json({ success: true, data: record });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/donations
router.post('/', async (req, res) => {
  try {
    const { donorId, requestId, hospitalName, patientName, bloodGroup, units } = req.body;

    if (!donorId) {
      return res.status(400).json({ success: false, message: 'Donor ID is required' });
    }

    const unitsCount = parseInt(units) || 1;

    if (prisma) {
      try {
        // Verify donor exists in Supabase
        let validDonorId = donorId;
        const donorUser = await prisma.user.findUnique({ where: { id: donorId } });
        if (!donorUser) {
          const firstDonor = await prisma.user.findFirst({ where: { role: 'donor' } }) || await prisma.user.findFirst();
          if (firstDonor) {
            validDonorId = firstDonor.id;
          }
        }

        const newRecord = await prisma.donationRecord.create({
          data: {
            donorId: validDonorId,
            requestId: requestId || `req_ext_${Date.now()}`,
            hospitalName: hospitalName || 'National Hospital of Sri Lanka',
            patientName: patientName || 'Emergency Patient',
            bloodGroup: bloodGroup || 'O+',
            units: unitsCount,
            donationDate: new Date(),
            status: 'Completed',
          },
        });

        // Update DonorProfile counters if profile exists
        try {
          const profile = await prisma.donorProfile.findUnique({ where: { userId: validDonorId } });
          if (profile) {
            await prisma.donorProfile.update({
              where: { userId: validDonorId },
              data: {
                totalDonations: profile.totalDonations + 1,
                livesSaved: profile.livesSaved + (unitsCount * 3),
                lastDonationDate: new Date(),
              },
            });
          }
        } catch (_) {}

        // Create a Notification in Supabase for the donor
        try {
          await prisma.notification.create({
            data: {
              userId: validDonorId,
              title: 'Blood Donation Completed! 🩸',
              message: `Thank you for donating ${unitsCount} unit(s) of ${bloodGroup || 'blood'} at ${hospitalName || 'the hospital'}. You've helped save up to ${unitsCount * 3} lives!`,
              type: 'reminder',
              relatedRequestId: requestId,
            },
          });
        } catch (_) {}

        db.donationRecords.unshift(newRecord);
        return res.status(201).json({
          success: true,
          message: 'Donation record created successfully',
          data: newRecord,
        });
      } catch (dbError) {
        console.error('Prisma POST /donations error:', dbError.message);
      }
    }

    // In-memory fallback
    const fallbackRecord = {
      id: `don_${Date.now()}`,
      donorId,
      requestId: requestId || `req_${Date.now()}`,
      hospitalName: hospitalName || 'National Hospital of Sri Lanka',
      patientName: patientName || 'Emergency Patient',
      bloodGroup: bloodGroup || 'O+',
      units: unitsCount,
      donationDate: new Date().toISOString(),
      status: 'Completed',
    };

    db.donationRecords.unshift(fallbackRecord);
    return res.status(201).json({
      success: true,
      message: 'Donation record created successfully (in-memory mode)',
      data: fallbackRecord,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
