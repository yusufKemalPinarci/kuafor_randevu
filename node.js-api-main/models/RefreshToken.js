const mongoose = require('mongoose');

const refreshTokenSchema = new mongoose.Schema({
  token:     { type: String, required: true, unique: true, index: true },
  userId:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  expiresAt: { type: Date, required: true },
  isRevoked: { type: Boolean, default: false },
}, {
  timestamps: true,
});

// TTL index — süresi dolan tokenlar MongoDB tarafından otomatik silinir
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('RefreshToken', refreshTokenSchema);
