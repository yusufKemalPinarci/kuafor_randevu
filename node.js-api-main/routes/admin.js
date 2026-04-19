const express = require('express');
const mongoose = require('mongoose');
const { User, UserRole } = require('../models/User');
const Shop = require('../models/Shop');
const Appointment = require('../models/Appointment');
const Service = require('../models/Service');
const { Subscription, SubscriptionTier, BillingPeriod, SubscriptionStatus } = require('../models/Subscription');
const PromoCode = require('../models/PromoCode');
const Settings = require('../models/Settings');
const AuditLog = require('../models/AuditLog');
const adminMiddleware = require('../middlewares/admin');
const router = express.Router();

function audit(req, action, targetType, targetId, details) {
  AuditLog.create({
    adminId: req.user._id,
    adminEmail: req.user.email,
    action,
    targetType,
    targetId,
    details,
  }).catch(err => console.error('Audit log error:', err));
}

/**
 * @swagger
 * tags:
 *   name: Admin
 *   description: Admin panel yönetimi
 */

// ═══════════════════════════════════════════════════════════════
// DASHBOARD & İSTATİSTİKLER
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/dashboard:
 *   get:
 *     summary: Admin dashboard istatistikleri
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 */
router.get('/dashboard', adminMiddleware, async (req, res) => {
  try {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalUsers,
      totalBarbers,
      totalCustomers,
      totalShops,
      totalAppointments,
      todayAppointments,
      monthAppointments,
      activeSubscriptions,
      expiredSubscriptions,
      totalRevenue,
      recentUsers,
      recentAppointments,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ role: 'Barber' }),
      User.countDocuments({ role: 'Customer' }),
      Shop.countDocuments(),
      Appointment.countDocuments(),
      Appointment.countDocuments({ createdAt: { $gte: todayStart } }),
      Appointment.countDocuments({ createdAt: { $gte: monthStart } }),
      Subscription.countDocuments({ status: 'active', endDate: { $gt: now } }),
      Subscription.countDocuments({ $or: [{ status: 'expired' }, { status: 'active', endDate: { $lte: now } }] }),
      Subscription.aggregate([
        { $match: { billingPeriod: { $in: ['monthly', '6month', 'yearly'] } } },
        { $group: { _id: null, total: { $sum: {
          $switch: {
            branches: [
              { case: { $eq: ['$billingPeriod', 'monthly'] }, then: 99 },
              { case: { $eq: ['$billingPeriod', '6month'] }, then: 499 },
              { case: { $eq: ['$billingPeriod', 'yearly'] }, then: 799 },
            ],
            default: 0
          }
        } } } }
      ]),
      User.find().sort({ createdAt: -1 }).limit(5).select('name email role createdAt'),
      Appointment.find().sort({ createdAt: -1 }).limit(5).select('customerName date status barberId').populate('barberId', 'name'),
    ]);

    res.json({
      stats: {
        totalUsers,
        totalBarbers,
        totalCustomers,
        totalShops,
        totalAppointments,
        todayAppointments,
        monthAppointments,
        activeSubscriptions,
        expiredSubscriptions,
        estimatedRevenue: totalRevenue[0]?.total || 0,
      },
      recentUsers,
      recentAppointments,
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    res.status(500).json({ error: 'Dashboard verileri alınamadı.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// KULLANICI YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: Tüm kullanıcıları listele (sayfalama + filtre)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 */
router.get('/users', adminMiddleware, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const { role, search } = req.query;

    const filter = {};
    if (role && ['Customer', 'Barber', 'Admin'].includes(role)) filter.role = role;
    if (search) {
      const regex = new RegExp(search, 'i');
      filter.$or = [{ name: regex }, { email: regex }, { phone: regex }];
    }

    const [users, total] = await Promise.all([
      User.find(filter, '-passwordHash -__v').sort({ createdAt: -1 }).skip(skip).limit(limit),
      User.countDocuments(filter),
    ]);

    res.json({ users, total, page, totalPages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin users error:', err);
    res.status(500).json({ error: 'Kullanıcılar alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/users/{id}:
 *   get:
 *     summary: Kullanıcı detayı
 *     tags: [Admin]
 */
router.get('/users/:id', adminMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.params.id, '-passwordHash -__v').populate('shopId');
    if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });

    // İlgili randevular ve hizmetler
    const [appointments, services] = await Promise.all([
      Appointment.find({ $or: [{ customerId: user._id }, { barberId: user._id }] })
        .sort({ createdAt: -1 }).limit(10),
      user.role === UserRole.BARBER ? Service.find({ barberId: user._id }) : Promise.resolve([]),
    ]);

    res.json({ user, appointments, services });
  } catch (err) {
    console.error('Admin user detail error:', err);
    res.status(500).json({ error: 'Kullanıcı detayı alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/users/{id}:
 *   put:
 *     summary: Kullanıcı bilgilerini güncelle (rol, isim, telefon vb.)
 *     tags: [Admin]
 */
router.put('/users/:id', adminMiddleware, async (req, res) => {
  try {
    const allowedFields = ['name', 'email', 'role', 'phone', 'bio', 'shopId'];
    const updateFields = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) updateFields[field] = req.body[field];
    }

    // Rol enum kontrolü
    if (updateFields.role && !['Customer', 'Barber', 'Admin'].includes(updateFields.role)) {
      return res.status(400).json({ error: 'Geçersiz rol.' });
    }

    const user = await User.findByIdAndUpdate(req.params.id, updateFields, { new: true, runValidators: true })
      .select('-passwordHash -__v');
    if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    audit(req, 'USER_UPDATE', 'User', user._id, { fields: updateFields });
    res.json(user);
  } catch (err) {
    console.error('Admin user update error:', err);
    res.status(500).json({ error: 'Kullanıcı güncellenemedi.' });
  }
});

/**
 * @swagger
 * /api/admin/users/{id}:
 *   delete:
 *     summary: Kullanıcıyı sil
 *     tags: [Admin]
 */
router.delete('/users/:id', adminMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });

    // Admin kendini silemez
    if (user._id.toString() === req.user._id.toString()) {
      return res.status(400).json({ error: 'Kendinizi silemezsiniz.' });
    }

    await User.findByIdAndDelete(req.params.id);
    // İlişkili verileri temizle
    await Appointment.deleteMany({ $or: [{ customerId: user._id }, { barberId: user._id }] });
    await Service.deleteMany({ barberId: user._id });

    audit(req, 'USER_DELETE', 'User', user._id, { name: user.name, email: user.email, role: user.role });
    res.json({ message: 'Kullanıcı ve ilişkili verileri silindi.' });
  } catch (err) {
    console.error('Admin user delete error:', err);
    res.status(500).json({ error: 'Kullanıcı silinemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// DÜKKAN YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/shops:
 *   get:
 *     summary: Tüm dükkanları listele (abonelik durumuyla birlikte)
 *     tags: [Admin]
 */
router.get('/shops', adminMiddleware, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const { search, city } = req.query;

    const filter = {};
    if (search) {
      const regex = new RegExp(search, 'i');
      filter.$or = [{ name: regex }, { city: regex }, { neighborhood: regex }];
    }
    if (city) filter.city = city;

    const [shops, total] = await Promise.all([
      Shop.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).populate('ownerId', 'name email'),
      Shop.countDocuments(filter),
    ]);

    // Her dükkan için abonelik durumunu ekle
    const now = new Date();
    const shopIds = shops.map(s => s._id);
    const subscriptions = await Subscription.find({ shopId: { $in: shopIds } }).sort({ createdAt: -1 });
    const subMap = {};
    for (const sub of subscriptions) {
      const sid = sub.shopId.toString();
      if (!subMap[sid]) subMap[sid] = sub; // en son abonelik
    }

    const shopsWithSub = shops.map(shop => {
      const sub = subMap[shop._id.toString()];
      const isActive = sub && sub.status === 'active' && new Date(sub.endDate) > now;
      return {
        ...shop.toObject(),
        subscription: sub ? {
          tier: sub.tier,
          billingPeriod: sub.billingPeriod,
          status: isActive ? 'active' : 'expired',
          endDate: sub.endDate,
          referralCode: sub.referralCode,
        } : null,
      };
    });

    res.json({ shops: shopsWithSub, total, page, totalPages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin shops error:', err);
    res.status(500).json({ error: 'Dükkanlar alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/shops/{id}:
 *   get:
 *     summary: Dükkan detayı (çalışanlar, abonelik, istatistik)
 *     tags: [Admin]
 */
router.get('/shops/:id', adminMiddleware, async (req, res) => {
  try {
    const shop = await Shop.findById(req.params.id).populate('ownerId', 'name email phone');
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });

    const [staff, subscription, appointmentCount] = await Promise.all([
      User.find({ shopId: shop._id, role: 'Barber' }, 'name email phone'),
      Subscription.findOne({ shopId: shop._id }).sort({ createdAt: -1 }),
      Appointment.countDocuments({ barberId: { $in: (await User.find({ shopId: shop._id })).map(u => u._id) } }),
    ]);

    res.json({ shop, staff, subscription, appointmentCount });
  } catch (err) {
    console.error('Admin shop detail error:', err);
    res.status(500).json({ error: 'Dükkan detayı alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/shops/{id}:
 *   put:
 *     summary: Dükkan bilgilerini güncelle
 *     tags: [Admin]
 */
router.put('/shops/:id', adminMiddleware, async (req, res) => {
  try {
    const allowedFields = ['name', 'fullAddress', 'neighborhood', 'city', 'district', 'phone', 'openingHour', 'closingHour', 'workingDays'];
    const updateFields = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) updateFields[field] = req.body[field];
    }

    const shop = await Shop.findByIdAndUpdate(req.params.id, updateFields, { new: true, runValidators: true });
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });
    audit(req, 'SHOP_UPDATE', 'Shop', shop._id, { fields: updateFields });
    res.json(shop);
  } catch (err) {
    console.error('Admin shop update error:', err);
    res.status(500).json({ error: 'Dükkan güncellenemedi.' });
  }
});

/**
 * @swagger
 * /api/admin/shops/{id}:
 *   delete:
 *     summary: Dükkanı sil (ilişkili verilerle birlikte)
 *     tags: [Admin]
 */
router.delete('/shops/:id', adminMiddleware, async (req, res) => {
  try {
    const shop = await Shop.findById(req.params.id);
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });

    // Dükkan çalışanlarının shopId'sini temizle
    await User.updateMany({ shopId: shop._id }, { $set: { shopId: null } });
    // İlişkili abonelikleri sil
    await Subscription.deleteMany({ shopId: shop._id });
    // Dükkanı sil
    await Shop.findByIdAndDelete(shop._id);

    audit(req, 'SHOP_DELETE', 'Shop', shop._id, { name: shop.name, city: shop.city });
    res.json({ message: 'Dükkan ve ilişkili verileri silindi.' });
  } catch (err) {
    console.error('Admin shop delete error:', err);
    res.status(500).json({ error: 'Dükkan silinemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// ABONELİK YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/subscriptions:
 *   get:
 *     summary: Tüm abonelikleri listele
 *     tags: [Admin]
 */
router.get('/subscriptions', adminMiddleware, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const { status } = req.query;

    const filter = {};
    if (status && ['active', 'expired', 'cancelled'].includes(status)) filter.status = status;

    const now = new Date();

    const [subscriptions, total] = await Promise.all([
      Subscription.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('shopId', 'name city')
        .populate('ownerId', 'name email'),
      Subscription.countDocuments(filter),
    ]);

    // Süresi geçmiş ama hâlâ active olanları güncelle
    for (const sub of subscriptions) {
      if (sub.status === 'active' && new Date(sub.endDate) <= now) {
        sub.status = 'expired';
        await sub.save();
      }
    }

    res.json({ subscriptions, total, page, totalPages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin subscriptions error:', err);
    res.status(500).json({ error: 'Abonelikler alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/subscriptions/{id}/extend:
 *   put:
 *     summary: Abonelik süresini uzat
 *     tags: [Admin]
 */
router.put('/subscriptions/:id/extend', adminMiddleware, async (req, res) => {
  try {
    const { days } = req.body;
    if (!days || days < 1 || days > 365) {
      return res.status(400).json({ error: 'Geçerli gün sayısı girin (1-365).' });
    }

    const sub = await Subscription.findById(req.params.id);
    if (!sub) return res.status(404).json({ error: 'Abonelik bulunamadı.' });

    // Mevcut bitiş tarihinden veya şimdi'den (hangisi ilerideyse) uzat
    const baseDate = new Date(sub.endDate) > new Date() ? new Date(sub.endDate) : new Date();
    baseDate.setDate(baseDate.getDate() + parseInt(days));
    sub.endDate = baseDate;
    sub.status = SubscriptionStatus.ACTIVE;
    await sub.save();

    audit(req, 'SUBSCRIPTION_EXTEND', 'Subscription', sub._id, { days, newEndDate: baseDate, shopId: sub.shopId });
    res.json(sub);
  } catch (err) {
    console.error('Admin extend subscription error:', err);
    res.status(500).json({ error: 'Abonelik uzatılamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/subscriptions/{id}/cancel:
 *   put:
 *     summary: Aboneliği iptal et
 *     tags: [Admin]
 */
router.put('/subscriptions/:id/cancel', adminMiddleware, async (req, res) => {
  try {
    const sub = await Subscription.findById(req.params.id);
    if (!sub) return res.status(404).json({ error: 'Abonelik bulunamadı.' });

    sub.status = SubscriptionStatus.CANCELLED;
    await sub.save();
    audit(req, 'SUBSCRIPTION_CANCEL', 'Subscription', sub._id, { shopId: sub.shopId });
    res.json(sub);
  } catch (err) {
    console.error('Admin cancel subscription error:', err);
    res.status(500).json({ error: 'Abonelik iptal edilemedi.' });
  }
});

/**
 * @swagger
 * /api/admin/subscriptions/grant:
 *   post:
 *     summary: Dükkan sahibine ücretsiz abonelik ver
 *     tags: [Admin]
 */
router.post('/subscriptions/grant', adminMiddleware, async (req, res) => {
  try {
    const { shopId, days } = req.body;
    if (!shopId || !days) return res.status(400).json({ error: 'shopId ve days gerekli.' });

    const shop = await Shop.findById(shopId);
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });

    // Mevcut aktif abonelik varsa uzat
    const existing = await Subscription.findOne({ shopId, status: SubscriptionStatus.ACTIVE });
    if (existing) {
      const baseDate = new Date(existing.endDate) > new Date() ? new Date(existing.endDate) : new Date();
      baseDate.setDate(baseDate.getDate() + parseInt(days));
      existing.endDate = baseDate;
      await existing.save();
      audit(req, 'SUBSCRIPTION_GRANT_EXTEND', 'Subscription', existing._id, { shopId, days, newEndDate: baseDate });
      return res.json(existing);
    }

    // Yoksa yeni oluştur
    const crypto = require('crypto');
    let referralCode = crypto.randomBytes(4).toString('hex').toUpperCase();
    while (await Subscription.findOne({ referralCode })) {
      referralCode = crypto.randomBytes(4).toString('hex').toUpperCase();
    }

    const endDate = new Date();
    endDate.setDate(endDate.getDate() + parseInt(days));

    const tier = req.body.tier || SubscriptionTier.STANDART;
    const sub = new Subscription({
      shopId,
      ownerId: shop.ownerId,
      tier,
      billingPeriod: BillingPeriod.FREE_TRIAL,
      status: SubscriptionStatus.ACTIVE,
      startDate: new Date(),
      endDate,
      referralCode,
      referredBy: 'ADMIN_GRANT',
    });
    await sub.save();

    audit(req, 'SUBSCRIPTION_GRANT_NEW', 'Subscription', sub._id, { shopId, days, endDate });
    res.status(201).json(sub);
  } catch (err) {
    console.error('Admin grant subscription error:', err);
    res.status(500).json({ error: 'Abonelik verilemedi.' });
  }
});

/**
 * @swagger
 * /api/admin/subscriptions/expire-all:
 *   post:
 *     summary: Süresi dolmuş tüm abonelikleri toplu olarak expire et
 *     tags: [Admin]
 */
router.post('/subscriptions/expire-all', adminMiddleware, async (req, res) => {
  try {
    const result = await Subscription.updateMany(
      { status: SubscriptionStatus.ACTIVE, endDate: { $lt: new Date() } },
      { $set: { status: SubscriptionStatus.EXPIRED } }
    );
    audit(req, 'SUBSCRIPTION_BULK_EXPIRE', 'Subscription', null, { expiredCount: result.modifiedCount });
    res.json({ message: `${result.modifiedCount} abonelik expire edildi.`, count: result.modifiedCount });
  } catch (err) {
    console.error('Bulk expire error:', err);
    res.status(500).json({ error: 'Toplu expire işlemi başarısız.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// RANDEVU YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/appointments:
 *   get:
 *     summary: Tüm randevuları listele
 *     tags: [Admin]
 */
router.get('/appointments', adminMiddleware, async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const { status, barberId, date } = req.query;

    const filter = {};
    if (status && ['pending', 'confirmed', 'cancelled'].includes(status)) filter.status = status;
    if (barberId) filter.barberId = barberId;
    if (date) {
      const d = new Date(date);
      const nextDay = new Date(d);
      nextDay.setDate(nextDay.getDate() + 1);
      filter.date = { $gte: d, $lt: nextDay };
    }

    const [appointments, total] = await Promise.all([
      Appointment.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('barberId', 'name email')
        .populate('serviceId', 'title price durationMinutes')
        .populate('customerId', 'name email phone'),
      Appointment.countDocuments(filter),
    ]);

    res.json({ appointments, total, page, totalPages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin appointments error:', err);
    res.status(500).json({ error: 'Randevular alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/appointments/{id}:
 *   put:
 *     summary: Randevu durumunu güncelle
 *     tags: [Admin]
 */
router.put('/appointments/:id', adminMiddleware, async (req, res) => {
  try {
    const { status, notes } = req.body;
    const updateFields = {};
    if (status && ['pending', 'confirmed', 'cancelled'].includes(status)) updateFields.status = status;
    if (notes !== undefined) updateFields.notes = notes;

    const appt = await Appointment.findByIdAndUpdate(req.params.id, updateFields, { new: true })
      .populate('barberId', 'name')
      .populate('serviceId', 'title');
    if (!appt) return res.status(404).json({ error: 'Randevu bulunamadı.' });
    audit(req, 'APPOINTMENT_UPDATE', 'Appointment', appt._id, { fields: updateFields });
    res.json(appt);
  } catch (err) {
    console.error('Admin appointment update error:', err);
    res.status(500).json({ error: 'Randevu güncellenemedi.' });
  }
});

/**
 * @swagger
 * /api/admin/appointments/{id}:
 *   delete:
 *     summary: Randevuyu sil
 *     tags: [Admin]
 */
router.delete('/appointments/:id', adminMiddleware, async (req, res) => {
  try {
    const appt = await Appointment.findByIdAndDelete(req.params.id);
    if (!appt) return res.status(404).json({ error: 'Randevu bulunamadı.' });
    audit(req, 'APPOINTMENT_DELETE', 'Appointment', appt._id, { barberId: appt.barberId, date: appt.date });
    res.json({ message: 'Randevu silindi.' });
  } catch (err) {
    console.error('Admin appointment delete error:', err);
    res.status(500).json({ error: 'Randevu silinemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// HİZMET YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

/**
 * @swagger
 * /api/admin/services:
 *   get:
 *     summary: Tüm hizmetleri listele
 *     tags: [Admin]
 */
router.get('/services', adminMiddleware, async (req, res) => {
  try {
    const services = await Service.find()
      .sort({ createdAt: -1 })
      .populate('barberId', 'name email');
    res.json(services);
  } catch (err) {
    console.error('Admin services error:', err);
    res.status(500).json({ error: 'Hizmetler alınamadı.' });
  }
});

/**
 * @swagger
 * /api/admin/services/{id}:
 *   delete:
 *     summary: Hizmeti sil
 *     tags: [Admin]
 */
router.delete('/services/:id', adminMiddleware, async (req, res) => {
  try {
    const service = await Service.findByIdAndDelete(req.params.id);
    if (!service) return res.status(404).json({ error: 'Hizmet bulunamadı.' });
    audit(req, 'SERVICE_DELETE', 'Appointment', service._id, { title: service.title, barberId: service.barberId });
    res.json({ message: 'Hizmet silindi.' });
  } catch (err) {
    console.error('Admin service delete error:', err);
    res.status(500).json({ error: 'Hizmet silinemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// AYARLAR
// ═══════════════════════════════════════════════════════════════

// Tüm ayarları obje olarak getir
router.get('/settings', adminMiddleware, async (req, res) => {
  try {
    const docs = await Settings.find();
    const result = {};
    for (const d of docs) result[d.key] = d.value;
    // Varsayılanlar
    if (result.referralBonusDays === undefined) result.referralBonusDays = 30;
    if (result.referralCodeValidDays === undefined) result.referralCodeValidDays = 0; // 0 = sonsuz
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: 'Ayarlar alınamadı.' });
  }
});

// Ayar güncelle (key-value olarak gönder)
router.put('/settings', adminMiddleware, async (req, res) => {
  try {
    const updates = req.body; // { referralBonusDays: 45 }
    for (const [key, value] of Object.entries(updates)) {
      await Settings.findOneAndUpdate(
        { key },
        { value },
        { upsert: true, new: true }
      );
    }
    audit(req, 'SETTINGS_UPDATE', 'Shop', null, { changes: updates });
    const docs = await Settings.find();
    const result = {};
    for (const d of docs) result[d.key] = d.value;
    if (result.referralBonusDays === undefined) result.referralBonusDays = 30;
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: 'Ayarlar kaydedilemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// PROMO KOD YÖNETİMİ
// ═══════════════════════════════════════════════════════════════

// Tüm promo kodları listele
router.get('/promo-codes', adminMiddleware, async (req, res) => {
  try {
    const codes = await PromoCode.find()
      .sort({ createdAt: -1 })
      .populate('createdBy', 'name email');
    res.json(codes);
  } catch (err) {
    console.error('Promo codes list error:', err);
    res.status(500).json({ error: 'Promo kodlar alınamadı.' });
  }
});

// Yeni promo kod oluştur
router.post('/promo-codes', adminMiddleware, async (req, res) => {
  try {
    const { code, label, bonusDays, maxUsage } = req.body;
    if (!code || !label) return res.status(400).json({ error: 'Kod ve etiket gerekli.' });

    const upperCode = code.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (upperCode.length < 3) return res.status(400).json({ error: 'Kod en az 3 karakter olmalı.' });

    const existing = await PromoCode.findOne({ code: upperCode });
    if (existing) return res.status(400).json({ error: 'Bu kod zaten kullanılıyor.' });

    // Aynı kod subscription referral olarak da kullanılmış olabilir
    const existingSub = await Subscription.findOne({ referralCode: upperCode });
    if (existingSub) return res.status(400).json({ error: 'Bu kod bir abonelik referans kodu olarak kullanılıyor.' });

    const promo = new PromoCode({
      code: upperCode,
      label,
      bonusDays: bonusDays || 30,
      maxUsage: maxUsage || 0,
      createdBy: req.user._id,
    });
    await promo.save();
    audit(req, 'PROMO_CREATE', 'PromoCode', promo._id, { code: upperCode, label, bonusDays: bonusDays || 30 });
    res.status(201).json(promo);
  } catch (err) {
    console.error('Promo code create error:', err);
    res.status(500).json({ error: 'Promo kod oluşturulamadı.' });
  }
});

// Promo kodu sil
router.delete('/promo-codes/:id', adminMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: 'Geçersiz ID formatı.' });
    }
    const promo = await PromoCode.findByIdAndDelete(req.params.id);
    if (!promo) return res.status(404).json({ error: 'Promo kod bulunamadı.' });
    audit(req, 'PROMO_DELETE', 'PromoCode', promo._id, { code: promo.code });
    res.json({ message: 'Promo kod silindi.' });
  } catch (err) {
    console.error('Promo code delete error:', err);
    res.status(500).json({ error: 'Promo kod silinemedi.' });
  }
});

// Promo kod aktif/pasif toggle
router.put('/promo-codes/:id/toggle', adminMiddleware, async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ error: 'Geçersiz ID formatı.' });
    }
    const promo = await PromoCode.findById(req.params.id);
    if (!promo) return res.status(404).json({ error: 'Promo kod bulunamadı.' });
    promo.isActive = !promo.isActive;
    await promo.save();
    audit(req, 'PROMO_TOGGLE', 'PromoCode', promo._id, { code: promo.code, isActive: promo.isActive });
    res.json(promo);
  } catch (err) {
    console.error('Promo code toggle error:', err);
    res.status(500).json({ error: 'Promo kod güncellenemedi.' });
  }
});

// Bir kodu kullanan dükkanları getir
router.get('/promo-codes/:code/usages', adminMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const subscriptions = await Subscription.find({ referredBy: code })
      .populate('shopId', 'name city neighborhood fullAddress')
      .populate('ownerId', 'name email phone')
      .sort({ createdAt: -1 });
    res.json(subscriptions);
  } catch (err) {
    console.error('Promo code usages error:', err);
    res.status(500).json({ error: 'Kullanım detayları alınamadı.' });
  }
});

module.exports = router;
