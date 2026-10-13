const express = require('express');
const { randomUUID } = require('node:crypto');
const router = express.Router();
const { prisma, db } = require('../prisma');
const { authenticateToken } = require('../middleware/auth.middleware');

// Helper to determine if two date ranges overlap:
// [fromA, untilA] and [fromB, untilB]
// A range without until is treated as ongoing (Infinity)
function rangesOverlap(fromA, untilA, fromB, untilB) {
  const startA = new Date(fromA).getTime();
  const endA = untilA ? new Date(untilA).getTime() : Infinity;
  const startB = new Date(fromB).getTime();
  const endB = untilB ? new Date(untilB).getTime() : Infinity;

  return startA <= endB && endA >= startB;
}

// Compute if an availability record is valid and current right now
function isRecordEffectiveNow(record, now = new Date()) {
  if (!record || !record.isActive) return false;
  const from = new Date(record.availableFrom);
  const until = record.availableUntil ? new Date(record.availableUntil) : null;
  return from <= now && (!until || until >= now);
}

// Synchronize DonorProfile.isAvailable based on active availability records
async function syncDonorProfileAvailability(donorId) {
  if (!prisma) return;
  try {
    const now = new Date();
    const activeRecords = await prisma.donorAvailability.findMany({
      where: { donorId, isActive: true },
      orderBy: { availableFrom: 'desc' },
    });

    let effectiveAvailable = false;
    if (activeRecords.length === 0) {
      // If no records, keep existing profile availability or default to true for unconfigured donors
      const existingProfile = await prisma.donorProfile.findUnique({ where: { userId: donorId } });
      effectiveAvailable = existingProfile ? (existingProfile.isAvailable ?? true) : true;
    } else {
      const current = activeRecords.find(r => isRecordEffectiveNow(r, now));
      if (current) {
        effectiveAvailable = current.status === 'Available';
      } else {
        // If all active records have expired or only future records exist
        effectiveAvailable = false;
      }
    }

    await prisma.donorProfile.updateMany({
      where: { userId: donorId },
      data: { isAvailable: effectiveAvailable },
    });
  } catch (err) {
    console.error('[DonorAvailability] Sync error:', err.message);
  }
}

// Validation helper
function validateAvailabilityInput(body, isUpdate = false) {
  const errors = [];
  const { status, availableFrom, availableUntil, city, notes } = body;

  let cleanStatus = status ? status.toString().trim() : (isUpdate ? undefined : 'Available');
  if (cleanStatus !== undefined && !['Available', 'Unavailable'].includes(cleanStatus)) {
    errors.push('Availability status must be either "Available" or "Unavailable"');
  }

  let fromDate = null;
  if (availableFrom !== undefined && availableFrom !== null) {
    fromDate = new Date(availableFrom);
    if (isNaN(fromDate.getTime())) {
      errors.push('Available From must be a valid date');
    }
  } else if (!isUpdate) {
    errors.push('Available From date is required');
  }

  let untilDate = null;
  if (availableUntil !== undefined && availableUntil !== null && availableUntil !== '') {
    untilDate = new Date(availableUntil);
    if (isNaN(untilDate.getTime())) {
      errors.push('Available Until must be a valid date');
    }
  }

  if (fromDate && untilDate && untilDate < fromDate) {
    errors.push('Available Until date cannot be earlier than Available From date');
  }

  let cleanCity = city !== undefined && city !== null ? city.toString().trim() : undefined;
  let cleanNotes = notes !== undefined && notes !== null ? notes.toString().trim() : undefined;
  if (cleanNotes && cleanNotes.length > 500) {
    errors.push('Notes cannot exceed 500 characters');
  }

  return {
    valid: errors.length === 0,
    errors,
    data: {
      status: cleanStatus,
      availableFrom: fromDate,
      availableUntil: untilDate,
      city: cleanCity,
      notes: cleanNotes,
    },
  };
}

// Protect all routes with JWT authentication
router.use(authenticateToken);

