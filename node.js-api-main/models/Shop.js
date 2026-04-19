const mongoose = require('mongoose');

const shopSchema = new mongoose.Schema({
  name: { type: String, required: true },
  shopCode: { type: String, unique: true, required: true }, // Eklendi (Dükkan Davet Kodu)
  fullAddress: { type: String, required: true },
  neighborhood: { type: String, required: true },
  city: { type: String, required: true },
  district: { type: String },  // <-- district eklendi, zorunlu değil
  phone: { type: String },
  adress: { type: String },
  openingHour: { type: String, required: true },
  closingHour: { type: String, required: true },
  workingDays: [{ type: String, required: true }],
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  autoConfirmAppointments: { type: Boolean, default: false },
}, { timestamps: true });


module.exports = mongoose.model('Shop', shopSchema);
