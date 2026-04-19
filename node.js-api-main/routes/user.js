const express = require('express');
const bcrypt = require('bcrypt');
const admin = require('firebase-admin');
const { User, UserRole } = require('../models/User');
const { generateToken, generateTokenPair } = require('../helpers/jwtService');
const RefreshToken = require('../models/RefreshToken');
const authMiddleware = require('../middlewares/auth');
const { initFirebase } = require('../utils/notificationService');
const { Subscription, SubscriptionTier } = require('../models/Subscription');
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

    // SECURITY: Validate types to prevent NoSQL injection
    if (typeof email !== 'string' || typeof password !== 'string') {
      return res.status(400).json({ error: 'Geçersiz istek formatı.' });
    }

    // SECURITY: Enforce minimum password length
    if (!password || password.length < 6) {
      return res.status(400).json({ error: 'Şifre en az 6 karakter olmalıdır.' });
    }

    email = email.toLowerCase();
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ error: 'Bu e-posta adresi zaten kullanılıyor.' });

    const passwordHash = await bcrypt.hash(password, 10);

    // SECURITY: Whitelist allowed roles — prevents privilege escalation to Admin via API
    const allowedRoles = [UserRole.CUSTOMER, UserRole.BARBER];
    let userData = {
      name,
      email,
      passwordHash,
      role: allowedRoles.includes(role) ? role : UserRole.CUSTOMER,
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

    const { accessToken: token, refreshToken } = await generateTokenPair(user);

    // Return full user object (excluding password hash) so frontend has all fields
    const userObj = user.toObject();
    delete userObj.passwordHash;
    delete userObj.__v;

    res.json({
      token,
      refreshToken,
      user: userObj
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.' });
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
    // SECURITY: Never expose sensitive fields to frontend
    const userObj = req.user.toObject ? req.user.toObject() : { ...req.user._doc };
    delete userObj.passwordHash;
    delete userObj.resetCode;
    delete userObj.resetCodeExpiry;
    delete userObj.__v;
    res.status(200).json(userObj);
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
router.put('/barber/availability/:id', authMiddleware, async (req, res) => {
  try {
    // SECURITY: Users can only update their own availability
    if (req.user._id.toString() !== req.params.id) {
      return res.status(403).json({ error: 'Sadece kendi müsaitlik bilginizi güncelleyebilirsiniz.' });
    }

    const { availability } = req.body;

    if (!availability || !Array.isArray(availability)) {
      return res.status(400).json({ error: 'Müsaitlik bilgisi dizi formatında olmalıdır.' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { availability },
      { new: true }
    );

    if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    res.json({ message: 'Müsaitlik güncellendi.', availability: user.availability });

  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
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
    let { email, password } = req.body;

    // SECURITY: Validate types to prevent NoSQL injection
    if (typeof email !== 'string' || typeof password !== 'string') {
      return res.status(400).json({ error: 'Geçersiz e-posta veya şifre formatı.' });
    }

    email = email.toLowerCase();
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ error: 'E-posta veya şifre hatalı.' });

    // Google ile kayıt olmuş ve şifresi olmayan kullanıcı
    if (user.googleId && !user.passwordHash) {
      return res.status(400).json({ error: 'Bu hesap Google ile oluşturulmuş. Lütfen "Google ile Giriş Yap" seçeneğini kullanın.' });
    }

    if (!user.passwordHash) {
      return res.status(400).json({ error: 'E-posta veya şifre hatalı.' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return res.status(400).json({ error: 'E-posta veya şifre hatalı.' });

    const { accessToken: token, refreshToken } = await generateTokenPair(user);

    // SECURITY: Strip sensitive fields before sending to client
    const userObj = user.toObject();
    delete userObj.passwordHash;
    delete userObj.resetCode;
    delete userObj.resetCodeExpiry;
    delete userObj.__v;

    res.json({
      token,
      refreshToken,
      user: userObj
    });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
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

    if (!shopId) return res.status(400).json({ error: 'Dükkan bilgisi zorunludur.' });
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
    res.status(500).json({ error: 'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.' });
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
      return res.status(400).json({ error: 'Kullanıcı henüz bir dükkana atanmamış.' });
    }

    user.shopId = null; // veya undefined de olabilir
    await user.save();

    res.json({
      message: 'Dükkandan ayrıldınız.',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        shopId: user.shopId,
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
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
// usera telefon ekleme
router.put('/:id/phone', authMiddleware, async (req, res) => {
  try {
    // SECURITY: Users can only update their own phone number
    if (req.user._id.toString() !== req.params.id) {
      return res.status(403).json({ error: 'Sadece kendi telefon numaranızı güncelleyebilirsiniz.' });
    }

    const { phone } = req.body;

    // Telefon numarası kontrolü
    if (!phone || phone.trim() === '') {
      return res.status(400).json({ error: 'Telefon numarası zorunludur.' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { phone },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    }

    res.json({ message: 'Telefon güncellendi.', phone: user.phone });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
  }
});


router.put('/shop', authMiddleware, async (req, res) => {
  try {
    const { shopId } = req.body;

    if (!shopId) {
      return res.status(400).json({ error: 'Dükkan bilgisi zorunludur.' });
    }

    // Dükkanın var olduğunu doğrula
    const Shop = require('../models/Shop');
    const shop = await Shop.findById(shopId);
    if (!shop) {
      return res.status(404).json({ error: 'Dükkan bulunamadı.' });
    }

    // JWT token'dan userId geliyor
    const userId = req.user.id;

    const user = await User.findByIdAndUpdate(
      userId,
      { shopId },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    }

    res.json({
      message: 'Dükkan güncellendi.',
      shopId: user.shopId
    });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
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
      return res.status(403).json({ error: 'Sadece berberler bu bilgiyi güncelleyebilir.' });
    }

    const { phone, bio, availability } = req.body;

    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      { phone, bio, availability },
      { new: true }
    ).select('-passwordHash');

    res.json(updatedUser);
  } catch (err) {
    res.status(500).json({ error: 'Profil güncellenirken hata oluştu.' });
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
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
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
      return res.status(400).json({ error: 'Müsaitlik bilgisi dizi formatında olmalıdır.' });
    }

    req.user.availability = availability;
    await req.user.save();

    res.json({ message: 'Availability updated', availability: req.user.availability });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası. Lütfen tekrar deneyin.' });
  }
});

// POST /api/user/forgot-password
router.post('/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'E-posta adresi zorunludur.' });

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return res.status(404).json({ error: 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.' });

    if (user.googleId && !user.passwordHash) {
      return res.status(400).json({ error: 'Bu hesap Google ile giriş yapıyor. Şifre sıfırlama kullanılamaz.' });
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    user.resetCode = code;
    user.resetCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 dakika
    await user.save();

    let emailSent = false;
    if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
      try {
        const nodemailer = require('nodemailer');
        const transporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: parseInt(process.env.SMTP_PORT) || 587,
          secure: false,
          auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
        });
        await transporter.sendMail({
          from: `"KuaFlex" <${process.env.SMTP_USER}>`,
          to: email,
          subject: 'Şifre Sıfırlama Kodu - KuaFlex',
          html: `<div style="font-family:sans-serif;max-width:400px">
            <h2 style="color:#C69749">Şifre Sıfırlama</h2>
            <p>Sıfırlama kodunuz:</p>
            <h1 style="letter-spacing:8px;color:#333">${code}</h1>
            <p style="color:#666">Bu kod 15 dakika geçerlidir.</p>
          </div>`,
        });
        emailSent = true;
      } catch (emailErr) {
        console.error('E-posta gönderilemedi:', emailErr.message);
      }
    }

    const response = { message: 'Şifre sıfırlama kodu gönderildi.' };
    if (!emailSent && process.env.NODE_ENV !== 'production') {
      response.code = code; // Sadece geliştirme modunda kodu döndür
    }
    res.json(response);
  } catch (err) {
    res.status(500).json({ error: 'Şifre sıfırlama sırasında hata oluştu.' });
  }
});
router.post('/reset-password', async (req, res) => {
  try {
    const { email, code, newPassword } = req.body;
    if (!email || !code || !newPassword) {
      return res.status(400).json({ error: 'E-posta, kod ve yeni şifre zorunludur.' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Şifre en az 6 karakter olmalıdır.' });
    }
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || user.resetCode !== code || !user.resetCodeExpiry || user.resetCodeExpiry < new Date()) {
      return res.status(400).json({ error: 'Geçersiz veya süresi dolmuş kod.' });
    }
    user.passwordHash = await bcrypt.hash(newPassword, 10);
    user.resetCode = null;
    user.resetCodeExpiry = null;
    await user.save();
    res.json({ message: 'Şifreniz başarıyla güncellendi. Giriş yapabilirsiniz.' });
  } catch (err) {
    res.status(500).json({ error: 'Şifre güncellenirken hata oluştu.' });
  }
});

// PUT /api/user/change-password (authenticated — requires current password)
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // SECURITY: type check prevents NoSQL injection
    if (typeof currentPassword !== 'string' || typeof newPassword !== 'string') {
      return res.status(400).json({ error: 'Geçersiz istek formatı.' });
    }
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Mevcut ve yeni şifre zorunludur.' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Yeni şifre en az 6 karakter olmalıdır.' });
    }

    const user = await User.findById(req.user._id);
    // Google / social users may not have a password hash
    if (!user.passwordHash) {
      return res.status(400).json({ error: 'Bu hesap sosyal giriş ile oluşturulmuş. Google hesabınızdan şifre değiştirebilirsiniz.' });
    }

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) {
      return res.status(400).json({ error: 'Mevcut şifreniz yanlış.' });
    }
    if (currentPassword === newPassword) {
      return res.status(400).json({ error: 'Yeni şifre mevcut şifreden farklı olmalıdır.' });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: 'Şifreniz başarıyla güncellendi.' });
  } catch (err) {
    res.status(500).json({ error: 'Şifre değiştirme sırasında hata oluştu.' });
  }
});

