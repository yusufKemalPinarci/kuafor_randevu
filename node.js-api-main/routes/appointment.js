const express = require('express');
const Appointment = require('../models/Appointment');
const { User, UserRole } = require('../models/User');
const Service = require('../models/Service'); // Service şemanın yolu
const authMiddleware = require('../middlewares/auth');
const router = express.Router();
const smsService = require('../utils/smsService.jsx'); // Twilio gibi bir servis





/**
 * @swagger
 * tags:
 *   name: Appointments
 *   description: Randevu yönetimi
 */

/**
 * @swagger
 * /api/appointment:
 *   post:
 *     summary: Yeni randevu oluştur (kullanıcı girişli)
 *     tags: [Appointments]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               barberId:
 *                 type: string
 *               date:
 *                 type: string
 *                 example: "2025-08-20"
 *               startTime:
 *                 type: string
 *                 example: "14:30"
 *               serviceId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Randevu oluşturuldu
 */


// ✅ Yeni randevu oluştur
// POST /api/appointment
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { barberId, date, startTime, serviceId } = req.body;

    // 1️⃣ Berber kontrolü
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== UserRole.BARBER) {
      return res.status(404).json({ error: 'Barber not found' });
    }

    // 2️⃣ Servis bilgisi
    const service = await Service.findById(serviceId);
    if (!service) {
      return res.status(404).json({ error: 'Service not found' });
    }

    // 3️⃣ Start ve end Date objeleri
    const [startHour, startMinute] = startTime.split(':').map(Number);
    const startDateObj = new Date(date);
    startDateObj.setHours(startHour, startMinute, 0, 0);

    const endDateObj = new Date(startDateObj.getTime() + service.durationMinutes * 60000);

    // 4️⃣ Çakışma kontrolü (Date objesi ile)
    const overlapping = await Appointment.findOne({
      barberId,
      date,
      $or: [
        { startTime: { $lt: endDateObj }, endTime: { $gt: startDateObj } }
      ]
    });

    if (overlapping) {
      return res.status(400).json({ error: 'This time slot overlaps with another appointment' });
    }

    // 5️⃣ Randevu oluşturma
    const appointment = new Appointment({
      barberId,
      customerId: req.user._id,
      customerName: req.user.name,
      customerPhone: req.user.phone,
      date,
      startTime: startDateObj,
      endTime: endDateObj,
      serviceId
    });

    await appointment.save();
    res.json(appointment);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/appointment/musaitberber:
 *   get:
 *     summary: Belirli berberin müsait saatlerini getir
 *     tags: [Appointments]
 *     parameters:
 *       - in: query
 *         name: barberId
 *         schema:
 *           type: string
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *       - in: query
 *         name: serviceId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Müsait saatler listesi
 */
// GET /available-times?barberId=xxx&date=2025-08-20    berberin dolu saatlerini görme 
router.get('/musaitberber', async (req, res) => {
  try {
    const { barberId, date, serviceId } = req.query;

    // 1. Berber bilgisi
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== 'Barber') {
      return res.status(404).json({ error: 'Berber bulunamadı veya geçersiz rol' });
    }

    // 2. Servis bilgisi (süreyi almak için)
    const service = await Service.findById(serviceId);
if (!service) {
  return res.status(404).json({ error: 'Servis bulunamadı' });
}

if (!service.barberId || service.barberId.toString() !== barberId) {
  return res.status(400).json({ error: 'Servis bu berbere ait değil' });
}

    const serviceDuration = service.durationMinutes; // dakika

    // 3. O günkü availability
    const dayOfWeek = new Date(date).getDay(); // 0 = Pazar
    const availabilityForDay = barber.availability.find(a => a.dayOfWeek === dayOfWeek);
    if (!availabilityForDay) {
      return res.json([]); // O gün hiç müsait değilse boş dön
    }

    // 4. O güne ait mevcut randevular
    const appointments = await Appointment.find({ barberId, date });

    // 5. 15 dakikalık slotları oluşturma + servis süresine göre kontrol
    const slots = [];
    availabilityForDay.timeRanges.forEach(range => {
      let current = timeStringToMinutes(range.startTime);
      const end = timeStringToMinutes(range.endTime);

      while (current + 15 <= end) {
        const timeLabel = minutesToTimeString(current);

        // Servis süresine göre çakışma kontrolü
        const slotStart = current;
        const slotEnd = slotStart + serviceDuration;

    const isTaken = appointments.some(app => {
  if (!app.startTime || !app.endTime) return false;

  // Date → dakika
  const appStart = app.startTime.getHours() * 60 + app.startTime.getMinutes();
  const appEnd   = app.endTime.getHours() * 60 + app.endTime.getMinutes();

  return slotStart < appEnd && slotEnd > appStart;
});


        slots.push({
          time: timeLabel,
          available: !isTaken // true = müsait, false = dolu
        });

        current += 15; // 15 dakika ilerle
      }
    });

    res.json(slots);

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});





