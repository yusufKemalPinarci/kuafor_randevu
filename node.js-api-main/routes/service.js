const express = require('express');
const Service = require('../models/Service');

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
router.post('/', async (req, res) => {
  try {
    const service = new Service(req.body);
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
router.put('/:id', async (req, res) => {
  try {
    const serviceId = req.params.id;
    const { title, price, durationMinutes } = req.body;

    const updatedService = await Service.findByIdAndUpdate(
      serviceId,
      { title, price, durationMinutes },
      { new: true, runValidators: true }
    );

    if (!updatedService) {
      return res.status(404).json({ error: 'Service not found' });
    }

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



module.exports = router;