// POST /api/user/firebase-auth — Firebase ID Token ile giriş/kayıt
router.post('/firebase-auth', async (req, res) => {
  try {
    const { firebaseIdToken, role } = req.body;
    if (!firebaseIdToken || typeof firebaseIdToken !== 'string') {
      return res.status(400).json({ error: 'Firebase token zorunludur.' });
    }

    // Firebase Admin SDK başlat (zaten başlatılmışsa atlar)
    initFirebase();

    // Firebase ID token doğrula
    const decodedToken = await admin.auth().verifyIdToken(firebaseIdToken);
    const { uid, email, name: firebaseName } = decodedToken;

    if (!email) {
      return res.status(400).json({ error: 'Firebase hesabında e-posta bulunamadı.' });
    }

    // Kullanıcıyı Firebase UID veya email ile bul
    let user = await User.findOne({ $or: [{ firebaseUid: uid }, { email: email.toLowerCase() }] });

    if (!user) {
      // Yeni kullanıcı — role gerekli
      if (!role) {
        return res.status(200).json({ needsRole: true, email, name: firebaseName });
      }

      const allowedRoles = [UserRole.CUSTOMER, UserRole.BARBER];
      user = new User({
        name: firebaseName || email.split('@')[0],
        email: email.toLowerCase(),
        firebaseUid: uid,
        role: allowedRoles.includes(role) ? role : UserRole.CUSTOMER,
      });
      await user.save();
    } else {
      // Mevcut kullanıcı — firebaseUid güncelle
      if (!user.firebaseUid) {
        user.firebaseUid = uid;
        await user.save();
      }
    }

    const { accessToken: token, refreshToken } = await generateTokenPair(user);
    const userObj = user.toObject();
    delete userObj.passwordHash;
    delete userObj.__v;
    res.json({ token, refreshToken, user: userObj });
  } catch (err) {
    console.error('Firebase auth error:', err.message);
    if (err.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Firebase oturumu sona ermiş. Lütfen tekrar giriş yapın.' });
    }
    if (err.code === 'auth/argument-error' || err.code === 'auth/id-token-revoked') {
      return res.status(401).json({ error: 'Geçersiz Firebase token.' });
    }
    res.status(500).json({ error: 'Firebase ile giriş sırasında hata oluştu.' });
  }
});

