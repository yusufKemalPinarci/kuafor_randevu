const mongoose = require('mongoose');

const blockedTimeSchema = new mongoose.Schema({
  barberId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  date: { type: String, required: true },       // "2026-03-10"
  startTime: { type: String, required: true },   // "13:00"
  endTime: { type: String, required: true },     // "15:00"
  reason: { type: String, default: '' },
}, { timestamps: true });

module.exports = mongoose.model('BlockedTime', blockedTimeSchema);
