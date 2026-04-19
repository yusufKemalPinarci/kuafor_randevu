require('dotenv').config();
const mongoose = require('mongoose');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const userRoutes = require('./routes/user');
const serviceRoutes = require('./routes/service');
const appointmentRoutes = require('./routes/appointment');
const shopRoutes = require('./routes/shop');
const subscriptionRoutes = require('./routes/subscription');
const adminRoutes = require('./routes/admin');
const swaggerDocs = require('./swagger');
const hmacMiddleware = require('./middlewares/hmac');
const { initFirebase } = require('./utils/notificationService');
const { startReminderCron } = require('./utils/reminderCron');
const { startDailySummaryCron } = require('./utils/dailySummaryCron');

const app = express();
const port = process.env.PORT || 3000;
const isProd = process.env.NODE_ENV === 'production';

// cPanel Passenger uygulamayı alt yola (örn. /kuaflex) mount eder.
// BASE_PATH ile tüm rotalar doğru prefix alır.
// Yerel geliştirmede BASE_PATH boş bırakılır → /api/... olarak çalışır.
// Sunucudaki .env'de: BASE_PATH=/kuaflex
const basePath = (process.env.BASE_PATH || '').replace(/\/$/, '');

// Güvenlik başlıkları
app.use(helmet());

// HTTPS zorla (prod'da reverse proxy arkasında)
// cPanel Passenger zaten SSL termination yapıyor, bu yüzden
// x-forwarded-proto kontrolünü esnek tutuyoruz
function isLocalHost(host) {
  if (!host) return false;
  const hostname = host.split(':')[0];
  return hostname === 'localhost'
    || hostname === '127.0.0.1'
    || hostname === '::1'
    || hostname.startsWith('10.')
    || hostname.startsWith('192.168.')
    || /^172\.(1[6-9]|2\d|3[01])\./.test(hostname);
}

if (isProd) {
  app.use((req, res, next) => {
    // Passenger/Apache arkasında proto header gelmeyebilir — güvenli kabul et
    const proto = req.headers['x-forwarded-proto'] || req.protocol;
    if (proto !== 'https' && !isLocalHost(req.headers.host)) {
      return res.redirect(301, 'https://' + req.headers.host + req.url);
    }
    next();
  });
}

// CORS
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : null;

app.use(cors({
  origin: (origin, callback) => {
    // Mobil uygulamalar origin göndermez—izin ver
    if (!origin) return callback(null, true);
    if (!allowedOrigins || allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error('CORS policy violation'));
  },
  credentials: true,
}));

app.use(express.json({
  limit: '1mb',
  // Ham body'yi sakla — HMAC imza doğrulaması için gerekli
  verify: (req, _res, buf) => { req.rawBody = buf.toString('utf8'); },
}));

// Auth endpoint rate limit: prod → 10 istek/dakika, dev → devre dışı
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  skip: () => !isProd,
  message: { error: 'Çok fazla istek. Lütfen 1 dakika bekleyin.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(`${basePath}/api/user/login`, authLimiter);
app.use(`${basePath}/api/user/register`, authLimiter);
app.use(`${basePath}/api/user/firebase-auth`, authLimiter);
app.use(`${basePath}/api/user/google-auth`, authLimiter);

// HMAC imza doğrulama (production'da tüm API isteklerine uygulanır)
app.use(`${basePath}/api`, hmacMiddleware);

// API rotaları
app.use(`${basePath}/api/shop`, shopRoutes);
app.use(`${basePath}/api/user`, userRoutes);
app.use(`${basePath}/api/service`, serviceRoutes);
app.use(`${basePath}/api/appointment`, appointmentRoutes);
app.use(`${basePath}/api/subscription`, subscriptionRoutes);
app.use(`${basePath}/api/admin`, adminRoutes);

// Swagger sadece geliştirme ortamında
if (!isProd) {
  swaggerDocs(app);
  console.log(`📄 Swagger UI: http://localhost:${port}${basePath}/api-docs`);
}

// Health check — yükleme dengeleyici / uptime monitor için
app.get(`${basePath}/health`, (req, res) => {
  res.json({ status: 'ok', env: process.env.NODE_ENV, timestamp: new Date().toISOString() });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Bu endpoint bulunamadı.' });
});

// Global hata yakalayıcı — dev: stack trace, prod: genel mesaj
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  const status = err.status || 500;
  if (isProd) {
    res.status(status).json({ error: err.message || 'Sunucu hatası.' });
  } else {
    res.status(status).json({ error: err.message, stack: err.stack });
  }
});

// MongoDB bağlantısı
mongoose.connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log('MongoDB connected!');
    await initFirebase();
    startReminderCron();
    startDailySummaryCron();
  })
  .catch(err => console.error('MongoDB connection error:', err));

// Sunucuyu başlat (0.0.0.0 — emülatör ve gerçek cihazlardan erişim için)
const server = app.listen(port, '0.0.0.0', () => {
  const env = process.env.NODE_ENV || 'development';
  console.log(`[${env.toUpperCase()}] Server running on http://0.0.0.0:${port}`);
  if (!isProd) {
    console.log(`  Flutter emülatörü → http://10.0.2.2:${port}`);
    console.log(`  Gerçek cihaz      → http://<LAN_IP>:${port}`);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    mongoose.connection.close();
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  server.close(() => {
    mongoose.connection.close();
    process.exit(0);
  });
});

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
});

module.exports = app;
