require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth.routes');
const donorRoutes = require('./routes/donor.routes');
const requestRoutes = require('./routes/request.routes');
const notificationRoutes = require('./routes/notification.routes');
const donationRoutes = require('./routes/donation.routes');
const { authenticateToken } = require('./middleware/auth.middleware');
const { verifyEmailConnection, getEmailConfigSummary } = require('./services/email.service');

const app = express();
const PORT = process.env.PORT || 5000;

// Enable CORS for Flutter mobile, web, and emulator clients
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
}));
app.options('*', cors());

app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'LifeLink REST API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Protected route verification endpoint
app.get('/api/auth/verify', authenticateToken, (req, res) => {
  res.json({
    success: true,
    message: 'Token is valid and authenticated',
    user: req.user,
  });
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/donors', donorRoutes);
app.use('/api/requests', requestRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/donations', donationRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint ${req.method} ${req.originalUrl} not found`,
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

if (require.main === module) {
  app.listen(PORT, async () => {
    console.log('====================================================');
    console.log(`🩸 LifeLink REST API Server running on port ${PORT}`);
    console.log(`📡 Base URL: http://localhost:${PORT}/api`);
    console.log(`📱 Android Emulator URL: http://10.0.2.2:${PORT}/api`);
    console.log(`🏥 Health Check: http://localhost:${PORT}/api/health`);
    const emailConfig = getEmailConfigSummary();
    console.log(`📧 Email Service: ${emailConfig.configured ? `Configured (${emailConfig.service} - ${emailConfig.host}:${emailConfig.port})` : 'NOT CONFIGURED (Add SMTP credentials to backend/.env)'}`);
    console.log('====================================================');

    if (emailConfig.configured) {
      await verifyEmailConnection();
    }
  });
}

module.exports = app;
