const mongoose = require('mongoose');

const promoCodeSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true, uppercase: true, trim: true },
  label: { type: String, required: true }, // "Ahmet'e verilen kod", "Instagram kampanyası"
  bonusDays: { type: Number, default: 30, min: 1, max: 365 }, // kaç gün ücretsiz
  maxUsage: { type: Number, default: 0 }, // 0 = sınırsız
  usageCount: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, { timestamps: true });

module.exports = mongoose.model('PromoCode', promoCodeSchema);
