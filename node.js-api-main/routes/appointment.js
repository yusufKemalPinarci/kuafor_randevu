const express = require('express');
const mongoose = require('mongoose');
const Appointment = require('../models/Appointment');
const BlockedTime = require('../models/BlockedTime');
const { User, UserRole } = require('../models/User');
const Service = require('../models/Service');
const authMiddleware = require('../middlewares/auth');
const phoneVerificationMiddleware = require('../middlewares/phoneVerification');
const router = express.Router();
const smsService = require('../utils/smsService.jsx');
const { sendToUser } = require('../utils/notificationService');
const Shop = require('../models/Shop');
const { sendAppointmentCreated, sendAppointmentConfirmed, sendAppointmentCancelled } = require('../utils/emailService');

// ObjectId doğrulama yardımcı fonksiyonu
function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// ═══════════════════════════════════════════════════════════════
// Paylaşılan çakışma kontrolü + bloke saat kontrolü
// Tüm randevu oluşturma route'ları bu fonksiyonu kullanır
// ═══════════════════════════════════════════════════════════════

/**
 * Çakışma ve bloke saat kontrolü yapar.
 * Çakışma varsa hata fırlatır, yoksa randevu oluşturur.
 * findOneAndUpdate + upsert benzeri atomik yaklaşım:
 *   1) Çakışma kontrolü
 *   2) Bloke saat kontrolü
 *   3) Kaydet
 *   4) Kaydetme sonrası tekrar çakışma kontrolü (TOCTOU önlemi)
 */