/**
 * @swagger
 * /api/appointment:
 *   get:
 *     summary: Tüm randevuları getir
 *     tags: [Appointment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Randevular başarıyla getirildi
 */

// ✅ Tüm randevuları getir
router.get('/', authMiddleware,async (req, res) => {
  try {
    const appointments = await Appointment.find()
      .populate('userId', 'name email')
      .populate('serviceId', 'title price durationMinutes');
    res.json(appointments);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/appointment/my:
 *   get:
 *     summary: Giriş yapan kullanıcının randevularını getir
 *     tags: [Appointment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Kullanıcının randevuları
 */

router.get('/my', authMiddleware, async (req, res) => {
  try {
    // Müşterinin ID'si JWT'den geliyor
    const customerId = req.user._id;

    // Sadece giriş yapan kullanıcının randevularını getir
    const appointments = await Appointment.find({ customerId })
      .populate('barberId', 'name email phone')    // Berber bilgilerini ekle
      .populate('serviceId', 'title price notes')        // Hizmet bilgilerini ekle
      .sort({ date: 1, startTime: 1 });             // Tarihe göre sırala

    res.json(appointments);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/**
 * @swagger
 * /api/appointment/my_berber:
 *   get:
 *     summary: Giriş yapan berberin randevularını getir
 *     tags: [Appointment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Berberin randevuları
 */
router.get('/my_berber', authMiddleware, async (req, res) => {
  try {
    // Müşterinin ID'si JWT'den geliyor
    const barberId = req.user._id;

    // Sadece giriş yapan kullanıcının randevularını getir
    const appointments = await Appointment.find({ barberId })
      .populate('barberId', 'name email phone')    // Berber bilgilerini ekle
      .populate('serviceId', 'title price notes')        // Hizmet bilgilerini ekle
      .sort({ date: 1, startTime: 1 });             // Tarihe göre sırala

    res.json(appointments);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});





/**
 * @swagger
 * /api/appointment/{id}:
 *   get:
 *     summary: ID ile randevu getir
 *     tags: [Appointment]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Randevu bilgisi
 */
// ✅ ID ile tek bir randevuyu getir
router.get('/:id', async (req, res) => {
  try {
    const appointment = await Appointment.findById(req.params.id)
      .populate('userId', 'name email')
      .populate('serviceId', 'title price durationMinutes');

    if (!appointment) {
      return res.status(404).json({ error: "Appointment not found" });
    }

    res.json(appointment);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


/**
 * @swagger
 * /api/appointment/{id}:
 *   put:
 *     summary: Randevuyu güncelle
 *     tags: [Appointment]
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
 *               date:
 *                 type: string
 *               userId:
 *                 type: string
 *               customerPhone:
 *                 type: string
 *               serviceId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Güncellenmiş randevu
 */

// ✅ Randevuyu güncelle
router.put('/:id', async (req, res) => {
  try {
    const { date, userId, customerPhone, serviceId } = req.body;

    const updatedAppointment = await Appointment.findByIdAndUpdate(
      req.params.id,
      {
        date,
        userId: userId || undefined,
        customerPhone,
        serviceId
      },
      { new: true, runValidators: true }
    );

    if (!updatedAppointment) {
      return res.status(404).json({ error: "Appointment not found" });
    }

    res.json(updatedAppointment);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/appointment/{id}:
 *   delete:
 *     summary: Randevuyu sil
 *     tags: [Appointment]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Başarıyla silindi
 */
// ✅ Randevuyu sil
router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Appointment.findByIdAndDelete(req.params.id);

    if (!deleted) {
      return res.status(404).json({ error: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted successfully" });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});



/**
 * @swagger
 * /api/appointment/{id}/availability:
 *   get:
 *     summary: Belirli berber için belirli günde müsaitlik getir
 *     tags: [Appointment]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: date
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Müsait saatler
 */
// GET /api/appointment/:id/availability?date=2025-08-15
router.get('/:id/availability', async (req, res) => {
  try {
    const barber = await User.findById(req.params.id);
    if (!barber || barber.role !== UserRole.BARBER) {
      return res.status(404).json({ error: 'Barber not found' });
    }

    const date = new Date(req.query.date);
    const dayOfWeek = date.getDay();

    // Berberin o günkü müsait saatlerini al
    const availableSlots = barber.availability.filter(a => a.dayOfWeek === dayOfWeek);

    // Burada mevcut randevuları çekip dolu saatleri çıkarabiliriz
    // Appointment.find({ barberId: barber._id, date: sameDay })

    res.json({ date: req.query.date, slots: availableSlots });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});





/**
 * @swagger
 * /api/appointment/randevu_al:
 *   post:
 *     summary: Yeni randevu al
 *     tags: [Appointment]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               barberId:
 *                 type: string
 *               customerId:
 *                 type: string
 *               customerName:
 *                 type: string
 *               customerPhone:
 *                 type: string
 *               date:
 *                 type: string
 *               startTime:
 *                 type: string
 *               serviceId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Randevu oluşturuldu
 */

// müşteri uygun saate randevu alacak.
router.post('/randevu_al', async (req, res) => {
  try {
    const { barberId, customerId, customerName, customerPhone, date, startTime, serviceId } = req.body;

    // 1. Berber kontrolü
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== 'Barber') {
      return res.status(404).json({ error: 'Berber bulunamadı veya geçersiz rol' });
    }

    // 2. Servis doğrulaması
    const service = await Service.findById(serviceId);
    if (!service || service.barberId.toString() !== barberId) {
      return res.status(404).json({ error: 'Servis bulunamadı veya bu berbere ait değil' });
    }

    // 3. Berberin o gün müsaitlik kontrolü
    const dayOfWeek = new Date(date).getDay();
    const availabilityForDay = (barber.availability || []).find(a => a.dayOfWeek === dayOfWeek);
    if (!availabilityForDay) {
      return res.status(400).json({ error: 'Berber o gün müsait değil' });
    }

    const isAvailable = availabilityForDay.timeRanges.some(range => {
      return startTime >= range.startTime && startTime < range.endTime;
    });
    if (!isAvailable) {
      return res.status(400).json({ error: 'Berber bu saatte müsait değil' });
    }

    // 4. Çakışan randevu kontrolü
    const existingAppointment = await Appointment.findOne({ barberId, date, startTime });
    if (existingAppointment) {
      return res.status(400).json({ error: 'Bu saat zaten dolu' });
    }

    // 5. Randevuyu oluştur
    const appointment = new Appointment({
      barberId,
      customerId,
      customerName,
      customerPhone,
      date,
      startTime,
      serviceId
    });

    await appointment.save();

    res.status(201).json(appointment);

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});



// Yardımcı fonksiyonlar
function timeStringToMinutes(timeStr) {
  const [hours, minutes] = timeStr.split(':').map(Number);
  return hours * 60 + minutes;
}

function minutesToTimeString(minutes) {
  const h = String(Math.floor(minutes / 60)).padStart(2, '0');
  const m = String(minutes % 60).padStart(2, '0');
  return `${h}:${m}`;
}


// Yardımcı fonksiyonlar
function timeStringToMinutes(timeStr) {
  const [hours, minutes] = timeStr.split(':').map(Number);
  return hours * 60 + minutes;
}

function minutesToTimeString(minutes) {
  const h = String(Math.floor(minutes / 60)).padStart(2, '0');
  const m = String(minutes % 60).padStart(2, '0');
  return `${h}:${m}`;
}


/**
 * @swagger
 * /api/appointment/request:
 *   post:
 *     summary: OTP göndererek randevu talebi
 *     tags: [Appointment]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               barberId:
 *                 type: string
 *               serviceId:
 *                 type: string
 *               date:
 *                 type: string
 *               startTime:
 *                 type: string
 *               customerName:
 *                 type: string
 *               customerPhone:
 *                 type: string
 *               endTime:
 *                 type: string
 *     responses:
 *       200:
 *         description: OTP gönderildi
 */


// 1️⃣ OTP üret ve SMS gönder
router.post('/request', async (req, res) => {
  try {
    const { barberId, serviceId, date, startTime, customerName, customerPhone, endTime } = req.body;

    // Berber kontrolü
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== 'Barber') return res.status(404).json({ error: 'Berber bulunamadı' });

    // Servis kontrolü
    const service = await Service.findById(serviceId);
    if (!service) return res.status(404).json({ error: 'Servis bulunamadı' });

    // OTP üret
    const otp = '123456';//Math.floor(100000 + Math.random() * 900000).toString(); // 6 haneli
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 dk geçerli

    // OTP’yi veritabanına kaydet (Appointment temp)
    await Appointment.create({
      barberId,
      serviceId,
      date,
      startTime,
      customerName,
      endTime,
      customerPhone,
      status: 'pending',
      otp,
      otpExpiresAt: expiresAt
    });

    // SMS gönder
    //await smsService.sendSMS(customerPhone, `Randevu doğrulama kodunuz: ${otp}`);

    res.json({ message: 'OTP gönderildi, lütfen kodu doğrulayın', customerPhone });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


/**
 * @swagger
 * /api/appointment/verify:
 *   post:
 *     summary: OTP doğrulaması ile randevuyu onayla
 *     tags: [Appointment]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               customerPhone:
 *                 type: string
 *               otp:
 *                 type: string
 *     responses:
 *       200:
 *         description: Randevu onaylandı
 */

router.post('/verify', async (req, res) => {
  try {
    const { customerPhone, otp } = req.body;
    
    const appointment = await Appointment.findOne({
      customerPhone,
      otp,
      otpExpiresAt: { $gte: new Date() },
      status: 'pending'
    });

    if (!appointment) return res.status(400).json({ error: 'Geçersiz veya süresi dolmuş kod' });

    // OTP doğrulandı → randevuyu aktif yap
    appointment.status = 'confirmed';
    appointment.otp = undefined;
    appointment.otpExpiresAt = undefined;
    await appointment.save();

    res.json({ message: 'Randevu başarıyla oluşturuldu', appointment });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});




module.exports = router;
