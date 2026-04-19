const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  adminId:    { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  adminEmail: { type: String, required: true },
  action:     { type: String, required: true },
  targetType: { type: String, enum: ['User', 'Shop', 'Subscription', 'PromoCode', 'Appointment'], required: true },
  targetId:   { type: mongoose.Schema.Types.ObjectId },
  details:    { type: mongoose.Schema.Types.Mixed },
}, { timestamps: true });

auditLogSchema.index({ createdAt: -1 });
auditLogSchema.index({ adminId: 1, createdAt: -1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
