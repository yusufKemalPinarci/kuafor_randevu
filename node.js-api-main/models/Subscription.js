const mongoose = require('mongoose');

const SubscriptionTier = {
  STANDART: 'standart',
  PRO: 'pro',
  PREMIUM: 'premium',
};

const BillingPeriod = {
  MONTHLY: 'monthly',
  SIX_MONTH: '6month',
  YEARLY: 'yearly',
  FREE_TRIAL: 'free_trial',
};

const SubscriptionStatus = {
  ACTIVE: 'active',
  EXPIRED: 'expired',
  CANCELLED: 'cancelled',
};

const subscriptionSchema = new mongoose.Schema({
  shopId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shop', required: true },
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  tier: { type: String, enum: Object.values(SubscriptionTier), default: SubscriptionTier.STANDART },
  billingPeriod: { type: String, enum: Object.values(BillingPeriod), default: BillingPeriod.MONTHLY },
  status: { type: String, enum: Object.values(SubscriptionStatus), default: SubscriptionStatus.ACTIVE },
  startDate: { type: Date, default: Date.now },
  endDate: { type: Date, required: true },
  referralCode: { type: String, unique: true, sparse: true }, // Her dükkan sahibinin tekil referans kodu
  referralCodeExpiresAt: { type: Date, default: null }, // null = sonsuz
  referredBy: { type: String, default: null }, // Kayıt sırasında kullanılan referans kodu
  isTrial: { type: Boolean, default: false },
  // Google Play In-App Purchase
  googlePurchaseToken: { type: String, default: null },
  googleProductId: { type: String, default: null },
  googleOrderId: { type: String, default: null },
}, { timestamps: true });

module.exports = {
  Subscription: mongoose.model('Subscription', subscriptionSchema),
  SubscriptionTier,
  BillingPeriod,
  SubscriptionStatus,
};
