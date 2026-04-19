const express = require('express');
const Service = require('../models/Service');
const authMiddleware = require('../middlewares/auth');
const subscriptionMiddleware = require('../middlewares/subscription');

const router = express.Router();

/**
 * @swagger
 * tags:
 *   name: Service
 *   description: Berber servis işlemleri
 */

/**
 * @swagger
 * /api/service:
 *   post:
 *     summary: Yeni servis oluştur
 *     tags: [Service]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               price:
 *                 type: number
 *               durationMinutes:
 *                 type: number
 *               barberId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Servis başarıyla oluşturuldu
 */
//yeni servis oluşturmak için berberler kullanır.
router.post('/', authMiddleware, subscriptionMiddleware, async (req, res) => {
  try {
    // SECURITY: barberId must match authenticated user
    const service = new Service({ ...req.body, barberId: req.user._id });
    await service.save();
    res.json(service);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});


/**
 * @swagger
 * /api/service:
 *   get:
 *     summary: Tüm servisleri getir
 *     tags: [Service]
 *     responses:
 *       200:
 *         description: Servis listesi
 */
router.get('/', async (req, res) => {
  const services = await Service.find();

;
  res.json(services);
});


/**
 * @swagger
 * /api/service/{id}:
 *   put:
 *     summary: Servisi güncelle
 *     tags: [Service]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Güncellenecek servisin ID'si
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               price:
 *                 type: number
 *               durationMinutes:
 *                 type: number
 *     responses:
 *       200:
 *         description: Servis başarıyla güncellendi
 *       404:
 *         description: Servis bulunamadı
 */
// ilgili servisi güncellemek için berberler kullanır
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const serviceId = req.params.id;
    const { title, price, durationMinutes } = req.body;

    // SECURITY: Verify ownership before update
    const existing = await Service.findById(serviceId);
    if (!existing) return res.status(404).json({ error: 'Service not found' });
    if (existing.barberId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Bu servisi güncelleme yetkiniz yok.' });
    }

    const updatedService = await Service.findByIdAndUpdate(
      serviceId,
      { title, price, durationMinutes },
      { new: true, runValidators: true }
    );

    res.json(updatedService);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * @swagger
 * /api/service/{barberId}/services:
 *   get:
 *     summary: Belirli berbere ait servisleri getir
 *     tags: [Service]
 *     parameters:
 *       - in: path
 *         name: barberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Berberin ID'si
 *     responses:
 *       200:
 *         description: Servis listesi
 */
// Örnek: /api/barber/:barberId/services
router.get('/:barberId/services', async (req, res) => {
  try {
    const { barberId } = req.params;
    const services = await Service.find({ barberId });
    res.json(services);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// Servisi sil
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    // SECURITY: Verify ownership before delete
    const service = await Service.findById(req.params.id);
    if (!service) return res.status(404).json({ error: 'Service not found' });
    if (service.barberId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Bu servisi silme yetkiniz yok.' });
    }

    // Aktif randevusu varsa silmeyi engelle
    const Appointment = require('../models/Appointment');
    const activeCount = await Appointment.countDocuments({
      serviceId: req.params.id,
      status: { $in: ['pending', 'confirmed'] }
    });
    if (activeCount > 0) {
      return res.status(400).json({ error: `Bu hizmete ait ${activeCount} aktif randevu bulunuyor. Önce randevuları iptal edin.` });
    }

    await Service.findByIdAndDelete(req.params.id);
    res.json({ message: 'Service deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


module.exports = router;
