const express = require('express');
const bcrypt = require('bcrypt');
const { User, UserRole } = require('../models/User');
const { generateToken } = require('../helpers/jwtService');
const authMiddleware = require('../middlewares/auth');
const router = express.Router();


/**
 * @swagger
 * tags:
 *   - name: User
 *     description: Kullanıcı işlemleri
 */

/**
 * @swagger
 * /api/user/register:
 *   post:
 *     summary: Yeni kullanıcı kaydı
 *     tags: [User]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: "Ahmet"
 *               email:
 *                 type: string
 *                 example: "ahmet@example.com"
 *               password:
 *                 type: string
 *                 example: "123456"
 *               role:
 *                 type: string
 *                 example: "BARBER"
 *               phone:
 *                 type: string
 *               shopId:
 *                 type: string
 *               services:
 *                 type: array
 *                 items:
 *                   type: string
 *               availability:
 *                 type: array
 *                 items:
 *                   type: object
 *               bio:
 *                 type: string
 *     responses:
 *       200:
 *         description: Kullanıcı başarıyla oluşturuldu
 *       400:
 *         description: Email zaten kullanılıyor
 */

router.post('/register', async (req, res) => {
  try {
    let { name, email, password, role, phone, shopId, availability, services, bio } = req.body;

    email = email.toLowerCase();
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ error: 'Email already in use' });

    const passwordHash = await bcrypt.hash(password, 10);

    let userData = {
      name,
      email,
      passwordHash,
      role: role || UserRole.CUSTOMER,
      phone: phone || '',
      shopId: shopId || null,
      bio: bio || '',
    };

    // Barber ise availability ve services opsiyonel eklenebilir
    if (role === UserRole.BARBER) {
      if (services) userData.services = services;
      if (availability) userData.availability = availability; // boş gelse de sorun olmaz
    }

    let user = new User(userData);
    await user.save();

    res.json({
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});


/**
 * @swagger
 * /api/user/me:
 *   get:
 *     summary: JWT ile oturum açmış kullanıcının bilgilerini döner
 *     tags: [User]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Kullanıcı bilgisi
 */

router.get('/me', authMiddleware, async (req, res) => {
  try {
    res.status(200).json(req.user);
  } catch (error) {
    console.error('Kullanıcı bilgisi getirme hatası:', error);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});



/**
 * @swagger
 * /api/user/{id}:
 *   get:
 *     summary: Kullanıcı bilgisi (ID ile)
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Kullanıcı bulundu
 *       404:
 *         description: Kullanıcı bulunamadı
 */
router.get('/:id', async (req, res) => {
  try {
    const userId = req.params.id;

    const user = await User.findById(userId).select('-passwordHash -__v'); // şifreyi ve gereksiz alanları çıkar
    if (!user) {
      return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
    }

    res.status(200).json(user);
  } catch (error) {
    console.error('Kullanıcı getirme hatası:', error);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});



/**
 * @swagger
 * /api/user/barber/availability/{id}:
 *   put:
 *     summary: Berberin belirli ID'li müsaitliklerini güncelle
 *     tags: [User]
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
 *               availability:
 *                 type: array
 *     responses:
 *       200:
 *         description: Güncellendi
 */
router.put('/barber/availability/:id', async (req, res) => {
  try {
    const { availability } = req.body;

    if (!availability || !Array.isArray(availability)) {
      return res.status(400).json({ error: 'Availability must be an array' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { availability },
      { new: true }
    );

    if (!user) return res.status(404).json({ error: 'User not found' });

    res.json({ message: 'Availability updated', availability: user.availability });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/**
 * @swagger
 * /login:
 *   post:
 *     summary: Kullanıcı girişi yap
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 example: "user@example.com"
 *               password:
 *                 type: string
 *                 example: "mypassword123"
 *     responses:
 *       200:
 *         description: Giriş başarılı
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                   example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *                 user:
 *                   type: object
 *                   description: Kullanıcı bilgileri
 *                   properties:
 *                     _id:
 *                       type: string
 *                       example: "60d0fe4f5311236168a109ca"
 *                     email:
 *                       type: string
 *                       example: "user@example.com"
 *                     name:
 *                       type: string
 *                       example: "John Doe"
 *       400:
 *         description: Geçersiz email veya şifre
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Invalid email or password"
 *       500:
 *         description: Sunucu hatası
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Something went wrong"
 */

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    email = email.toLowerCase(); 
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ error: 'Invalid email or password' });

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return res.status(400).json({ error: 'Invalid email or password' });

    const token = generateToken(user);

    res.json({
      token,
      user
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});







/**
 * @swagger
 * /api/user/select-shop:
 *   post:
 *     summary: Kullanıcıya shop seçtir
 *     tags: [User]
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
 *     responses:
 *       200:
 *         description: Shop seçildi
 */

router.post('/select-shop', authMiddleware, async (req, res) => {
  try {
    const { shopId } = req.body;

    if (!shopId) return res.status(400).json({ error: 'shopId is required' });

    const user = req.user;
    user.shopId = shopId;
    await user.save();

    res.json({
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        //isEmailVerified: false, // veya kendi verine göre
        //phone: '',              // varsayılan değer
        //isPhoneVerified: false,
        //avatarUrl: null,
        shopId: user.shopId,
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/user/leave-shop:
 *   post:
 *     summary: Kullanıcı shoptan ayrılır
 *     tags: [User]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Başarılı çıkış
 */

router.post('/leave-shop', authMiddleware, async (req, res) => {
  try {
    const user = req.user;

    if (!user.shopId) {
      return res.status(400).json({ error: 'User is not assigned to any shop' });
    }

    user.shopId = null; // veya undefined de olabilir
    await user.save();

    res.json({
      message: 'Successfully left the shop',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        shopId: user.shopId,
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});




/**
 * @swagger
 * /api/user/{id}/phone:
 *   put:
 *     summary: Kullanıcı telefon numarasını güncelle
 *     tags: [User]
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
 *               phone:
 *                 type: string
 *     responses:
 *       200:
 *         description: Telefon güncellendi
 */
// usera telefeon ekleme
router.put('/:id/phone', async (req, res) => {
  try {
    const { phone } = req.body;

    // Telefon numarası kontrolü
    if (!phone || phone.trim() === '') {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { phone },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ message: 'Phone updated successfully', phone: user.phone });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


router.put('/shop', authMiddleware, async (req, res) => {
  try {
    const { shopId } = req.body;

    if (!shopId) {
      return res.status(400).json({ error: 'shopId is required' });
    }

    // JWT token'dan userId geliyor
    const userId = req.user.id;

    const user = await User.findByIdAndUpdate(
      userId,
      { shopId },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      message: 'Shop ID updated successfully',
      shopId: user.shopId
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * @swagger
 * /api/user/exists:
 *   get:
 *     summary: Email var mı kontrolü
 *     tags: [User]
 *     parameters:
 *       - in: query
 *         name: email
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Email var mı bilgisi döner
 */
// /api/user/exists?email=xxx@example.com
router.get('/exists', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ exists: false });

  const user = await User.findOne({ email: email.toLowerCase() });
  res.json({ exists: !!user });
});





/**
 * @swagger
 * /api/user:
 *   get:
 *     summary: Tüm kullanıcıları listeler
 *     tags: [User]
 *     responses:
 *       200:
 *         description: Kullanıcı listesi
 */
router.get('/', async (req, res) => {
  const users = await User.find().select('-passwordHash');
  res.json(users);
});





/**
 * @swagger
 * /api/user/profile:
 *   put:
 *     summary: Berber profilini güncelle
 *     tags: [User]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               phone:
 *                 type: string
 *               bio:
 *                 type: string
 *               availability:
 *                 type: array
 *     responses:
 *       200:
 *         description: Profil güncellendi
 */

// PUT /api/user/profile
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Only barbers can update this' });
    }

    const { phone, bio, availability } = req.body;

    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      { phone, bio, availability },
      { new: true }
    ).select('-passwordHash');

    res.json(updatedUser);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});






/**
 * @swagger
 * /api/user/{id}/availability:
 *   get:
 *     summary: Berberin müsaitlik bilgisini döner
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Müsaitlik bilgisi
 */


// GET /api/user/:id/availability
router.get('/:id/availability', async (req, res) => {
  try {
    const barber = await User.findById(req.params.id).select('availability role');

    if (!barber) {
      return res.status(404).json({ error: 'Berber bulunamadı' });
    }

    if (barber.role !== UserRole.BARBER) {
      return res.status(400).json({ error: 'Kullanıcı berber değil' });
    }

    res.json({ availability: barber.availability || [] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/user/availability:
 *   put:
 *     summary: Berberin müsaitliklerini güncelleme
 *     tags: [User]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: array
 *             items:
 *               type: object
 *               properties:
 *                 dayOfWeek:
 *                   type: integer
 *                 timeRanges:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       startTime:
 *                         type: string
 *                       endTime:
 *                         type: string
 *     responses:
 *       200:
 *         description: Müsaitlik güncellendi
 *       400:
 *         description: Geçersiz veri
 */

// PUT /api/user/availability
router.put('/availability', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Sadece berberler müsaitliklerini güncelleyebilir' });
    }

    const { availability } = req.body; 
    // Örnek body:
    // [
    //   { dayOfWeek: 1, timeRanges: [{ startTime: '09:00', endTime: '12:00' }, { startTime: '13:00', endTime: '22:00' }] },
    //   { dayOfWeek: 2, timeRanges: [{ startTime: '10:00', endTime: '18:00' }] }
    // ]

    if (!Array.isArray(availability)) {
      return res.status(400).json({ error: 'availability array is required' });
    }

    // Basit validasyon yapabilirsin

    req.user.availability = availability;
    await req.user.save();

    res.json({ message: 'Availability updated', availability: req.user.availability });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});





module.exports = router;
