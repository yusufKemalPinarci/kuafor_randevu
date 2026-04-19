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
  googleId: { type: String, default: null },
  firebaseUid: { type: String, default: null, index: true },
  resetCode: { type: String, default: null },
  resetCodeExpiry: { type: Date, default: null },
  fcmTokens: [{ type: String }], // Firebase Cloud Messaging cihaz token'ları

  // Bildirim tercihleri (berberler için)
  notificationPreferences: {
    push: { type: Boolean, default: true },
    email: { type: Boolean, default: false },
    sms: { type: Boolean, default: false },
    // Push alt tercihleri
    pushNewAppointment: { type: Boolean, default: true },
    pushCancellation: { type: Boolean, default: true },
    pushReminder: { type: Boolean, default: true },
    // Email alt tercihleri
    emailDailySummary: { type: Boolean, default: true },
    emailReminder: { type: Boolean, default: true },
    // SMS alt tercihleri
    smsNewAppointment: { type: Boolean, default: true },
    smsReminder: { type: Boolean, default: true },
    // Müşteri bildirim tercihleri
    customerPushReminder: { type: Boolean, default: true },
    customerPushStatusChange: { type: Boolean, default: true },
    customerEmailReminder: { type: Boolean, default: true },
    customerSmsReminder: { type: Boolean, default: true },
  },
}, { timestamps: true });

module.exports = {
  User: mongoose.model('User', userSchema),
  UserRole,
};
