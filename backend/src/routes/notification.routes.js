const express = require('express');
const router = express.Router();
const { prisma, db } = require('../prisma');

// GET /api/notifications/unread-count
router.get('/unread-count', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    if (prisma && userId) {
      try {
        const count = await prisma.notification.count({
          where: { userId, isRead: false },
        });
        return res.json({ success: true, count });
      } catch (dbError) {
        console.error('Prisma count unread error:', dbError.message);
      }
    }

    const count = db.notifications.filter(n => (!userId || n.userId === userId) && !n.isRead).length;
    return res.json({ success: true, count });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/notifications
router.get('/', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    if (prisma) {
      try {
        const whereClause = userId ? { userId } : {};
        const notifications = await prisma.notification.findMany({
          where: whereClause,
          orderBy: { timestamp: 'desc' },
        });
        return res.json({ success: true, data: notifications });
      } catch (dbError) {
        console.error('Prisma notifications GET error:', dbError.message);
      }
    }

    const filtered = userId
      ? db.notifications.filter(n => n.userId === userId)
      : db.notifications;
    return res.json({ success: true, data: filtered });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/notifications/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        const notif = await prisma.notification.findUnique({ where: { id } });
        if (notif) {
          return res.json({ success: true, data: notif });
        }
      } catch (dbError) {
        console.error('Prisma GET /notifications/:id error:', dbError.message);
      }
    }

    const memoryNotif = db.notifications.find(n => n.id === id);
    if (!memoryNotif) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }
    return res.json({ success: true, data: memoryNotif });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/notifications
router.post('/', async (req, res) => {
  try {
    const { userId, title, message, type, relatedRequestId } = req.body;

    if (!title || !message) {
      return res.status(400).json({ success: false, message: 'Title and message are required' });
    }

    if (prisma) {
      try {
        let validUserId = userId;
        if (validUserId) {
          const userExists = await prisma.user.findUnique({ where: { id: validUserId } });
          if (!userExists) {
            validUserId = null;
          }
        }

        if (!validUserId) {
          const firstUser = await prisma.user.findFirst();
          if (firstUser) validUserId = firstUser.id;
        }

        if (validUserId) {
          const newNotif = await prisma.notification.create({
            data: {
              userId: validUserId,
              title,
              message,
              type: type || 'emergency',
              relatedRequestId: relatedRequestId || null,
              isRead: false,
            },
          });

          db.notifications.unshift(newNotif);
          return res.status(201).json({
            success: true,
            message: 'Notification created successfully',
            data: newNotif,
          });
        }
      } catch (dbError) {
        console.error('Prisma POST /notifications error:', dbError.message);
      }
    }

    // In-memory fallback
    const fallbackNotif = {
      id: `notif_${Date.now()}`,
      userId: userId || 'usr_donor_101',
      title,
      message,
      type: type || 'emergency',
      relatedRequestId: relatedRequestId || null,
      isRead: false,
      timestamp: new Date().toISOString(),
    };

    db.notifications.unshift(fallbackNotif);
    return res.status(201).json({
      success: true,
      message: 'Notification created successfully (in-memory mode)',
      data: fallbackNotif,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// PATCH /api/notifications/:id/read
router.patch('/:id/read', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        await prisma.notification.update({
          where: { id },
          data: { isRead: true },
        });
        return res.json({ success: true, message: 'Notification marked as read' });
      } catch (dbError) {
        console.error('Prisma notification update error:', dbError.message);
      }
    }

    const notif = db.notifications.find(n => n.id === id);
    if (notif) {
      notif.isRead = true;
    }
    return res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/notifications/read-all
router.post('/read-all', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    if (prisma) {
      try {
        await prisma.notification.updateMany({
          where: userId ? { userId } : {},
          data: { isRead: true },
        });
        return res.json({ success: true, message: 'All notifications marked as read' });
      } catch (dbError) {
        console.error('Prisma notification read-all error:', dbError.message);
      }
    }

    for (const n of db.notifications) {
      if (!userId || n.userId === userId) {
        n.isRead = true;
      }
    }
    return res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/notifications/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    if (prisma) {
      try {
        await prisma.notification.delete({
          where: { id },
        });
        return res.json({ success: true, message: 'Notification deleted' });
      } catch (dbError) {
        console.error('Prisma notification delete error:', dbError.message);
      }
    }

    const idx = db.notifications.findIndex(n => n.id === id);
    if (idx !== -1) {
      db.notifications.splice(idx, 1);
    }
    return res.json({ success: true, message: 'Notification deleted' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
