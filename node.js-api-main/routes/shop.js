const express = require('express');
const Shop = require('../models/Shop');
const { User } = require('../models/User');
const { Subscription, SubscriptionStatus } = require('../models/Subscription');
const authMiddleware = require('../middlewares/auth');
const router = express.Router();




/**
 * @swagger
 * tags:
 *   name: Shop
 *   description: Dükkan yönetimi
 */

/**
 * @swagger
 * /api/shop:
 *   post:
 *     summary: Yeni bir dükkan oluştur
 *     tags: [Shop]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               fullAddress:
 *                 type: string
 *               neighborhood:
 *                 type: string
 *               city:
 *                 type: string
 *               phone:
 *                 type: string
 *               adress:
 *                 type: string
 *               openingHour:
 *                 type: string
 *               closingHour:
 *                 type: string
 *               workingDays:
 *                 type: array
 *                 items:
 *                   type: string
 *               staffEmails:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       201:
 *         description: Dükkan oluşturuldu
 *       500:
 *         description: Sunucu hatası
 */

// Create Shop
router.post('/',authMiddleware, async (req, res) => {
  try {
    const {
      name,
      fullAddress,
      neighborhood,
      city,
      phone,
      adress,
      openingHour,
      closingHour,
      workingDays,
    } = req.body;
    
    const ownerId = req.user._id; 
    
    // Rastgele 6 haneli eşsiz kod üret (Örn: A8B2X9)
    const generateCode = () => Math.random().toString(36).substring(2, 8).toUpperCase();
    let shopCode = generateCode();
    
    // Kod çakışması çok düşük ihtimal ama yine de kontrol edelim
    while(await Shop.findOne({ shopCode })) {
      shopCode = generateCode();
    }

    const shop = new Shop({
      name,
      shopCode,
      fullAddress,
      neighborhood,
      city,
      phone,
      adress,
      openingHour,
      closingHour,
      workingDays,
      ownerId,
    });

    await shop.save();
    
    // Dükkanı kuran kişiyi otomatik olarak bu dükkana bağla
    await User.findByIdAndUpdate(ownerId, { shopId: shop._id });

    // Güncel User bilgisini de dönmek mantıklı
    const updatedUser = await User.findById(ownerId);

    res.status(201).json({ shop, user: updatedUser });
  } catch (err) {
   console.error('Shop create error:', err.message, err);
   res.status(500).json({ error: 'Something went wrong', details: err.message });
  }
});

/**
 * @swagger
 * /api/shop/join:
 *   post:
 *     summary: Davet kodu ile dükkana katıl
 *     tags: [Shop]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               shopCode:
 *                 type: string
 *     responses:
 *       200:
 *         description: Dükkana başarıyla katılındı
 *       404:
 *         description: Geçersiz dükkan kodu
 */
// Davet kodu ile dükkana katıl
router.post('/join', authMiddleware, async (req, res) => {
  try {
    const { shopCode } = req.body;
    if (!shopCode) {
      return res.status(400).json({ error: 'Shop code is required' });
    }

    // Koda göre dükkanı bul
    const shop = await Shop.findOne({ shopCode: shopCode.toUpperCase() });
    if (!shop) {
      return res.status(404).json({ error: 'Bu koda sahip bir dükkan bulunamadı.' });
    }

    // Kullanıcının dükkanını güncelle
    req.user.shopId = shop._id;
    await req.user.save();

    res.status(200).json({ message: 'Dükkana başarıyla katılındı', shop, user: req.user });
  } catch (err) {
    console.error('Error joining shop:', err);
    res.status(500).json({ error: 'Dükkana katılırken bir hata oluştu.' });
  }
});






// Eski /by-staff-email rotası kapatıldı. Çünkü artık staffEmails üzerinden ilişki kurmuyoruz.


/**
 * @swagger
 * /api/shop/{id}:
 *   get:
 *     summary: Dükkan detaylarını getir
 *     tags: [Shop]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Dükkan bulundu
 *       404:
 *         description: Dükkan bulunamadı
 *       500:
 *         description: Sunucu hatası
 */
