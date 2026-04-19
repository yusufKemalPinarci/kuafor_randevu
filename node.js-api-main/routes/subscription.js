const express = require('express');
const { Subscription, SubscriptionTier, BillingPeriod, SubscriptionStatus } = require('../models/Subscription');
const Shop = require('../models/Shop');
const { User } = require('../models/User');
const PromoCode = require('../models/PromoCode');
const Settings = require('../models/Settings');
const authMiddleware = require('../middlewares/auth');
const crypto = require('crypto');
const { google } = require('googleapis');
const router = express.Router();

// ────────────────────────────────────────────────────────────
// Google Play Developer API — satın alma doğrulama
// ────────────────────────────────────────────────────────────

const ANDROID_PACKAGE_NAME = 'com.kuaflex.app';

/**
 * Google Play Android Publisher API istemcisini döndürür.
 * Çevresel değişkendeki GOOGLE_SERVICE_ACCOUNT_JSON veya
 * serviceAccountKey.json dosyasından yetkilendirme yapar.
 */
async function getPlayDeveloperApi() {
  let credentials;
  if (process.env.GOOGLE_SERVICE_ACCOUNT_JSON) {
    credentials = JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON);
  } else {
    const path = require('path');
    const fs = require('fs');
    const keyPath = path.join(__dirname, '..', 'googlePlayServiceAccount.json');
    if (!fs.existsSync(keyPath)) {
      throw new Error('Google Play service account key dosyası bulunamadı. googlePlayServiceAccount.json ekleyin veya GOOGLE_SERVICE_ACCOUNT_JSON env değişkeni tanımlayın.');
    }
    credentials = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  }

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  return google.androidpublisher({ version: 'v3', auth });
}

// ────────────────────────────────────────────────────────────
// Yardımcı fonksiyonlar
// ────────────────────────────────────────────────────────────

function generateReferralCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
}

function tierFromProductId(productId) {
  if (!productId) return SubscriptionTier.STANDART;
  if (productId.includes('premium')) return SubscriptionTier.PREMIUM;
  if (productId.includes('pro')) return SubscriptionTier.PRO;
  return SubscriptionTier.STANDART;
}

function billingPeriodFromGoogle(subscriptionData) {
  // Google Play subscriptions v2 API returns billingPeriod in ISO 8601 duration
  // P1M = monthly, P6M = 6 month, P1Y = yearly
  const expiryMs = parseInt(subscriptionData.expiryTimeMillis);
  const startMs = parseInt(subscriptionData.startTimeMillis);
  const durationDays = (expiryMs - startMs) / (1000 * 60 * 60 * 24);
  if (durationDays > 300) return BillingPeriod.YEARLY;
  if (durationDays > 90) return BillingPeriod.SIX_MONTH;
  return BillingPeriod.MONTHLY;
}

/**
 * @swagger
 * tags:
 *   name: Subscription
 *   description: Abonelik yönetimi (Google Play In-App Purchase)
 */

// ────────────────────────────────────────────────────────────
// POST /api/subscription/verify-purchase
// Flutter uygulaması satın alma tamamlandığında bu endpoint'e
// purchaseToken gönderir. Backend Google Play API ile doğrular.
// ────────────────────────────────────────────────────────────

/**
 * @swagger
 * /api/subscription/verify-purchase:
 *   post:
 *     summary: Google Play satın alma doğrulama
 *     tags: [Subscription]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [shopId, purchaseToken, productId, platform]
 *             properties:
 *               shopId:
 *                 type: string
 *               purchaseToken:
 *                 type: string
 *               productId:
 *                 type: string
 *               platform:
 *                 type: string
 *                 enum: [android, ios]
 *               referralCode:
 *                 type: string
 *     responses:
 *       200:
 *         description: Satın alma doğrulandı, abonelik aktif
 *       400:
 *         description: Geçersiz satın alma
 */
