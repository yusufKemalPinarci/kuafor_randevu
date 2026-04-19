const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema({
  barberId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true },
  price: { type: Number, required: true, min: [0, 'Fiyat 0 veya daha büyük olmalıdır.'] },
  durationMinutes: { type: Number, required: true, min: [1, 'Süre en az 1 dakika olmalıdır.'] }
}, { timestamps: true });


module.exports = mongoose.model('Service', serviceSchema);