// POST /api/user/google-auth
router.post('/google-auth', async (req, res) => {
  try {
    const { idToken, role } = req.body;
    if (!idToken) return res.status(400).json({ error: 'Google token zorunludur.' });

    const tokenInfoRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
    const payload = await tokenInfoRes.json();
    if (payload.error || !payload.email) {
      return res.status(401).json({ error: 'Geçersiz Google token.' });
    }

    const { email, name, sub: googleId } = payload;
    let user = await User.findOne({ $or: [{ googleId }, { email: email.toLowerCase() }] });

    if (!user) {
      if (!role) return res.status(200).json({ isNewUser: true, email, name });
      // SECURITY: Whitelist allowed roles — prevents privilege escalation to Admin via API
      const allowedRoles = [UserRole.CUSTOMER, UserRole.BARBER];
      user = new User({
        name: name || email.split('@')[0],
        email: email.toLowerCase(),
        googleId,
        role: allowedRoles.includes(role) ? role : UserRole.CUSTOMER,
      });
      await user.save();
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const { accessToken: token, refreshToken } = await generateTokenPair(user);
    const userObj = user.toObject();
    delete userObj.passwordHash;
    delete userObj.__v;
    res.json({ token, refreshToken, user: userObj });
  } catch (err) {
    res.status(500).json({ error: 'Google ile giriş sırasında hata oluştu.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// ✅ FCM TOKEN YÖNETİMİ (Push Notification)
// ═══════════════════════════════════════════════════════════════

// POST /api/user/fcm-token — FCM token kaydet / güncelle
router.post('/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken zorunludur.' });
    }

    const user = req.user;

    // Aynı token zaten varsa ekleme
    if (!user.fcmTokens.includes(fcmToken)) {
      user.fcmTokens.push(fcmToken);
      await user.save();
    }

    res.json({ message: 'FCM token kaydedildi.' });
  } catch (err) {
    res.status(500).json({ error: 'Token kaydedilemedi.' });
  }
});

// DELETE /api/user/fcm-token — Çıkışta FCM token sil
router.delete('/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken zorunludur.' });
    }

    const user = req.user;
    user.fcmTokens = user.fcmTokens.filter(t => t !== fcmToken);
    await user.save();

    res.json({ message: 'FCM token silindi.' });
  } catch (err) {
    res.status(500).json({ error: 'Token silinemedi.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// ✅ HESAP SİLME
// ═══════════════════════════════════════════════════════════════

// DELETE /api/user/account — Kullanıcı hesabını ve ilişkili verilerini kalıcı olarak sil
router.delete('/account', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const userEmail = req.user.email;
    const firebaseUid = req.user.firebaseUid;

    const Appointment = require('../models/Appointment');
    const Subscription = require('../models/Subscription');
    const BlockedTime = require('../models/BlockedTime');

    // İlişkili verileri sil
    await Appointment.deleteMany({
      $or: [{ barber: userId }, { customer: userId }],
    });
    await Subscription.deleteMany({ shop: { $in: await getOwnedShopIds(userId) } });
    await BlockedTime.deleteMany({ barber: userId });

    // Kullanıcının sahip olduğu dükkan varsa, dükkanı da sil
    const Shop = require('../models/Shop');
    await Shop.deleteMany({ owner: userId });

    // Firebase Auth hesabını sil
    if (firebaseUid) {
      try {
        initFirebase();
        await admin.auth().deleteUser(firebaseUid);
      } catch (fbErr) {
        // Firebase hesabı zaten silinmiş olabilir, devam et
        console.error('Firebase hesap silme hatası (devam ediliyor):', fbErr.message);
      }
    }

    // Kullanıcıyı veritabanından sil
    await User.findByIdAndDelete(userId);

    res.json({ message: 'Hesabınız ve tüm verileriniz kalıcı olarak silindi.' });
  } catch (err) {
    console.error('Hesap silme hatası:', err.message);
    res.status(500).json({ error: 'Hesap silinirken bir hata oluştu.' });
  }
});

// ────────────────────────────────────────────────────────────
// POST /api/user/refresh-token — JWT yenile (refresh token rotation)
// ────────────────────────────────────────────────────────────
router.post('/refresh-token', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken || typeof refreshToken !== 'string') {
      return res.status(400).json({ error: 'Refresh token zorunludur.' });
    }

    // Refresh token'ı bul
    const storedToken = await RefreshToken.findOne({ token: refreshToken });
    if (!storedToken) {
      return res.status(401).json({ error: 'Geçersiz refresh token.' });
    }

    // Revoke edilmiş mi kontrol et
    if (storedToken.isRevoked) {
      // Olası token hırsızlığı — bu kullanıcının tüm refresh tokenlarını iptal et
      await RefreshToken.updateMany({ userId: storedToken.userId }, { isRevoked: true });
      return res.status(401).json({ error: 'Token güvenlik ihlali tespit edildi. Lütfen tekrar giriş yapın.' });
    }

    // Süresi dolmuş mu
    if (storedToken.expiresAt < new Date()) {
      await RefreshToken.deleteOne({ _id: storedToken._id });
      return res.status(401).json({ error: 'Refresh token süresi dolmuş. Lütfen tekrar giriş yapın.' });
    }

    // Kullanıcı hala mevcut mu
    const user = await User.findById(storedToken.userId);
    if (!user) {
      await RefreshToken.deleteMany({ userId: storedToken.userId });
      return res.status(401).json({ error: 'Kullanıcı bulunamadı.' });
    }

    // Eski refresh token'ı revoke et (rotation)
    storedToken.isRevoked = true;
    await storedToken.save();

    // Yeni JWT + refresh token çifti üret
    const { accessToken, refreshToken: newRefreshToken } = await generateTokenPair(user);

    res.json({ token: accessToken, refreshToken: newRefreshToken });
  } catch (err) {
    console.error('Refresh token hatası:', err.message);
    res.status(500).json({ error: 'Token yenilenirken hata oluştu.' });
  }
});