router.post('/verify-purchase', authMiddleware, async (req, res) => {
  try {
    const ownerId = req.user._id;
    const { shopId, purchaseToken, productId, platform, referralCode } = req.body;

    if (!shopId || !purchaseToken || !productId) {
      return res.status(400).json({ error: 'shopId, purchaseToken ve productId gerekli.' });
    }

    // Dükkan kontrolü
    const shop = await Shop.findById(shopId);
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });
    if (shop.ownerId.toString() !== ownerId.toString()) {
      return res.status(403).json({ error: 'Bu dükkanın sahibi değilsiniz.' });
    }

    // Aynı purchaseToken daha önce kullanılmış mı?
    const existingToken = await Subscription.findOne({ googlePurchaseToken: purchaseToken });
    if (existingToken) {
      return res.status(400).json({ error: 'Bu satın alma zaten doğrulanmış.' });
    }

    // Google Play API ile doğrulama
    let subscriptionData;
    try {
      const api = await getPlayDeveloperApi();
      const result = await api.purchases.subscriptions.get({
        packageName: ANDROID_PACKAGE_NAME,
        subscriptionId: productId,
        token: purchaseToken,
      });
      subscriptionData = result.data;
    } catch (playErr) {
      console.error('Google Play API error:', playErr.message);
      return res.status(400).json({ error: 'Google Play satın alma doğrulanamadı. Lütfen tekrar deneyin.' });
    }

    // Satın alma geçerli mi?
    // paymentState: 0=Pending, 1=Received, 2=Free trial, 3=Pending deferred
    const paymentState = subscriptionData.paymentState;
    if (paymentState === undefined || (paymentState !== 1 && paymentState !== 2)) {
      return res.status(400).json({ error: 'Ödeme henüz tamamlanmamış.' });
    }

    // Zaten aktif abonelik var mı?
    const existing = await Subscription.findOne({ shopId, status: SubscriptionStatus.ACTIVE });
    if (existing) {
      // Mevcut aboneliği güncelle
      existing.googlePurchaseToken = purchaseToken;
      existing.googleProductId = productId;
      existing.googleOrderId = subscriptionData.orderId || null;
      existing.tier = tierFromProductId(productId);
      existing.billingPeriod = billingPeriodFromGoogle(subscriptionData);
      existing.startDate = new Date(parseInt(subscriptionData.startTimeMillis));
      existing.endDate = new Date(parseInt(subscriptionData.expiryTimeMillis));
      existing.status = SubscriptionStatus.ACTIVE;
      await existing.save();

      return res.status(200).json({
        subscription: existing.toObject(),
        message: 'Abonelik başarıyla güncellendi!',
      });
    }

    // Yeni abonelik oluştur
    const selectedTier = tierFromProductId(productId);
    const selectedBillingPeriod = billingPeriodFromGoogle(subscriptionData);
    const startDate = new Date(parseInt(subscriptionData.startTimeMillis));
    const endDate = new Date(parseInt(subscriptionData.expiryTimeMillis));

    let newReferralCode = generateReferralCode();
    while (await Subscription.findOne({ referralCode: newReferralCode })) {
      newReferralCode = generateReferralCode();
    }

    const validDaysSetting = await Settings.findOne({ key: 'referralCodeValidDays' });
    let referralCodeExpiresAt = null;
    if (validDaysSetting && validDaysSetting.value > 0) {
      referralCodeExpiresAt = new Date();
      referralCodeExpiresAt.setDate(referralCodeExpiresAt.getDate() + validDaysSetting.value);
    }

    let usedReferral = null;
    if (referralCode) {
      const upperCode = referralCode.toUpperCase();
      const referralSub = await Subscription.findOne({ referralCode: upperCode });
      if (referralSub && referralSub.ownerId.toString() !== ownerId.toString()) {
        if (!referralSub.referralCodeExpiresAt || new Date() <= new Date(referralSub.referralCodeExpiresAt)) {
          usedReferral = upperCode;
        }
      } else {
        // Atomik increment — race condition önlenir
        const promo = await PromoCode.findOneAndUpdate(
          { code: upperCode, isActive: true, $or: [{ maxUsage: 0 }, { $expr: { $lt: ['$usageCount', '$maxUsage'] } }] },
          { $inc: { usageCount: 1 } },
          { new: true }
        );
        if (promo) {
          usedReferral = upperCode;
        } else {
          // Kod bulunamadı veya limit dolmuş
          const exists = await PromoCode.findOne({ code: upperCode, isActive: true });
          if (exists) {
            return res.status(400).json({ error: 'Bu promo kodun kullanım limiti dolmuş.' });
          }
        }
      }
    }

    const subscription = new Subscription({
      shopId,
      ownerId,
      tier: selectedTier,
      billingPeriod: selectedBillingPeriod,
      status: SubscriptionStatus.ACTIVE,
      startDate,
      endDate,
      referralCode: newReferralCode,
      referralCodeExpiresAt,
      referredBy: usedReferral,
      googlePurchaseToken: purchaseToken,
      googleProductId: productId,
      googleOrderId: subscriptionData.orderId || null,
    });

    await subscription.save();

    // Referans ödülü: Referrer'ın aboneliğine 7 gün ekle
    if (usedReferral) {
      const referrerSub = await Subscription.findOne({ referralCode: usedReferral });
      if (referrerSub && referrerSub.status === SubscriptionStatus.ACTIVE) {
        const baseDate = new Date(referrerSub.endDate) > new Date() ? new Date(referrerSub.endDate) : new Date();
        baseDate.setDate(baseDate.getDate() + 7);
        referrerSub.endDate = baseDate;
        await referrerSub.save();
      }
    }

    res.status(201).json({
      subscription: subscription.toObject(),
      message: 'Abonelik başarıyla aktifleştirildi!',
    });
  } catch (err) {
    console.error('Verify purchase error:', err);
    res.status(500).json({ error: 'Satın alma doğrulanırken hata oluştu.', details: err.message });
  }
});

