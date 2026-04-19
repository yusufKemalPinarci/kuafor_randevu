const cron = require('node-cron');
const Appointment = require('../models/Appointment');
const { User } = require('../models/User');
const Service = require('../models/Service');
const { sendToUser } = require('../utils/notificationService');
const { sendAppointmentReminder } = require('../utils/emailService');

/**
 * Her 5 dakikada bir çalışır.
 * 1 saat kala ve 15 dakika kala hatırlatma gönderir.
 */
function startReminderCron() {
  // Her 5 dakikada bir çalış
  cron.schedule('*/5 * * * *', async () => {
    try {
      const now = new Date();
      const in15min = new Date(now.getTime() + 15 * 60 * 1000);
      const in20min = new Date(now.getTime() + 20 * 60 * 1000);
      const in1hour = new Date(now.getTime() + 60 * 60 * 1000);
      const in65min = new Date(now.getTime() + 65 * 60 * 1000);

      // 1 saat kala hatırlatma (55-65 dk arası)
      // Atomik olarak flag'i set et — race condition önlenir
      const hourReminders = [];
      let hourCursor = await Appointment.find({
        status: 'confirmed',
        startTime: { $gte: in1hour, $lt: in65min },
        reminderSent1h: { $ne: true },
      }).populate('serviceId', 'title');

      for (const apt of hourCursor) {
        const updated = await Appointment.findOneAndUpdate(
          { _id: apt._id, reminderSent1h: { $ne: true } },
          { $set: { reminderSent1h: true } },
          { new: true }
        ).populate('serviceId', 'title');
        if (updated) {
          await sendReminder(updated, '1 saat', true);
          hourReminders.push(updated);
        }
      }

      // 15 dakika kala hatırlatma (10-20 dk arası)
      const shortReminders = [];
      let shortCursor = await Appointment.find({
        status: 'confirmed',
        startTime: { $gte: in15min, $lt: in20min },
        reminderSent15m: { $ne: true },
      }).populate('serviceId', 'title');

      for (const apt of shortCursor) {
        const updated = await Appointment.findOneAndUpdate(
          { _id: apt._id, reminderSent15m: { $ne: true } },
          { $set: { reminderSent15m: true } },
          { new: true }
        ).populate('serviceId', 'title');
        if (updated) {
          await sendReminder(updated, '15 dakika');
          shortReminders.push(updated);
        }
      }

      if (hourReminders.length > 0 || shortReminders.length > 0) {
        console.log(`⏰ Hatırlatma: ${hourReminders.length} adet 1s, ${shortReminders.length} adet 15dk`);
      }
    } catch (err) {
      console.error('Cron hatırlatma hatası:', err.message);
    }
  });

  console.log('⏰ Randevu hatırlatma cron\'u başlatıldı');
}

async function sendReminder(appointment, timeLabel, sendEmailReminder = false) {
  const timeStr = formatTime(appointment.startTime);
  const serviceName = appointment.serviceId?.title || 'Randevu';

  // Berbere hatırlatma (tercih kontrolü)
  const barber = await User.findById(appointment.barberId);
  if (barber && barber.notificationPreferences?.push !== false && barber.notificationPreferences?.pushReminder !== false) {
    await sendToUser(
      barber,
      `⏰ ${timeLabel} sonra randevu`,
      `${appointment.customerName} — ${serviceName} (${timeStr})`,
      { type: 'reminder', appointmentId: appointment._id.toString() }
    );
  }

  // Kayıtlı müşteriye hatırlatma (customerId varsa)
  if (appointment.customerId) {
    const customer = await User.findById(appointment.customerId);
    if (customer && customer.notificationPreferences?.push !== false
        && customer.notificationPreferences?.customerPushReminder !== false) {
      await sendToUser(
        customer,
        `⏰ Randevunuza ${timeLabel} kaldı`,
        `${serviceName} — ${timeStr}`,
        { type: 'reminder', appointmentId: appointment._id.toString() }
      );
    }
  }

  // 📧 1 saat kala e-posta hatırlatması
  if (sendEmailReminder && barber?.notificationPreferences?.emailReminder !== false) {
    const customerRecord = appointment.customerId ? await User.findById(appointment.customerId) : null;
    // Müşteri varsa ve e-posta hatırlatmasını kapattıysa gönderme
    if (!customerRecord || customerRecord.notificationPreferences?.customerEmailReminder !== false) {
      const customerEmail = appointment.customerEmail || customerRecord?.email;
      if (customerEmail) {
        sendAppointmentReminder(customerEmail, {
          customerName: appointment.customerName,
          serviceName,
          barberName: barber?.name || '',
          date: appointment.date,
          startTime: appointment.startTime,
        }).catch(err => console.error('Hatırlatma e-postası gönderilemedi:', err.message));
      }
    }
  }
}

function formatTime(date) {
  if (!date) return '';
  const d = new Date(date);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

module.exports = { startReminderCron };
