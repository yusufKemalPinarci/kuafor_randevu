const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema({
  barberId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true },
  price: { type: Number, required: true },
  durationMinutes: { type: Number, required: true }
}, { timestamps: true });


module.exports = mongoose.model('Service', serviceSchema);
