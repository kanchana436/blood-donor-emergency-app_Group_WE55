require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth.routes');
const donorRoutes = require('./routes/donor.routes');
const requestRoutes = require('./routes/request.routes');
const notificationRoutes = require('./routes/notification.routes');
const donationRoutes = require('./routes/donation.routes');
const bloodStockRoutes = require('./routes/blood-stock.routes');
const verificationQueueRoutes = require('./routes/verification-queue.routes');
const emergencyContactRoutes = require('./routes/emergency-contact.routes');
const donorAvailabilityRoutes = require('./routes/donor-availability.routes');
const campaignRoutes = require('./routes/campaign.routes');
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
app.use('/api/blood-stock', bloodStockRoutes);
app.use('/api/emergency-contacts', emergencyContactRoutes);
app.use('/api/verification-queue', verificationQueueRoutes);
app.use('/api/donor-availability', donorAvailabilityRoutes);
app.use('/api/campaigns', campaignRoutes);

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
  const server = app.listen(PORT, async () => {
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

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`\n⚠️  Port ${PORT} is already in use by another running instance of the backend.`);
      console.error(`If you already have a terminal running 'npm run dev', that server is already active and healthy.`);
      console.error(`To kill any process currently using port ${PORT}, run in PowerShell:`);
      console.error(`   Get-NetTCPConnection -LocalPort ${PORT} -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }\n`);
      process.exit(1);
    } else {
      console.error('Server error:', err);
      process.exit(1);
    }
  });

  const gracefulShutdown = () => {
    server.close(() => {
      process.exit(0);
    });
  };

  process.on('SIGINT', gracefulShutdown);
  process.on('SIGTERM', gracefulShutdown);
}

module.exports = app;