// ────────────────────────────────────────────────────────────
// POST /api/user/logout — Oturumu kapat (refresh token iptal)
// ────────────────────────────────────────────────────────────
router.post('/logout', authMiddleware, async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      // Belirtilen refresh token'ı revoke et
      await RefreshToken.updateOne({ token: refreshToken, userId: req.user._id }, { isRevoked: true });
    }

    // Bu kullanıcının tüm refresh tokenlarını iptal et
    await RefreshToken.updateMany({ userId: req.user._id }, { isRevoked: true });

    res.json({ message: 'Oturum başarıyla kapatıldı.' });
  } catch (err) {
    console.error('Logout hatası:', err.message);
    res.status(500).json({ error: 'Çıkış sırasında hata oluştu.' });
  }
});

// ═══════════════════════════════════════════════════════════════
// ✅ BİLDİRİM TERCİHLERİ
// ═══════════════════════════════════════════════════════════════

// GET /api/user/notification-preferences
router.get('/notification-preferences', authMiddleware, async (req, res) => {
  try {
    const prefs = req.user.notificationPreferences || {};

    // Müşteriler için basit yanıt
    if (req.user.role === UserRole.CUSTOMER) {
      return res.json({
        preferences: {
          push: prefs.push !== false,
          customerPushReminder: prefs.customerPushReminder !== false,
          customerPushStatusChange: prefs.customerPushStatusChange !== false,
          customerEmailReminder: prefs.customerEmailReminder !== false,
          customerSmsReminder: prefs.customerSmsReminder !== false,
        },
      });
    }

    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Bildirim tercihleri görüntülenemez.' });
    }

    // Aktif abonelik tier bilgisini de döndür (UI'da toggle kilit durumu için)
    let activeTier = null;
    if (req.user.shopId) {
      const sub = await Subscription.findOne({
        shopId: req.user.shopId,
        status: 'active',
        endDate: { $gt: new Date() },
      });
      if (sub) activeTier = sub.tier;
    }

    // Aboneliğe göre email/sms durumunu kontrol et
    const canEmail = !!activeTier;
    const canSms = activeTier === SubscriptionTier.PRO || activeTier === SubscriptionTier.PREMIUM;

    res.json({
      preferences: {
        push: prefs.push !== false,
        email: canEmail ? (prefs.email === true) : false,
        sms: canSms ? (prefs.sms === true) : false,
        // Push alt tercihleri
        pushNewAppointment: prefs.pushNewAppointment !== false,
        pushCancellation: prefs.pushCancellation !== false,
        pushReminder: prefs.pushReminder !== false,
        // Email alt tercihleri
        emailDailySummary: prefs.emailDailySummary !== false,
        emailReminder: prefs.emailReminder !== false,
        // SMS alt tercihleri
        smsNewAppointment: prefs.smsNewAppointment !== false,
        smsReminder: prefs.smsReminder !== false,
      },
      activeTier,
    });
  } catch (err) {
    res.status(500).json({ error: 'Bildirim tercihleri alınamadı.' });
  }
});

