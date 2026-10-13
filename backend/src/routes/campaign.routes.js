const express = require('express');
const { randomUUID } = require('node:crypto');
const router = express.Router();
const { prisma, db } = require('../prisma');
const { authenticateToken, optionalAuth } = require('../middleware/auth.middleware');

// Helper to parse time strings like "09:00 AM", "9:00 AM", "14:30", "09:00" into total minutes from midnight
function parseTimeToMinutes(timeStr) {
  if (!timeStr || typeof timeStr !== 'string') return null;
  const trimmed = timeStr.trim().toUpperCase();
  const match = trimmed.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/);
  if (!match) return null;

  let hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);
  const meridiem = match[3];

  if (minutes < 0 || minutes > 59) return null;

  if (meridiem) {
    if (hours < 1 || hours > 12) return null;
    if (meridiem === 'PM' && hours < 12) hours += 12;
    if (meridiem === 'AM' && hours === 12) hours = 0;
  } else {
    if (hours < 0 || hours > 23) return null;
  }

  return hours * 60 + minutes;
}

// Phone validator (requires at least 7 digits, allows +, -, spaces, parentheses)
function isValidPhone(phone) {
  if (!phone || typeof phone !== 'string') return false;
  const digitsOnly = phone.replace(/\D/g, '');
  if (digitsOnly.length < 7 || digitsOnly.length > 15) return false;
  return /^[+]?[0-9\s\-()]+$/.test(phone.trim());
}

// Email validator
function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

// Validation helper for Create and Update
function validateCampaignInput(body, isUpdate = false) {
  const errors = [];
  const {
    campaignName,
    description,
    organizerName,
    contactNumber,
    email,
    hospitalOrBloodBank,
    location,
    city,
    campaignDate,
    startTime,
    endTime,
    targetDonors,
    status,
  } = body;

  let cleanName;
  if (campaignName !== undefined) {
    cleanName = typeof campaignName === 'string' ? campaignName.trim() : '';
    if (!cleanName) {
      errors.push('Campaign Name is required');
    }
  } else if (!isUpdate) {
    errors.push('Campaign Name is required');
  }

  let cleanOrganizerName;
  if (organizerName !== undefined) {
    cleanOrganizerName = typeof organizerName === 'string' ? organizerName.trim() : '';
    if (!cleanOrganizerName) {
      errors.push('Organizer Name is required');
    }
  } else if (!isUpdate) {
    errors.push('Organizer Name is required');
  }

  let cleanContactNumber;
  if (contactNumber !== undefined) {
    cleanContactNumber = typeof contactNumber === 'string' ? contactNumber.trim() : '';
    if (!cleanContactNumber) {
      errors.push('Contact Number is required');
    } else if (!isValidPhone(cleanContactNumber)) {
      errors.push('Please provide a valid Contact Number with 7-15 digits');
    }
  } else if (!isUpdate) {
    errors.push('Contact Number is required');
  }

  let cleanEmail;
  if (email !== undefined && email !== null && email !== '') {
    cleanEmail = typeof email === 'string' ? email.trim() : '';
    if (cleanEmail && !isValidEmail(cleanEmail)) {
      errors.push('Please provide a valid Email Address format');
    }
  } else if (email === '') {
    cleanEmail = null;
  }

  let cleanLocation;
  if (location !== undefined) {
    cleanLocation = typeof location === 'string' ? location.trim() : '';
    if (!cleanLocation) {
      errors.push('Campaign Location is required');
    }
  } else if (!isUpdate) {
    errors.push('Campaign Location is required');
  }

  let cleanCity;
  if (city !== undefined) {
    cleanCity = typeof city === 'string' ? city.trim() : '';
    if (!cleanCity) {
      errors.push('City is required');
    }
  } else if (!isUpdate) {
    errors.push('City is required');
  }

  let parsedDate;
  if (campaignDate !== undefined) {
    parsedDate = new Date(campaignDate);
    if (isNaN(parsedDate.getTime())) {
      errors.push('Campaign Date must be a valid date');
    }
  } else if (!isUpdate) {
    errors.push('Campaign Date is required');
  }

  let cleanStartTime;
  let cleanEndTime;
  if (startTime !== undefined) {
    cleanStartTime = typeof startTime === 'string' ? startTime.trim() : '';
    if (!cleanStartTime) {
      errors.push('Start Time is required');
    } else if (parseTimeToMinutes(cleanStartTime) === null) {
      errors.push('Start Time format is invalid (e.g. "09:00 AM" or "09:00")');
    }
  } else if (!isUpdate) {
    errors.push('Start Time is required');
  }

  if (endTime !== undefined) {
    cleanEndTime = typeof endTime === 'string' ? endTime.trim() : '';
    if (!cleanEndTime) {
      errors.push('End Time is required');
    } else if (parseTimeToMinutes(cleanEndTime) === null) {
      errors.push('End Time format is invalid (e.g. "04:00 PM" or "16:00")');
    }
  } else if (!isUpdate) {
    errors.push('End Time is required');
  }

  if (cleanStartTime && cleanEndTime) {
    const startMins = parseTimeToMinutes(cleanStartTime);
    const endMins = parseTimeToMinutes(cleanEndTime);
    if (startMins !== null && endMins !== null && endMins <= startMins) {
      errors.push('End Time must be later than Start Time');
    }
  }

  let cleanTargetDonors;
  if (targetDonors !== undefined && targetDonors !== null && targetDonors !== '') {
    const num = Number(targetDonors);
    if (!Number.isInteger(num) || num <= 0) {
      errors.push('Target Number of Donors must be a positive whole number');
    } else {
      cleanTargetDonors = num;
    }
  } else if (targetDonors === '' || targetDonors === null) {
    cleanTargetDonors = null;
  }

  let cleanStatus;
  const validStatuses = ['Upcoming', 'Ongoing', 'Completed', 'Cancelled'];
  if (status !== undefined) {
    cleanStatus = typeof status === 'string' ? status.trim() : '';
    if (!validStatuses.includes(cleanStatus)) {
      errors.push(`Status must be one of: ${validStatuses.join(', ')}`);
    }
  } else if (!isUpdate) {
    cleanStatus = 'Upcoming';
  }

  return {
    valid: errors.length === 0,
    errors,
    data: {
      campaignName: cleanName,
      description: description !== undefined ? (description ? description.trim() : null) : undefined,
      organizerName: cleanOrganizerName,
      contactNumber: cleanContactNumber,
      email: cleanEmail,
      hospitalOrBloodBank: hospitalOrBloodBank !== undefined ? (hospitalOrBloodBank ? hospitalOrBloodBank.trim() : null) : undefined,
      location: cleanLocation,
      city: cleanCity,
      campaignDate: parsedDate,
      startTime: cleanStartTime,
      endTime: cleanEndTime,
      targetDonors: cleanTargetDonors,
      status: cleanStatus,
    },
  };
}

