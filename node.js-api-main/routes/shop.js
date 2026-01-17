const express = require('express');
const Shop = require('../models/Shop');
const { User } = require('../models/User');
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
      staffEmails     // yeni alan
    } = req.body;
    const ownerId = req.user._id; 
    const owner = await User.findById(ownerId);
    const ownerEmail = owner?.email;
       // Sahip mailini staff listesine otomatik ekle
    if (ownerEmail && !staffEmails.includes(ownerEmail)) {
      staffEmails.push(ownerEmail);
    }
    const shop = new Shop({
      name,
      fullAddress,
      neighborhood,
      city,
      phone,
      adress,
      openingHour,
      closingHour,
      workingDays,
      ownerId,
      staffEmails
    });

    await shop.save();
    res.status(201).json(shop);
  } catch (err) {
   console.error('Shop create error:', err.message, err);
   res.status(500).json({ error: 'Something went wrong', details: err.message });

  }
});






/**
 * @swagger
 * /api/shop/by-staff-email:
 *   get:
 *     summary: Çalışana ait dükkanları listele
 *     tags: [Shop]
 *     parameters:
 *       - in: query
 *         name: email
 *         schema:
 *           type: string
 *         required: true
 *     responses:
 *       200:
 *         description: Dükkanlar listelendi
 *       400:
 *         description: Email eksik
 *       500:
 *         description: Sunucu hatası
 */
// Çalışana Ait Dükkanları listele      //berber için lazım
// GET /api/shop/by-staff-email?email=test@example.com
router.get('/by-staff-email', async (req, res) => {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const shops = await Shop.find({ staffEmails: email });

    res.json(shops);
  } catch (err) {
    console.error('Error fetching shops by staff email:', err);
    res.status(500).json({ error: 'Something went wrong' });
  }
});


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
// dükkanda çalışan kişileri listelemek için 
router.get('/:shopId/staff', async (req, res) => {
  try {
    const shopId = req.params.shopId;

    const shop = await Shop.findById(shopId);
    if (!shop) {
      return res.status(404).json({ error: 'Dükkan bulunamadı' });
    }

    // Tüm e-posta adreslerini al (string filtrele)
    const staffEmails = (shop.staffEmails || []).filter(email => typeof email === 'string');

    // Bu e-posta adreslerine sahip ve rolü 'Barber' olan, shopId ile eşleşen kullanıcıları getir
      const users = await User.find(
      {
        role: 'Barber',
        $or: [
          { email: { $in: staffEmails } },
          { shopId: shopId }
        ]
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
    const { city, neighborhood} = req.query;

    // Filtre objesi oluşturuyoruz, varsa ekliyoruz
    const filter = {};
    if (city) filter.city = city;
    if (neighborhood) filter.neighborhood = neighborhood;

    // Filtreye göre Shop'ları getir
    const shops = await Shop.find(filter);

    res.json(shops);
  } catch (err) {
    console.error('Error searching shops:', err);
    res.status(500).json({ error: 'Something went wrong' });
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

// Tüm dükkanları getir (genel listeleme)    // Müşteri tarafında lazım
router.get('/', async (req, res) => {
  try {
    const shops = await Shop.find();
    res.json(shops);
  } catch (err) {
    console.error('Error fetching all shops:', err);
    res.status(500).json({ error: 'Something went wrong' });
  }
});



/**
 * @swagger
 * /api/shop/{id}/add-staff:
 *   put:
 *     summary: Dükkan çalışanı ekle
 *     tags: [Shop]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *     responses:
 *       200:
 *         description: Çalışan eklendi
 *       400:
 *         description: Hatalı giriş
 *       500:
 *         description: Sunucu hatası
 */
//dükkana çalışan ekleme          // Dükkan sahibi tarafında lazım.
// PUT /api/shop/:id/add-staff
router.put('/:id/add-staff', async (req, res) => {
  try {
    let { email } = req.body;
    email = email.toLowerCase(); // artık hata yok

    if (!email) {
      return res.status(400).json({ message: 'Email is required' });
    }

    const shop = await Shop.findById(req.params.id);
    if (!shop) {
      return res.status(404).json({ message: 'Shop not found' });
    }

    if (shop.staffEmails.includes(email)) {
      return res.status(400).json({ message: 'This email is already added as staff.' });
    }

    shop.staffEmails.push(email);
    await shop.save();

    res.status(200).json({ message: 'Staff added successfully', shop });
  } catch (error) {
    console.error('Error adding staff:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});





module.exports = router;