// PUT /api/user/notification-preferences
router.put('/notification-preferences', authMiddleware, async (req, res) => {
  try {
    // Müşteriler için basit güncelleme
    if (req.user.role === UserRole.CUSTOMER) {
      const { push, customerPushReminder, customerPushStatusChange, customerEmailReminder, customerSmsReminder } = req.body;
      const updateFields = {};
      if (typeof push === 'boolean') updateFields['notificationPreferences.push'] = push;
      if (typeof customerPushReminder === 'boolean') updateFields['notificationPreferences.customerPushReminder'] = customerPushReminder;
      if (typeof customerPushStatusChange === 'boolean') updateFields['notificationPreferences.customerPushStatusChange'] = customerPushStatusChange;
      if (typeof customerEmailReminder === 'boolean') updateFields['notificationPreferences.customerEmailReminder'] = customerEmailReminder;
      if (typeof customerSmsReminder === 'boolean') updateFields['notificationPreferences.customerSmsReminder'] = customerSmsReminder;

      const user = await User.findByIdAndUpdate(req.user._id, { $set: updateFields }, { new: true });
      const prefs = user.notificationPreferences || {};
      return res.json({
        preferences: {
          push: prefs.push !== false,
          customerPushReminder: prefs.customerPushReminder !== false,
          customerPushStatusChange: prefs.customerPushStatusChange !== false,
          customerEmailReminder: prefs.customerEmailReminder !== false,
          customerSmsReminder: prefs.customerSmsReminder !== false,
        },
      });
    }
    }

    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Sadece berberler bildirim tercihlerini değiştirebilir.' });
    }

    const {
      push, email, sms,
      pushNewAppointment, pushCancellation, pushReminder,
      emailDailySummary, emailReminder,
      smsNewAppointment, smsReminder,
    } = req.body;

    // Abonelik tier kontrolü
    let activeTier = null;
    if (req.user.shopId) {
      const sub = await Subscription.findOne({
        shopId: req.user.shopId,
        status: 'active',
        endDate: { $gt: new Date() },
      });
      if (sub) activeTier = sub.tier;
    }

    const canEmail = !!activeTier;
    const canSms = activeTier === SubscriptionTier.PRO || activeTier === SubscriptionTier.PREMIUM;

    // Tercihleri güncelle — abonelik yetmiyorsa ilgili kanalı kapalı yaz
    const updateFields = {};
    if (typeof push === 'boolean') updateFields['notificationPreferences.push'] = push;
    if (typeof email === 'boolean') updateFields['notificationPreferences.email'] = canEmail ? email : false;
    if (typeof sms === 'boolean') updateFields['notificationPreferences.sms'] = canSms ? sms : false;

    // Push alt tercihleri
    if (typeof pushNewAppointment === 'boolean') updateFields['notificationPreferences.pushNewAppointment'] = pushNewAppointment;
    if (typeof pushCancellation === 'boolean') updateFields['notificationPreferences.pushCancellation'] = pushCancellation;
    if (typeof pushReminder === 'boolean') updateFields['notificationPreferences.pushReminder'] = pushReminder;

    // Email alt tercihleri
    if (typeof emailDailySummary === 'boolean') updateFields['notificationPreferences.emailDailySummary'] = emailDailySummary;
    if (typeof emailReminder === 'boolean') updateFields['notificationPreferences.emailReminder'] = emailReminder;

    // SMS alt tercihleri
    if (typeof smsNewAppointment === 'boolean') updateFields['notificationPreferences.smsNewAppointment'] = smsNewAppointment;
    if (typeof smsReminder === 'boolean') updateFields['notificationPreferences.smsReminder'] = smsReminder;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updateFields },
      { new: true }
    );

    const prefs = user.notificationPreferences || {};
    res.json({
      preferences: {
        push: prefs.push !== false,
        email: canEmail ? (prefs.email === true) : false,
        sms: canSms ? (prefs.sms === true) : false,
        pushNewAppointment: prefs.pushNewAppointment !== false,
        pushCancellation: prefs.pushCancellation !== false,
        pushReminder: prefs.pushReminder !== false,
        emailDailySummary: prefs.emailDailySummary !== false,
        emailReminder: prefs.emailReminder !== false,
        smsNewAppointment: prefs.smsNewAppointment !== false,
        smsReminder: prefs.smsReminder !== false,
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'Bildirim tercihleri güncellenemedi.' });
  }
});

// Kullanıcının sahip olduğu dükkan ID'lerini bul
async function getOwnedShopIds(userId) {
  const Shop = require('../models/Shop');
  const shops = await Shop.find({ owner: userId }).select('_id');
  return shops.map(s => s._id);
}

module.exports = router;
