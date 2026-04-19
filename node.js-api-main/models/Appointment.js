const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  date: { type: Date, required: true }, // Tarih + saat
  startTime: { type: Date, required: true },
  endTime: { type: Date, required: false },
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: false },
  customerName: { type: String, required: true },
  customerPhone: { type: String, required: true },
  customerEmail: { type: String },
  barberId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true },
  status: { type: String, enum: ['pending', 'confirmed', 'cancelled'], default: 'pending' },
  notes: { type: String },
  reminderSent1h: { type: Boolean, default: false },
  reminderSent15m: { type: Boolean, default: false },
}, { timestamps: true });

// Çakışma sorgularını hızlandıran bileşik index
appointmentSchema.index({ barberId: 1, date: 1, startTime: 1, endTime: 1 });

module.exports = mongoose.model('Appointment', appointmentSchema);