// Verify active user
router.use(async (req, res, next) => {
  try {
    const donorId = req.user?.id;
    if (!donorId) {
      return res.status(401).json({ success: false, message: 'Authentication required' });
    }

    if (prisma) {
      const user = await prisma.user.findUnique({ where: { id: donorId } });
      if (!user) {
        return res.status(401).json({ success: false, message: 'User account not found' });
      }
      if (!user.isActive) {
        return res.status(403).json({ success: false, message: 'Account is deactivated' });
      }
    }
    next();
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// -----------------------------------------------------------------------------
// POST /api/donor-availability — Create Availability
// -----------------------------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    const donorId = req.user.id;
    const validation = validateAvailabilityInput(req.body, false);
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors.join('. '),
        errors: validation.errors,
      });
    }

    const { status, availableFrom, availableUntil, notes } = validation.data;
    let city = validation.data.city;

    // Use donor's existing location where possible if not explicitly provided
    if (!city) {
      if (prisma) {
        const donorProfile = await prisma.donorProfile.findUnique({ where: { userId: donorId } });
        city = donorProfile?.city || 'Colombo';
      } else {
        city = 'Colombo';
      }
    }

    if (prisma) {
      // Check for conflicting or overlapping active availability records for this donor
      const existingActive = await prisma.donorAvailability.findMany({
        where: {
          donorId,
          isActive: true,
        },
      });

      for (const rec of existingActive) {
        if (rangesOverlap(availableFrom, availableUntil, rec.availableFrom, rec.availableUntil)) {
          return res.status(409).json({
            success: false,
            message: 'An active availability schedule already exists for this date range. Please update or delete your existing schedule.',
            conflictingRecord: rec,
          });
        }
      }

      const newRecord = await prisma.donorAvailability.create({
        data: {
          donorId,
          status,
          availableFrom,
          availableUntil,
          city,
          notes,
          isActive: true,
        },
      });

      // Synchronize DonorProfile.isAvailable
      await syncDonorProfileAvailability(donorId);

      return res.status(201).json({
        success: true,
        message: 'Availability schedule created successfully',
        data: newRecord,
      });
    }

    // In-memory fallback
    if (!db.donorAvailabilities) db.donorAvailabilities = [];
    const conflict = db.donorAvailabilities.find(
      r => r.donorId === donorId && r.isActive && rangesOverlap(availableFrom, availableUntil, r.availableFrom, r.availableUntil)
    );
    if (conflict) {
      return res.status(409).json({
        success: false,
        message: 'An active availability schedule already exists for this date range.',
      });
    }

    const memRecord = {
      id: randomUUID(),
      donorId,
      status,
      availableFrom,
      availableUntil,
      city,
      notes,
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    db.donorAvailabilities.push(memRecord);

    return res.status(201).json({
      success: true,
      message: 'Availability schedule created successfully',
      data: memRecord,
    });
  } catch (error) {
    console.error('Create availability error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create availability schedule: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// GET /api/donor-availability/me — Get Authenticated Donor's Availability
// -----------------------------------------------------------------------------
router.get('/me', async (req, res) => {
  try {
    const donorId = req.user.id;
    const includeHistory = req.query.includeHistory === 'true';

    let records = [];
    if (prisma) {
      records = await prisma.donorAvailability.findMany({
        where: {
          donorId,
          ...(includeHistory ? {} : { isActive: true }),
        },
        orderBy: [{ availableFrom: 'desc' }, { createdAt: 'desc' }],
      });
    } else {
      records = (db.donorAvailabilities || []).filter(
        r => r.donorId === donorId && (includeHistory ? true : r.isActive)
      );
    }

    const now = new Date();
    const currentActiveRecord = records.find(r => isRecordEffectiveNow(r, now));
    const isCurrentlyAvailable = currentActiveRecord ? currentActiveRecord.status === 'Available' : false;

    return res.json({
      success: true,
      currentStatus: currentActiveRecord ? currentActiveRecord.status : (records.length === 0 ? 'Not Scheduled' : 'No Active Schedule'),
      isCurrentlyAvailable,
      currentRecord: currentActiveRecord || null,
      count: records.length,
      data: records,
    });
  } catch (error) {
    console.error('Get my availability error:', error);
    return res.status(500).json({ success: false, message: 'Failed to retrieve availability records: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// GET /api/donor-availability/:id — Get Specific Record
// -----------------------------------------------------------------------------
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const donorId = req.user.id;
    const isManager = req.user.role === 'manager';

    let record = null;
    if (prisma) {
      record = await prisma.donorAvailability.findUnique({
        where: { id },
        include: {
          donor: {
            select: { id: true, name: true, email: true, phone: true },
          },
        },
      });
    } else {
      record = (db.donorAvailabilities || []).find(r => r.id === id);
    }

    if (!record) {
      return res.status(404).json({ success: false, message: 'Availability record not found' });
    }

    // Ownership check: only owner or manager can access private records
    if (record.donorId !== donorId && !isManager) {
      return res.status(403).json({ success: false, message: 'You are not authorized to view this availability record' });
    }

    return res.json({
      success: true,
      data: record,
    });
  } catch (error) {
    console.error('Get availability details error:', error);
    return res.status(500).json({ success: false, message: 'Failed to retrieve availability record: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// PUT /api/donor-availability/:id — Update Availability
// -----------------------------------------------------------------------------
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const donorId = req.user.id;

    let existing = null;
    if (prisma) {
      existing = await prisma.donorAvailability.findUnique({ where: { id } });
    } else {
      existing = (db.donorAvailabilities || []).find(r => r.id === id);
    }

    if (!existing) {
      return res.status(404).json({ success: false, message: 'Availability record not found' });
    }

    // Ownership check: donors can only update their own records
    if (existing.donorId !== donorId) {
      return res.status(403).json({ success: false, message: 'You are not authorized to modify this availability record' });
    }

    const validation = validateAvailabilityInput(req.body, true);
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors.join('. '),
        errors: validation.errors,
      });
    }

    const updateData = {};
    if (validation.data.status !== undefined) updateData.status = validation.data.status;
    if (validation.data.availableFrom !== null) updateData.availableFrom = validation.data.availableFrom;
    if (validation.data.availableUntil !== null) updateData.availableUntil = validation.data.availableUntil;
    if (validation.data.city !== undefined) updateData.city = validation.data.city;
    if (validation.data.notes !== undefined) updateData.notes = validation.data.notes;

    // Evaluate proposed date range against other active records of the donor
    const targetFrom = updateData.availableFrom || existing.availableFrom;
    const targetUntil = updateData.availableUntil !== undefined ? updateData.availableUntil : existing.availableUntil;

    if (targetUntil && new Date(targetUntil) < new Date(targetFrom)) {
      return res.status(400).json({
        success: false,
        message: 'Available Until date cannot be earlier than Available From date',
      });
    }

    if (prisma) {
      const otherActive = await prisma.donorAvailability.findMany({
        where: {
          donorId,
          isActive: true,
          id: { not: id },
        },
      });

      for (const other of otherActive) {
        if (rangesOverlap(targetFrom, targetUntil, other.availableFrom, other.availableUntil)) {
          return res.status(409).json({
            success: false,
            message: 'The updated date range conflicts with another active availability schedule.',
            conflictingRecord: other,
          });
        }
      }

      const updated = await prisma.donorAvailability.update({
        where: { id },
        data: updateData,
      });

      // Synchronize DonorProfile.isAvailable
      await syncDonorProfileAvailability(donorId);

      return res.json({
        success: true,
        message: 'Availability schedule updated successfully',
        data: updated,
      });
    }

    // In-memory fallback
    Object.assign(existing, updateData, { updatedAt: new Date() });
    return res.json({
      success: true,
      message: 'Availability schedule updated successfully',
      data: existing,
    });
  } catch (error) {
    console.error('Update availability error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update availability schedule: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// DELETE /api/donor-availability/:id — Delete Availability (Soft-Delete)
// -----------------------------------------------------------------------------
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const donorId = req.user.id;

    let existing = null;
    if (prisma) {
      existing = await prisma.donorAvailability.findUnique({ where: { id } });
    } else {
      existing = (db.donorAvailabilities || []).find(r => r.id === id);
    }

    if (!existing) {
      return res.status(404).json({ success: false, message: 'Availability record not found' });
    }

    // Ownership check: donors can only delete their own records
    if (existing.donorId !== donorId) {
      return res.status(403).json({ success: false, message: 'You are not authorized to delete this availability record' });
    }

    if (prisma) {
      // Soft-delete to preserve audit history
      await prisma.donorAvailability.update({
        where: { id },
        data: { isActive: false },
      });

      // Synchronize DonorProfile.isAvailable
      await syncDonorProfileAvailability(donorId);

      return res.json({
        success: true,
        message: 'Availability schedule deleted successfully',
      });
    }

    existing.isActive = false;
    return res.json({
      success: true,
      message: 'Availability schedule deleted successfully',
    });
  } catch (error) {
    console.error('Delete availability error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete availability schedule: ' + error.message });
  }
});

module.exports = router;