// Dükkanı shopCode ile getirme (public, deep link için)
router.get('/by-code/:shopCode', async (req, res) => {
  try {
    const shop = await Shop.findOne({ shopCode: req.params.shopCode.toUpperCase() });
    if (!shop) return res.status(404).json({ error: 'Dükkan bulunamadı.' });
    res.status(200).json(shop);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

//Dükkanı id sine göre bilgilerini getirme   // hem müşteri hem berber tarafında lazım.
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const shop = await Shop.findById(id);

    if (!shop) {
      return res.status(404).json({ error: 'Shop not found' });
    }

    res.status(200).json(shop);
  } catch (err) {
    console.error('Shop fetch error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


/**
 * @swagger
 * /api/shop/{shopId}/staff:
 *   get:
 *     summary: Dükkan çalışanlarını listele
 *     tags: [Shop]
 *     parameters:
 *       - in: path
 *         name: shopId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Çalışanlar listelendi
 *       404:
 *         description: Dükkan bulunamadı
 *       500:
 *         description: Sunucu hatası
 */
// dükkanda çalışan kişileri listelemek için (Sadece shopId referansıyla çekilecek)
router.get('/:shopId/staff', async (req, res) => {
  try {
    const shopId = req.params.shopId;

    const shop = await Shop.findById(shopId);
    if (!shop) {
      return res.status(404).json({ error: 'Dükkan bulunamadı' });
    }

    // Role Berber olan ve bu dükkana bağlı olan herkesi getir.
    const users = await User.find(
      {
        role: 'Barber',
        shopId: shopId
      },
      '-passwordHash -__v'
    );

    res.status(200).json(users);
  } catch (error) {
    console.error('Hata:', error);
    res.status(500).json({ error: 'Sunucu hatası', details: error.message });
  }
});


/**
 * @swagger
 * /api/shop/search:
 *   get:
 *     summary: Dükkanları filtrele
 *     tags: [Shop]
 *     parameters:
 *       - in: query
 *         name: city
 *         schema:
 *           type: string
 *       - in: query
 *         name: neighborhood
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Filtrelenmiş dükkan listesi
 *       500:
 *         description: Sunucu hatası
 */
// Query ile dükkanları filtrele     // Müşteri tarafında lazım arama butonu için
// GET /api/shop/search?city=Istanbul&neighborhood=Kadikoy&district=Moda
router.get('/search', async (req, res) => {
  try {
    const { city, district, neighborhood } = req.query;

    const filter = {};
    if (city) filter.city = { $regex: new RegExp(city, 'i') };
    if (district) filter.district = { $regex: new RegExp(district, 'i') };
    if (neighborhood) filter.neighborhood = { $regex: new RegExp(neighborhood, 'i') };

    // Aktif aboneliği olan dükkanları filtrele
    const now = new Date();
    const activeSubscriptions = await Subscription.find({
      status: SubscriptionStatus.ACTIVE,
      endDate: { $gt: now },
    }).select('shopId');
    const activeShopIds = activeSubscriptions.map(s => s.shopId);
    filter._id = { $in: activeShopIds };

    const shops = await Shop.find(filter);
    res.json(shops);
  } catch (err) {
    console.error('Error searching shops:', err);
    res.status(500).json({ error: 'Something went wrong' });
  }
});


// Dükkanı güncelle
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const shop = await Shop.findById(id);
    
    if (!shop) {
      return res.status(404).json({ error: 'Shop not found' });
    }

    // Only the owner can edit the shop
    if (shop.ownerId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Only the shop owner can edit this shop' });
    }

    const allowedFields = ['name', 'fullAddress', 'neighborhood', 'city', 'district', 'phone', 'adress', 'openingHour', 'closingHour', 'workingDays', 'autoConfirmAppointments'];
    const updateFields = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updateFields[field] = req.body[field];
      }
    }

    const updatedShop = await Shop.findByIdAndUpdate(id, updateFields, { new: true, runValidators: true });
    res.json(updatedShop);
  } catch (err) {
    console.error('Shop update error:', err);
    res.status(500).json({ error: 'Shop update failed', details: err.message });
  }
});


/**
 * @swagger
 * /api/shop:
 *   get:
 *     summary: Tüm dükkanları getir
 *     tags: [Shop]
 *     responses:
 *       200:
 *         description: Dükkan listesi
 *       500:
 *         description: Sunucu hatası
 */

// Tüm dükkanları getir (sadece aktif aboneliği olanlar)    // Müşteri tarafında lazım
router.get('/', async (req, res) => {
  try {
    const { city, district } = req.query;

    // Aktif aboneliği olan dükkanların ID'lerini bul
    const now = new Date();
    const activeSubscriptions = await Subscription.find({
      status: SubscriptionStatus.ACTIVE,
      endDate: { $gt: now },
    }).select('shopId');

    const activeShopIds = activeSubscriptions.map(s => s.shopId);

    const filter = { _id: { $in: activeShopIds } };
    if (city) filter.city = { $regex: new RegExp(city, 'i') };
    if (district) filter.district = { $regex: new RegExp(district, 'i') };

    // Sadece aktif aboneliği olan dükkanları getir
    const shops = await Shop.find(filter);
    res.json(shops);
  } catch (err) {
    console.error('Error fetching all shops:', err);
    res.status(500).json({ error: 'Something went wrong' });
  }
});



// Eski /:id/add-staff (email ekeleme) rotası yeni yapıda gerekmediği için kaldırıldı.





module.exports = router;
