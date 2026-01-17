const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  date: { type: Date, required: true }, // Tarih + saat
  startTime: { type: Date, required: true },
  endTime: { type: Date, required: false },
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: false },
  customerName: { type: String, required: true },
  customerPhone: { type: String, required: true },
  barberId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  serviceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Service', required: true },
  otp: String,
  otpExpiresAt: Date,
  status: { type: String, enum: ['pending', 'confirmed', 'cancelled'], default: 'pending' },
  notes: { type: String },
 


}, { timestamps: true });

module.exports = mongoose.model('Appointment', appointmentSchema);