// ────────────────────────────────────────────────────────────
// POST /api/subscription/subscribe — Referans kodu ile ücretsiz deneme
// ────────────────────────────────────────────────────────────

/**
 * @swagger
 * /api/subscription/subscribe:
 *   post:
 *     summary: Referans kodu ile ücretsiz abonelik başlat
 *     tags: [Subscription]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               shopId:
 *                 type: string
 *               plan:
 *                 type: string
 *                 enum: [free_trial]
 *               referralCode:
 *                 type: string
 *     responses:
 *       201:
 *         description: Abonelik oluşturuldu
 */
router.post('/subscribe', authMiddleware, async (req, res) => {
  try {
    const ownerId = req.user._id;
    const { shopId, plan, referralCode } = req.body;

    const shop = await Shop.findById(shopId);
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });
    if (shop.ownerId.toString() !== ownerId.toString()) {
      return res.status(403).json({ error: 'Bu dükkanın sahibi değilsiniz.' });
    }

    const existing = await Subscription.findOne({ shopId, status: SubscriptionStatus.ACTIVE });
    if (existing) {
      return res.status(400).json({ error: 'Bu dükkanın zaten aktif bir aboneliği var.' });
    }

    if (!referralCode) {
      return res.status(400).json({ error: 'Ücretsiz deneme sadece referans kodu ile başlatılabilir.' });
    }

    const upperCode = referralCode.toUpperCase();
    let usedReferral = null;
    let bonusDays = 30;

    const referralSub = await Subscription.findOne({ referralCode: upperCode });
    if (referralSub) {
      if (referralSub.ownerId.toString() === ownerId.toString()) {
        return res.status(400).json({ error: 'Kendi referans kodunuzu kullanamazsınız.' });
      }
      if (referralSub.referralCodeExpiresAt && new Date() > new Date(referralSub.referralCodeExpiresAt)) {
        return res.status(400).json({ error: 'Bu referans kodunun geçerlilik süresi dolmuş.' });
      }
      const bonusSetting = await Settings.findOne({ key: 'referralBonusDays' });
      bonusDays = bonusSetting ? bonusSetting.value : 30;
      usedReferral = upperCode;
    } else {
      // Atomik increment — race condition önlenir
      const promo = await PromoCode.findOneAndUpdate(
        { code: upperCode, isActive: true, $or: [{ maxUsage: 0 }, { $expr: { $lt: ['$usageCount', '$maxUsage'] } }] },
        { $inc: { usageCount: 1 } },
        { new: true }
      );
      if (!promo) {
        const exists = await PromoCode.findOne({ code: upperCode, isActive: true });
        if (exists) {
          return res.status(400).json({ error: 'Bu promo kodun kullanım limiti dolmuş.' });
        }
        return res.status(400).json({ error: 'Geçersiz referans kodu.' });
      }
      bonusDays = promo.bonusDays;
      usedReferral = upperCode;
    }

    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + bonusDays);

    let newReferralCode = generateReferralCode();
    while (await Subscription.findOne({ referralCode: newReferralCode })) {
      newReferralCode = generateReferralCode();
    }

    const validDaysSetting = await Settings.findOne({ key: 'referralCodeValidDays' });
    let referralCodeExpiresAt = null;
    if (validDaysSetting && validDaysSetting.value > 0) {
      referralCodeExpiresAt = new Date();
      referralCodeExpiresAt.setDate(referralCodeExpiresAt.getDate() + validDaysSetting.value);
    }

    const subscription = new Subscription({
      shopId,
      ownerId,
      tier: SubscriptionTier.STANDART,
      billingPeriod: BillingPeriod.FREE_TRIAL,
      status: SubscriptionStatus.ACTIVE,
      startDate,
      endDate,
      referralCode: newReferralCode,
      referralCodeExpiresAt,
      referredBy: usedReferral,
      isTrial: true,
    });

    await subscription.save();

    // Referans ödülü
    if (usedReferral) {
      const referrerSub = await Subscription.findOne({ referralCode: usedReferral });
      if (referrerSub && referrerSub.status === SubscriptionStatus.ACTIVE) {
        const baseDate = new Date(referrerSub.endDate) > new Date() ? new Date(referrerSub.endDate) : new Date();
        baseDate.setDate(baseDate.getDate() + 7);
        referrerSub.endDate = baseDate;
        await referrerSub.save();
      }
    }

    res.status(201).json(subscription);
  } catch (err) {
    console.error('Subscribe error:', err);
    res.status(500).json({ error: 'Abonelik oluşturulurken hata oluştu.', details: err.message });
  }
});