// -----------------------------------------------------------------------------
// GET /api/campaigns — List Campaigns with optional filtering
// -----------------------------------------------------------------------------
router.get('/', optionalAuth, async (req, res) => {
  try {
    const { city, status, date, search, includeArchived } = req.query;

    const isManagerOrAdmin = req.user && (req.user.role === 'manager' || req.user.role === 'admin');
    const shouldIncludeArchived = includeArchived === 'true' && isManagerOrAdmin;

    if (prisma) {
      try {
        const where = {};

        if (!shouldIncludeArchived) {
          where.isActive = true;
        }

        if (city && city.trim() !== '') {
          where.city = { contains: city.trim(), mode: 'insensitive' };
        }

        if (status && status.trim() !== '') {
          const statuses = status.split(',').map(s => s.trim()).filter(Boolean);
          if (statuses.length === 1) {
            where.status = { equals: statuses[0], mode: 'insensitive' };
          } else if (statuses.length > 1) {
            where.status = { in: statuses };
          }
        }

        if (date && date.trim() !== '') {
          const filterDate = new Date(date.trim());
          if (!isNaN(filterDate.getTime())) {
            const startOfDay = new Date(filterDate);
            startOfDay.setUTCHours(0, 0, 0, 0);
            const endOfDay = new Date(filterDate);
            endOfDay.setUTCHours(23, 59, 59, 999);

            where.campaignDate = {
              gte: startOfDay,
              lte: endOfDay,
            };
          }
        }

        if (search && search.trim() !== '') {
          const term = search.trim();
          where.OR = [
            { campaignName: { contains: term, mode: 'insensitive' } },
            { location: { contains: term, mode: 'insensitive' } },
            { city: { contains: term, mode: 'insensitive' } },
            { organizerName: { contains: term, mode: 'insensitive' } },
            { hospitalOrBloodBank: { contains: term, mode: 'insensitive' } },
            { description: { contains: term, mode: 'insensitive' } },
          ];
        }

        const campaigns = await prisma.bloodCampaign.findMany({
          where,
          orderBy: [
            { campaignDate: 'asc' },
            { startTime: 'asc' },
          ],
          include: {
            organizer: {
              select: { id: true, name: true, email: true, phone: true, role: true },
            },
          },
        });

        return res.json({
          success: true,
          count: campaigns.length,
          data: campaigns,
        });
      } catch (dbError) {
        console.error('Prisma GET /campaigns error, falling back to memory store:', dbError.message);
      }
    }

    // In-memory fallback
    let results = (db.campaigns || []).filter(c => shouldIncludeArchived ? true : c.isActive !== false);

    if (city && city.trim() !== '') {
      const cLower = city.trim().toLowerCase();
      results = results.filter(c => c.city && c.city.toLowerCase().includes(cLower));
    }

    if (status && status.trim() !== '') {
      const statuses = status.split(',').map(s => s.trim().toLowerCase());
      results = results.filter(c => c.status && statuses.includes(c.status.toLowerCase()));
    }

    if (date && date.trim() !== '') {
      const targetStr = new Date(date.trim()).toISOString().split('T')[0];
      results = results.filter(c => {
        const cDateStr = new Date(c.campaignDate).toISOString().split('T')[0];
        return cDateStr === targetStr;
      });
    }

    if (search && search.trim() !== '') {
      const term = search.trim().toLowerCase();
      results = results.filter(c =>
        (c.campaignName && c.campaignName.toLowerCase().includes(term)) ||
        (c.location && c.location.toLowerCase().includes(term)) ||
        (c.city && c.city.toLowerCase().includes(term)) ||
        (c.organizerName && c.organizerName.toLowerCase().includes(term)) ||
        (c.hospitalOrBloodBank && c.hospitalOrBloodBank.toLowerCase().includes(term)) ||
        (c.description && c.description.toLowerCase().includes(term))
      );
    }

    return res.json({
      success: true,
      count: results.length,
      data: results,
    });
  } catch (error) {
    console.error('Get campaigns error:', error);
    return res.status(500).json({ success: false, message: 'Failed to retrieve campaigns: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// GET /api/campaigns/:id — Get Campaign Details
// -----------------------------------------------------------------------------
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        const campaign = await prisma.bloodCampaign.findUnique({
          where: { id },
          include: {
            organizer: {
              select: { id: true, name: true, email: true, phone: true, role: true },
            },
          },
        });

        if (campaign) {
          const isManagerOrAdmin = req.user && (req.user.role === 'manager' || req.user.role === 'admin');
          if (!campaign.isActive && !isManagerOrAdmin) {
            return res.status(404).json({ success: false, message: 'Blood campaign not found or has been archived' });
          }

          return res.json({
            success: true,
            data: campaign,
          });
        }
      } catch (dbError) {
        console.error('Prisma findUnique error in GET /:id, falling back to memory store:', dbError.message);
      }
    }

    // In-memory fallback
    const campaign = (db.campaigns || []).find(c => c.id === id);
    if (!campaign) {
      return res.status(404).json({ success: false, message: 'Blood campaign not found' });
    }

    return res.json({
      success: true,
      data: campaign,
    });
  } catch (error) {
    console.error('Get campaign by id error:', error);
    return res.status(500).json({ success: false, message: 'Failed to retrieve campaign details: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// POST /api/campaigns — Create Blood Campaign
// -----------------------------------------------------------------------------
router.post('/', authenticateToken, async (req, res) => {
  try {
    const validation = validateCampaignInput(req.body, false);
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors.join('. '),
        errors: validation.errors,
      });
    }

    let organizerId = req.user?.id || 'usr_manager_001';

    if (prisma) {
      try {
        // Ensure organizerId exists in database to prevent foreign key violations
        let organizerUser = await prisma.user.findUnique({ where: { id: organizerId } });
        if (!organizerUser && req.user?.email) {
          organizerUser = await prisma.user.findFirst({
            where: { email: { equals: req.user.email, mode: 'insensitive' } },
          });
          if (organizerUser) {
            organizerId = organizerUser.id;
          }
        }
        if (!organizerUser) {
          const fallbackManager = await prisma.user.findFirst({ where: { role: 'manager' } })
            || await prisma.user.findFirst();
          if (fallbackManager) {
            organizerId = fallbackManager.id;
          }
        }

        const campaignData = {
          ...validation.data,
          organizerId,
        };

        const newCampaign = await prisma.bloodCampaign.create({
          data: campaignData,
          include: {
            organizer: {
              select: { id: true, name: true, email: true, phone: true, role: true },
            },
          },
        });

        return res.status(201).json({
          success: true,
          message: 'Blood campaign created successfully',
          data: newCampaign,
        });
      } catch (dbError) {
        console.error('Prisma create campaign error, falling back to in-memory store:', dbError.message);
      }
    }

    const campaignData = {
      ...validation.data,
      organizerId,
    };

    // In-memory fallback
    if (!db.campaigns) db.campaigns = [];
    const memCampaign = {
      id: randomUUID(),
      ...campaignData,
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    db.campaigns.push(memCampaign);

    return res.status(201).json({
      success: true,
      message: 'Blood campaign created successfully',
      data: memCampaign,
    });
  } catch (error) {
    console.error('Create campaign error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create blood campaign: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// PUT /api/campaigns/:id — Update Blood Campaign
// -----------------------------------------------------------------------------
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const userRole = req.user?.role;
    const isManagerOrAdmin = userRole === 'manager' || userRole === 'admin';

    let existing = null;
    if (prisma) {
      try {
        existing = await prisma.bloodCampaign.findUnique({ where: { id } });
      } catch (dbError) {
        console.error('Prisma findUnique error:', dbError.message);
      }
    }
    if (!existing) {
      existing = (db.campaigns || []).find(c => c.id === id);
    }

    if (!existing) {
      return res.status(404).json({ success: false, message: 'Blood campaign not found' });
    }

    // Authorization: only the organizer who created it or a manager/admin
    const isOwner = existing.organizerId === userId;
    if (!isOwner && !isManagerOrAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: You are not authorized to update this blood campaign',
      });
    }

    const validation = validateCampaignInput(req.body, true);
    if (!validation.valid) {
      return res.status(400).json({
        success: false,
        message: validation.errors.join('. '),
        errors: validation.errors,
      });
    }

    // Filter out undefined values from validation.data
    const updateData = {};
    for (const [key, val] of Object.entries(validation.data)) {
      if (val !== undefined) {
        updateData[key] = val;
      }
    }

    // Check time range if either startTime or endTime is being updated
    const finalStartTime = updateData.startTime || existing.startTime;
    const finalEndTime = updateData.endTime || existing.endTime;
    const startMins = parseTimeToMinutes(finalStartTime);
    const endMins = parseTimeToMinutes(finalEndTime);
    if (startMins !== null && endMins !== null && endMins <= startMins) {
      return res.status(400).json({
        success: false,
        message: 'End Time must be later than Start Time',
      });
    }

    if (prisma) {
      try {
        const updated = await prisma.bloodCampaign.update({
          where: { id },
          data: updateData,
          include: {
            organizer: {
              select: { id: true, name: true, email: true, phone: true, role: true },
            },
          },
        });

        return res.json({
          success: true,
          message: 'Blood campaign updated successfully',
          data: updated,
        });
      } catch (dbError) {
        console.error('Prisma update error, falling back to memory:', dbError.message);
      }
    }

    // In-memory fallback
    Object.assign(existing, updateData, { updatedAt: new Date() });
    return res.json({
      success: true,
      message: 'Blood campaign updated successfully',
      data: existing,
    });
  } catch (error) {
    console.error('Update campaign error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update blood campaign: ' + error.message });
  }
});

// -----------------------------------------------------------------------------
// DELETE /api/campaigns/:id — Delete/Archive Blood Campaign
// -----------------------------------------------------------------------------
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const userRole = req.user?.role;
    const isManagerOrAdmin = userRole === 'manager' || userRole === 'admin';

    let existing = null;
    if (prisma) {
      try {
        existing = await prisma.bloodCampaign.findUnique({ where: { id } });
      } catch (dbError) {
        console.error('Prisma findUnique error:', dbError.message);
      }
    }
    if (!existing) {
      existing = (db.campaigns || []).find(c => c.id === id);
    }

    if (!existing) {
      return res.status(404).json({ success: false, message: 'Blood campaign not found' });
    }

    // Authorization: only the organizer or a manager/admin can delete
    const isOwner = existing.organizerId === userId;
    if (!isOwner && !isManagerOrAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: You are not authorized to delete or cancel this blood campaign',
      });
    }

    // Soft delete / archive to safely preserve historical references
    if (prisma) {
      try {
        const archived = await prisma.bloodCampaign.update({
          where: { id },
          data: {
            isActive: false,
            status: 'Cancelled',
          },
        });

        return res.json({
          success: true,
          message: 'Blood campaign cancelled and archived successfully',
          data: archived,
        });
      } catch (dbError) {
        console.error('Prisma delete error, falling back to memory:', dbError.message);
      }
    }

    // In-memory fallback
    existing.isActive = false;
    existing.status = 'Cancelled';
    existing.updatedAt = new Date();

    return res.json({
      success: true,
      message: 'Blood campaign cancelled and archived successfully',
    });
  } catch (error) {
    console.error('Delete campaign error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete blood campaign: ' + error.message });
  }
});

module.exports = router;
