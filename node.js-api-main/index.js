require('dotenv').config();
const mongoose = require('mongoose');
const express = require('express');
const cors = require('cors');

const userRoutes = require('./routes/user');
const serviceRoutes = require('./routes/service');
const appointmentRoutes = require('./routes/appointment');
const shopRoutes = require('./routes/shop');

// 🔥 Swagger import
const swaggerDocs = require('./swagger'); // <- bunu ekledik

const app = express();
const port = process.env.PORT || 3000;

// Middleware'ler
app.use(express.json());
app.use(cors());

// API rotaları
app.use('/api/shop', shopRoutes);
app.use('/api/user', userRoutes);
app.use('/api/service', serviceRoutes);
app.use('/api/appointment', appointmentRoutes);

// 🔥 Swagger route'u aktif et
swaggerDocs(app); // <- bunu da ekledik

// MongoDB bağlantısı
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('MongoDB connected!'))
  .catch(err => console.error('MongoDB connection error:', err));

// Sunucuyu başlat
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
