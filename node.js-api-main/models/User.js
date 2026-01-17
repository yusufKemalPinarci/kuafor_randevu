const mongoose = require('mongoose');

const UserRole = {
  CUSTOMER: 'Customer',
  BARBER: 'Barber',
  ADMIN: 'Admin',
};

// Müsait saat yapısı
const availabilitySchema = new mongoose.Schema({
  dayOfWeek: { type: Number, required: false }, // 0=Pazar, 1=Pazartesi ... 6=Cumartesi
  timeRanges: [
    {
      startTime: { type: String, required: false }, // "09:00"
      endTime: { type: String, required: false },   // "12:00"
    }
  ]
}, { _id: false });

const userSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String },
  role: { type: String, enum: Object.values(UserRole), default: UserRole.CUSTOMER },
  phone: { type: String, trim: true, default: '' },
  shopId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', default: null },

  // Berberlere özel alanlar
  availability: [availabilitySchema], // haftalık müsait saatler
  // services: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Service' }], // sunduğu hizmetler
  bio: { type: String, trim: true, default: '' }, // kısa açıklama
}, { timestamps: true });

module.exports = {
  User: mongoose.model('User', userSchema),
  UserRole,
};