async function createAppointmentSafe(data) {
  const { barberId, date, startTime, endTime } = data;

  // 1. Çakışma kontrolü (iptal edilmemiş randevularla)
  const overlap = await Appointment.findOne({
    barberId,
    date,
    status: { $ne: 'cancelled' },
    startTime: { $lt: endTime },
    endTime: { $gt: startTime },
  });
  if (overlap) {
    const err = new Error('Bu saat aralığı başka bir randevu ile çakışıyor');
    err.code = 'SLOT_TAKEN';
    throw err;
  }

  // 2. Bloke saat kontrolü
  const startMinutes = startTime.getHours() * 60 + startTime.getMinutes();
  const endMinutes = endTime.getHours() * 60 + endTime.getMinutes();
  const blockedTimes = await BlockedTime.find({ barberId, date });
  const isBlocked = blockedTimes.some(bt => {
    const btStart = timeStringToMinutes(bt.startTime);
    const btEnd = timeStringToMinutes(bt.endTime);
    return startMinutes < btEnd && endMinutes > btStart;
  });
  if (isBlocked) {
    const err = new Error('Bu saat aralığı bloke edilmiş');
    err.code = 'SLOT_BLOCKED';
    throw err;
  }

  // 3. Kaydet
  const appointment = await Appointment.create(data);

  // 4. Kaydetme sonrası çakışma kontrolü (TOCTOU önlemi)
  // Aynı berber+tarih+zaman aralığında bu randevudan başka aktif randevu var mı?
  const duplicateCount = await Appointment.countDocuments({
    barberId,
    date,
    status: { $ne: 'cancelled' },
    startTime: { $lt: endTime },
    endTime: { $gt: startTime },
    _id: { $ne: appointment._id },
  });

  if (duplicateCount > 0) {
    // Yarış kaybedildi — bu randevuyu sil
    await Appointment.findByIdAndDelete(appointment._id);
    const err = new Error('Bu saat aralığı az önce başka biri tarafından alındı');
    err.code = 'SLOT_TAKEN';
    throw err;
  }

  return appointment;
}





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

    // 4️⃣ Otomatik onay kontrolü
    let autoConfirm = false;
    if (barber.shopId) {
      const shop = await Shop.findById(barber.shopId);
      if (shop?.autoConfirmAppointments) autoConfirm = true;
    }

    // 5️⃣ Çakışma + bloke saat kontrolü + atomik oluşturma
    let appointment;
    try {
      appointment = await createAppointmentSafe({
        barberId,
        customerId: req.user._id,
        customerName: req.user.name,
        customerPhone: req.user.phone,
        date,
        startTime: startDateObj,
        endTime: endDateObj,
        serviceId,
        ...(autoConfirm ? { status: 'confirmed' } : {}),
      });
    } catch (e) {
      if (e.code === 'SLOT_TAKEN' || e.code === 'SLOT_BLOCKED') {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }

    // 🔔 Berbere bildirim gönder (tercih kontrolü)
    const timeStr = `${String(startHour).padStart(2,'0')}:${String(startMinute).padStart(2,'0')}`;
    if (barber.notificationPreferences?.push !== false && barber.notificationPreferences?.pushNewAppointment !== false) {
      sendToUser(barber, '📅 Yeni Randevu Talebi', `${req.user.name} — ${service.title} (${timeStr})`, {
        type: 'new_appointment', appointmentId: appointment._id.toString()
      }).catch(err => console.error('Bildirim gönderilemedi:', err.message));
    }

    // 📧 Müşteriye e-posta (her zaman gider)
    if (req.user.email) {
      const shop = barber.shopId ? await Shop.findById(barber.shopId) : null;
      sendAppointmentCreated(req.user.email, {
        customerName: req.user.name,
        serviceName: service.title,
        barberName: barber.name,
        shopName: shop?.name || '',
        date: appointment.date,
        startTime: appointment.startTime,
      }).catch(err => console.error('E-posta gönderilemedi:', err.message));
    }

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
    if (!barber || barber.role !== UserRole.BARBER) {
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

    // 4. O güne ait mevcut randevular + bloke saatler
    const appointments = await Appointment.find({ barberId, date });
    const blockedTimes = await BlockedTime.find({ barberId, date });

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

    // Bloke saat kontrolü
    const isBlocked = blockedTimes.some(bt => {
      const btStart = timeStringToMinutes(bt.startTime);
      const btEnd = timeStringToMinutes(bt.endTime);
      return slotStart < btEnd && slotEnd > btStart;
    });

        slots.push({
          time: timeLabel,
          available: !isTaken && !isBlocked
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

// ✅ Tüm randevuları getir (Sadece Admin)
router.get('/', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.ADMIN) {
      return res.status(403).json({ error: 'Bu işleme yetkiniz yok.' });
    }
    const appointments = await Appointment.find()
      .populate('customerId', 'name email phone')
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


// ═══════════════════════════════════════════════════════════════
// ✅ BLOKE SAAT YÖNETİMİ (Berber meşgul saatleri)
// ═══════════════════════════════════════════════════════════════

// POST /api/appointment/block — Saat bloklama
router.post('/block', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Sadece berberler saat bloke edebilir' });
    }

    const { date, startTime, endTime, reason } = req.body;
    if (!date || !startTime || !endTime) {
      return res.status(400).json({ error: 'Tarih, başlangıç ve bitiş saati zorunludur' });
    }

    if (timeStringToMinutes(startTime) >= timeStringToMinutes(endTime)) {
      return res.status(400).json({ error: 'Bitiş saati başlangıçtan büyük olmalıdır' });
    }

    const blocked = await BlockedTime.create({
      barberId: req.user._id,
      date,
      startTime,
      endTime,
      reason: reason || '',
    });

    res.status(201).json(blocked);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/appointment/block?date=2026-03-10 — Berberin bloke saatleri
router.get('/block', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Yetkisiz' });
    }

    const filter = { barberId: req.user._id };
    if (req.query.date) filter.date = req.query.date;

    const blocks = await BlockedTime.find(filter).sort({ date: 1, startTime: 1 });
    res.json(blocks);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/appointment/block/:id — Bloke saat sil
router.delete('/block/:id', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Yetkisiz' });
    }

    const block = await BlockedTime.findOneAndDelete({
      _id: req.params.id,
      barberId: req.user._id,
    });

    if (!block) {
      return res.status(404).json({ error: 'Bloke saat bulunamadı' });
    }

    res.json({ message: 'Bloke saat silindi' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ═══════════════════════════════════════════════════════════════
// ✅ MANUEL RANDEVU (Berber müşteri adına oluşturur)
// ═══════════════════════════════════════════════════════════════

// POST /api/appointment/manual
router.post('/manual', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== UserRole.BARBER) {
      return res.status(403).json({ error: 'Sadece berberler manuel randevu oluşturabilir' });
    }

    const { serviceId, date, startTime, customerName, customerPhone } = req.body;

    if (!serviceId || !date || !startTime || !customerName || !customerPhone) {
      return res.status(400).json({ error: 'Tüm alanlar zorunludur' });
    }

    const barberId = req.user._id;

    // Servis kontrolü
    const service = await Service.findById(serviceId);
    if (!service || service.barberId.toString() !== barberId.toString()) {
      return res.status(404).json({ error: 'Servis bulunamadı veya bu berbere ait değil' });
    }

    // Start/End Date objeleri
    const [startHour, startMinute] = startTime.split(':').map(Number);
    const startDateObj = new Date(date);
    startDateObj.setHours(startHour, startMinute, 0, 0);
    const endDateObj = new Date(startDateObj.getTime() + service.durationMinutes * 60000);

    // Çakışma + bloke saat kontrolü + atomik oluşturma
    let appointment;
    try {
      appointment = await createAppointmentSafe({
        barberId,
        customerId: null,
        customerName,
        customerPhone,
        date,
        startTime: startDateObj,
        endTime: endDateObj,
        serviceId,
        status: 'confirmed',
        notes: 'Berber tarafından manuel oluşturuldu',
      });
    } catch (e) {
      if (e.code === 'SLOT_TAKEN' || e.code === 'SLOT_BLOCKED') {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }
    res.status(201).json(appointment);
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
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Geçersiz randevu kimliği.' });
    }
    const appointment = await Appointment.findById(req.params.id)
      .populate('customerId', 'name email phone')
      .populate('barberId', 'name email phone')
      .populate('serviceId', 'title price durationMinutes');

    if (!appointment) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    // Ownership check: berber, müşteri veya admin görebilir
    const userId = req.user._id.toString();
    const isOwner = appointment.barberId?._id?.toString() === userId
      || appointment.customerId?._id?.toString() === userId
      || req.user.role === UserRole.ADMIN;
    if (!isOwner) {
      return res.status(403).json({ error: 'Bu randevuyu görme yetkiniz yok.' });
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
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Geçersiz randevu kimliği.' });
    }
    // Ownership check: sadece randevu sahibi berber, müşteri veya admin güncelleyebilir
    const existingAppt = await Appointment.findById(req.params.id);
    if (!existingAppt) return res.status(404).json({ error: 'Appointment not found' });
    const userId = req.user._id.toString();
    const isOwner = existingAppt.barberId?.toString() === userId
      || existingAppt.customerId?.toString() === userId
      || req.user.role === UserRole.ADMIN;
    if (!isOwner) {
      return res.status(403).json({ error: 'Bu randevuyu güncelleme yetkiniz yok.' });
    }

    const { date, userId: bodyUserId, customerPhone, serviceId, status, notes } = req.body;

    const updateFields = {};
    if (date) updateFields.date = date;
    if (bodyUserId) updateFields.userId = bodyUserId;
    if (customerPhone) updateFields.customerPhone = customerPhone;
    if (serviceId) updateFields.serviceId = serviceId;
    if (status && ['pending', 'confirmed', 'cancelled'].includes(status)) updateFields.status = status;
    if (notes !== undefined) updateFields.notes = notes;

    // Durum değişikliğinde geçerli geçiş kontrolü (race condition önlemi)
    let statusFilter = {};
    if (status === 'confirmed') {
      statusFilter = { status: 'pending' }; // sadece pending → confirmed
    } else if (status === 'cancelled') {
      statusFilter = { status: { $in: ['pending', 'confirmed'] } }; // pending/confirmed → cancelled
    }

    const updatedAppointment = await Appointment.findOneAndUpdate(
      { _id: req.params.id, ...statusFilter },
      updateFields,
      { new: true, runValidators: true }
    );

    if (!updatedAppointment) {
      // Randevu var mı kontrol et — yoksa 404, varsa geçersiz geçiş
      const exists = await Appointment.findById(req.params.id);
      if (!exists) return res.status(404).json({ error: 'Appointment not found' });
      return res.status(409).json({ error: `Randevu şu anki durumda (${exists.status}) bu işleme izin vermiyor` });
    }

    // 🔔 Durum değişikliğinde bildirim gönder
    if (status === 'confirmed' || status === 'cancelled') {
      const statusText = status === 'confirmed' ? 'onaylandı ✅' : 'iptal edildi ❌';
      const timeStr = updatedAppointment.startTime
        ? `${String(updatedAppointment.startTime.getHours()).padStart(2,'0')}:${String(updatedAppointment.startTime.getMinutes()).padStart(2,'0')}`
        : '';

      const isActorBarber = updatedAppointment.barberId?.toString() === req.user._id.toString();
      const isActorCustomer = updatedAppointment.customerId?.toString() === req.user._id.toString();

      // Müşteriye bildirim — işlemi yapan müşteri değilse gönder
      if (!isActorCustomer && updatedAppointment.customerId) {
        const customer = await User.findById(updatedAppointment.customerId);
        if (customer && customer.notificationPreferences?.push !== false
            && customer.notificationPreferences?.customerPushStatusChange !== false) {
          sendToUser(customer, `Randevunuz ${statusText}`, `${timeStr} randevunuz ${statusText}`, {
            type: 'status_change', appointmentId: updatedAppointment._id.toString(), status
          }).catch(err => console.error('Müşteri bildirimi gönderilemedi:', err.message));
        }
      }

      // Berbere bildirim — işlemi yapan berber değilse gönder (sadece iptal)
      if (!isActorBarber) {
        const barber = await User.findById(updatedAppointment.barberId);
        if (barber && barber.notificationPreferences?.push !== false
            && barber.notificationPreferences?.pushCancellation !== false
            && status === 'cancelled') {
          sendToUser(barber, `Randevu ${statusText}`, `${updatedAppointment.customerName} — ${timeStr}`, {
            type: 'status_change', appointmentId: updatedAppointment._id.toString(), status
          }).catch(err => console.error('Berber bildirimi gönderilemedi:', err.message));
        }
      }

      // 📧 Müşteriye e-posta (kayıtlı veya misafir) — aktöre de gönder
      const barber = await User.findById(updatedAppointment.barberId);
      const customerEmail = updatedAppointment.customerEmail
        || (updatedAppointment.customerId ? (await User.findById(updatedAppointment.customerId))?.email : null);
      if (customerEmail) {
        const svc = await Service.findById(updatedAppointment.serviceId);
        const brb = barber || await User.findById(updatedAppointment.barberId);
        const emailFn = status === 'confirmed' ? sendAppointmentConfirmed : sendAppointmentCancelled;
        emailFn(customerEmail, {
          customerName: updatedAppointment.customerName,
          serviceName: svc?.title || '',
          barberName: brb?.name || '',
          date: updatedAppointment.date,
          startTime: updatedAppointment.startTime,
        }).catch(err => console.error('E-posta gönderilemedi:', err.message));
      }
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
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Geçersiz randevu kimliği.' });
    }
    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) {
      return res.status(404).json({ error: 'Appointment not found' });
    }

    // Ownership check: sadece berber veya admin silebilir
    const reqUserId = req.user._id.toString();
    const isOwner = appointment.barberId?.toString() === reqUserId
      || req.user.role === UserRole.ADMIN;
    if (!isOwner) {
      return res.status(403).json({ error: 'Bu randevuyu silme yetkiniz yok.' });
    }

    await Appointment.findByIdAndDelete(req.params.id);
    res.json({ message: 'Appointment deleted successfully' });
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
router.post('/randevu_al', phoneVerificationMiddleware, async (req, res) => {
  try {
    const { barberId, customerId, customerName, customerPhone, customerEmail, date, startTime, serviceId } = req.body;

    // Telefon numarası doğrulaması — Firebase ile doğrulanan numara eşleşmeli
    if (req.verifiedPhone !== customerPhone) {
      return res.status(403).json({ error: 'Doğrulanan telefon numarası ile eşleşmiyor.' });
    }

    // 1. Berber kontrolü
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== UserRole.BARBER) {
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

    // 4. Start/End Date objeleri + çakışma kontrolü
    const [rStartHour, rStartMinute] = startTime.split(':').map(Number);
    const startDateObj = new Date(date);
    startDateObj.setHours(rStartHour, rStartMinute, 0, 0);
    const endDateObj = new Date(startDateObj.getTime() + service.durationMinutes * 60000);

    // 4.5 Otomatik onay kontrolü
    let autoConfirm = false;
    if (barber.shopId) {
      const shop = await Shop.findById(barber.shopId);
      if (shop?.autoConfirmAppointments) autoConfirm = true;
    }

    // 5. Çakışma + bloke saat kontrolü + atomik oluşturma
    let appointment;
    try {
      appointment = await createAppointmentSafe({
        barberId,
        customerId,
        customerName,
        customerPhone,
        customerEmail: customerEmail || undefined,
        date,
        startTime: startDateObj,
        endTime: endDateObj,
        serviceId,
        ...(autoConfirm ? { status: 'confirmed' } : {}),
      });
    } catch (e) {
      if (e.code === 'SLOT_TAKEN' || e.code === 'SLOT_BLOCKED') {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }

    // 🔔 Berbere bildirim gönder (tercih kontrolü)
    if (barber.notificationPreferences?.push !== false && barber.notificationPreferences?.pushNewAppointment !== false) {
      sendToUser(barber, '📅 Yeni Randevu', `${customerName} — ${service.title} (${startTime})`, {
        type: 'new_appointment', appointmentId: appointment._id.toString()
      }).catch(err => console.error('Bildirim gönderilemedi:', err.message));
    }

    // 📧 Müşteriye e-posta (her zaman gider)
    const emailAddr = customerEmail || (customerId ? (await User.findById(customerId))?.email : null);
    if (emailAddr) {
      const shop = barber.shopId ? await Shop.findById(barber.shopId) : null;
      sendAppointmentCreated(emailAddr, {
        customerName,
        serviceName: service.title,
        barberName: barber.name,
        shopName: shop?.name || '',
        date: appointment.date,
        startTime: appointment.startTime,
      }).catch(err => console.error('E-posta gönderilemedi:', err.message));
    }

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


// Misafir randevu oluştur (Firebase telefon doğrulaması zorunlu)
router.post('/request', phoneVerificationMiddleware, async (req, res) => {
  try {
    const { barberId, serviceId, date, startTime, customerName, customerPhone, customerEmail } = req.body;

    // Telefon numarası doğrulaması — Firebase ile doğrulanan numara eşleşmeli
    if (req.verifiedPhone !== customerPhone) {
      return res.status(403).json({ error: 'Doğrulanan telefon numarası ile eşleşmiyor.' });
    }

    // Berber kontrolü
    const barber = await User.findById(barberId);
    if (!barber || barber.role !== UserRole.BARBER) return res.status(404).json({ error: 'Berber bulunamadı' });

    // Servis kontrolü
    const service = await Service.findById(serviceId);
    if (!service) return res.status(404).json({ error: 'Servis bulunamadı' });

    // startTime'ı Date objesine çevir ve endTime hesapla
    const [hours, minutes] = startTime.split(':').map(Number);
    const startDate = new Date(date);
    startDate.setHours(hours, minutes, 0, 0);
    const endDate = new Date(startDate.getTime() + service.durationMinutes * 60 * 1000);

    // Firebase ile doğrulanmış — çakışma kontrolü + oluşturma
    let appointment;
    try {
      appointment = await createAppointmentSafe({
        barberId,
        serviceId,
        date,
        startTime: startDate,
        endTime: endDate,
        customerName,
        customerPhone,
        customerEmail: customerEmail || undefined,
        status: 'confirmed',
      });
    } catch (e) {
      if (e.code === 'SLOT_TAKEN' || e.code === 'SLOT_BLOCKED') {
        return res.status(400).json({ error: e.message });
      }
      throw e;
    }

    // 🔔 Berbere bildirim gönder (tercih kontrolü)
    const timeStr = startTime;
    if (barber.notificationPreferences?.push !== false && barber.notificationPreferences?.pushNewAppointment !== false) {
      sendToUser(barber, '📅 Yeni Randevu', `${customerName} — ${service.title} (${timeStr})`, {
        type: 'new_appointment', appointmentId: appointment._id.toString()
      }).catch(err => console.error('Bildirim gönderilemedi:', err.message));
    }

    // 📧 Müşteriye e-posta (her zaman gider)
    if (customerEmail) {
      const shop = barber.shopId ? await Shop.findById(barber.shopId) : null;
      sendAppointmentCreated(customerEmail, {
        customerName,
        serviceName: service.title,
        barberName: barber.name,
        shopName: shop?.name || '',
        date: appointment.date,
        startTime: appointment.startTime,
      }).catch(err => console.error('E-posta gönderilemedi:', err.message));
    }

    return res.json({ message: 'Randevu başarıyla oluşturuldu', appointment });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ═══════════════════════════════════════════════════════════════
// ✅ MİSAFİR RANDEVU SORGULAMA (Telefon numarası ile)
// ═══════════════════════════════════════════════════════════════

// GET /api/appointment/guest-lookup?phone=+905xxxxxxxxx
router.get('/guest-lookup', async (req, res) => {
  try {
    const { phone } = req.query;
    if (!phone) {
      return res.status(400).json({ error: 'Telefon numarası zorunludur.' });
    }

    const appointments = await Appointment.find({
      customerPhone: phone,
      customerId: null, // Sadece misafir randevuları
    })
      .populate('barberId', 'name phone')
      .populate('serviceId', 'title price durationMinutes')
      .sort({ date: -1, startTime: -1 });

    res.json(appointments);
  } catch (err) {
    res.status(500).json({ error: 'Randevular yüklenemedi.' });
  }
});

module.exports = router;
