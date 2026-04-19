const cron = require('node-cron');
const Appointment = require('../models/Appointment');
const { User, UserRole } = require('../models/User');
const Service = require('../models/Service');
const { Subscription } = require('../models/Subscription');
const { sendDailySummary } = require('../utils/emailService');

/**
 * Her gün saat 20:00'de çalışır.
 * Ertesi günün randevu programını berberlere e-posta ile gönderir.
 */
function startDailySummaryCron() {
  // Her gün 20:00'de çalış
  cron.schedule('0 20 * * *', async () => {
    try {
      // Yarının tarih aralığı
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const dayAfter = new Date(tomorrow);
      dayAfter.setDate(dayAfter.getDate() + 1);

      // E-postası olan tüm berberleri bul
      const barbers = await User.find({ role: UserRole.BARBER, email: { $exists: true, $ne: '' } });

      let sentCount = 0;

      for (const barber of barbers) {
        // E-posta tercihi veya günlük özet tercihi kapalıysa atla
        if (barber.notificationPreferences?.email === false) continue;
        if (barber.notificationPreferences?.emailDailySummary === false) continue;

        // Aktif abonelik yoksa e-posta gönderme (Standart+ gerekli)
        const sub = await Subscription.findOne({
          ownerId: barber._id,
          status: 'active',
          endDate: { $gt: new Date() },
        });
        if (!sub) continue;

        // Bu berberin yarınki onaylı randevuları
        const appointments = await Appointment.find({
          barberId: barber._id,
          date: { $gte: tomorrow, $lt: dayAfter },
          status: { $in: ['pending', 'confirmed'] },
        })
          .populate('serviceId', 'title')
          .sort({ startTime: 1 });

        // Randevu yoksa da özet gönder (berberin haberi olsun)
        const summaryData = appointments.map(a => ({
          startTime: a.startTime,
          customerName: a.customerName,
          serviceName: a.serviceId?.title || '-',
        }));

        const sent = await sendDailySummary(barber.email, {
          barberName: barber.name,
          date: tomorrow,
          appointments: summaryData,
        });

        if (sent) sentCount++;
      }

      if (sentCount > 0) {
        console.log(`📋 Günlük özet: ${sentCount} berbere e-posta gönderildi`);
      }
    } catch (err) {
      console.error('Günlük özet cron hatası:', err.message);
    }
  });

  console.log('📋 Günlük özet cron\'u başlatıldı (her gün 20:00)');
}

module.exports = { startDailySummaryCron };