// ────────────────────────────────────────────────────────────
// GET /api/subscription/my — Mevcut aboneliği getir
// ────────────────────────────────────────────────────────────

/**
 * @swagger
 * /api/subscription/my:
 *   get:
 *     summary: Mevcut aboneliğimi getir
 *     tags: [Subscription]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Abonelik bilgisi
 */
router.get('/my', authMiddleware, async (req, res) => {
  try {
    const ownerId = req.user._id;
    const subscription = await Subscription.findOne({ ownerId }, null, { sort: { createdAt: -1 } });

    if (!subscription) {
      return res.status(200).json(null);
    }

    if (subscription.status === SubscriptionStatus.ACTIVE && new Date() > subscription.endDate) {
      subscription.status = SubscriptionStatus.EXPIRED;
      await subscription.save();
    }

    const referralCount = subscription.referralCode
      ? await Subscription.countDocuments({ referredBy: subscription.referralCode })
      : 0;

    const subObj = subscription.toObject();
    subObj.referralCount = referralCount;
    delete subObj.googlePurchaseToken;

    res.status(200).json(subObj);
  } catch (err) {
    console.error('Get subscription error:', err);
    res.status(500).json({ error: 'Abonelik bilgisi alınamadı.' });
  }
});

// ────────────────────────────────────────────────────────────
// POST /api/subscription/check-referral
// ────────────────────────────────────────────────────────────

/**
 * @swagger
 * /api/subscription/check-referral:
 *   post:
 *     summary: Referans kodu geçerli mi kontrol et
 *     tags: [Subscription]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               referralCode:
 *                 type: string
 *     responses:
 *       200:
 *         description: Referans kodu geçerli/geçersiz
 */
router.post('/check-referral', async (req, res) => {
  try {
    const { referralCode } = req.body;
    if (!referralCode) return res.status(400).json({ valid: false, error: 'Referans kodu gerekli.' });

    const upperCode = referralCode.toUpperCase();
    const sub = await Subscription.findOne({ referralCode: upperCode });
    if (sub) {
      if (sub.referralCodeExpiresAt && new Date() > new Date(sub.referralCodeExpiresAt)) {
        return res.status(200).json({ valid: false, error: 'Bu referans kodunun geçerlilik süresi dolmuş.' });
      }
      const shop = await Shop.findById(sub.shopId);
      const bonusSetting = await Settings.findOne({ key: 'referralBonusDays' });
      const bonusDays = bonusSetting ? bonusSetting.value : 30;
      return res.status(200).json({
        valid: true,
        shopName: shop?.name || 'Bilinmeyen Dükkan',
        bonusDays,
        isPromo: false,
      });
    }

    const promo = await PromoCode.findOne({ code: upperCode, isActive: true });
    if (promo) {
      if (promo.maxUsage > 0 && promo.usageCount >= promo.maxUsage) {
        return res.status(200).json({ valid: false, error: 'Bu promo kodun kullanım limiti dolmuş.' });
      }
      return res.status(200).json({
        valid: true,
        shopName: `Tanıtım Kodu: ${promo.label}`,
        bonusDays: promo.bonusDays,
        isPromo: true,
      });
    }

    return res.status(200).json({ valid: false });
  } catch (err) {
    console.error('Check referral error:', err);
    res.status(500).json({ error: 'Referans kontrolü sırasında hata.' });
  }
});

// ────────────────────────────────────────────────────────────
// GET /api/subscription/status/:shopId
// ────────────────────────────────────────────────────────────

/**
 * @swagger
 * /api/subscription/status/{shopId}:
 *   get:
 *     summary: Dükkanın abonelik durumunu kontrol et
 *     tags: [Subscription]
 *     parameters:
 *       - in: path
 *         name: shopId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Abonelik durumu
 */
router.get('/status/:shopId', async (req, res) => {
  try {
    const { shopId } = req.params;
    const subscription = await Subscription.findOne({ shopId, status: SubscriptionStatus.ACTIVE });

    if (!subscription) {
      return res.status(200).json({ isActive: false });
    }

    if (new Date() > subscription.endDate) {
      subscription.status = SubscriptionStatus.EXPIRED;
      await subscription.save();
      return res.status(200).json({ isActive: false });
    }

    res.status(200).json({
      isActive: true,
      tier: subscription.tier,
      billingPeriod: subscription.billingPeriod,
      endDate: subscription.endDate,
      referralCode: subscription.referralCode,
    });
  } catch (err) {
    console.error('Subscription status error:', err);
    res.status(500).json({ error: 'Abonelik durumu kontrol edilemedi.' });
  }
});

module.exports = router;
