const nodemailer = require('nodemailer');

// ─── Transporter (lazy singleton) ─────────────────────────────
let _transporter = null;

function getTransporter() {
  if (_transporter) return _transporter;
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    return null;
  }
  _transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT) || 587,
    secure: false,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  return _transporter;
}

// ─── Ortak mail gönderim fonksiyonu ────────────────────────────
async function sendEmail(to, subject, html) {
  const transporter = getTransporter();
  if (!transporter) return false;
  try {
    await transporter.sendMail({
      from: `"KuaFlex" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html,
    });
    return true;
  } catch (err) {
    console.error('📧 E-posta gönderilemedi:', err.message);
    return false;
  }
}

// ─── Tarih/saat formatlayıcılar ────────────────────────────────
function formatTime(date) {
  if (!date) return '';
  const d = new Date(date);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function formatDate(date) {
  if (!date) return '';
  const d = new Date(date);
  const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

// ─── E-posta şablonu wrapper ───────────────────────────────────
function wrapTemplate(content) {
  return `
  <div style="font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;max-width:500px;margin:0 auto;background:#fafafa;border:1px solid #eee;border-radius:12px;overflow:hidden">
    <div style="background:#1a1a2e;padding:20px 24px">
      <h2 style="margin:0;color:#C69749;font-size:22px">KuaFlex</h2>
    </div>
    <div style="padding:24px">
      ${content}
    </div>
    <div style="background:#f0f0f0;padding:14px 24px;text-align:center">
      <p style="margin:0;color:#999;font-size:12px">Bu e-posta KuaFlex tarafından otomatik gönderilmiştir.</p>
    </div>
  </div>`;
}

// ═══════════════════════════════════════════════════════════════
// Randevu oluşturuldu — müşteriye bilgi
// ═══════════════════════════════════════════════════════════════
async function sendAppointmentCreated(email, { customerName, serviceName, barberName, shopName, date, startTime }) {
  const html = wrapTemplate(`
    <h3 style="color:#333;margin-top:0">Merhaba ${customerName} 👋</h3>
    <p style="color:#555">Randevunuz başarıyla oluşturuldu.</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px 0;color:#888;width:120px">Hizmet</td><td style="padding:8px 0;color:#333;font-weight:600">${serviceName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Berber</td><td style="padding:8px 0;color:#333;font-weight:600">${barberName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Salon</td><td style="padding:8px 0;color:#333;font-weight:600">${shopName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Tarih</td><td style="padding:8px 0;color:#333;font-weight:600">${formatDate(date)}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Saat</td><td style="padding:8px 0;color:#333;font-weight:600">${formatTime(startTime)}</td></tr>
    </table>
    <p style="color:#888;font-size:13px">Randevunuz onay bekliyor. Onaylandığında size bildirim göndereceğiz.</p>
  `);
  return sendEmail(email, 'Randevunuz Oluşturuldu — KuaFlex', html);
}

// ═══════════════════════════════════════════════════════════════
// Randevu onaylandı — müşteriye bilgi
// ═══════════════════════════════════════════════════════════════
async function sendAppointmentConfirmed(email, { customerName, serviceName, barberName, date, startTime }) {
  const html = wrapTemplate(`
    <h3 style="color:#333;margin-top:0">Randevunuz Onaylandı ✅</h3>
    <p style="color:#555">Merhaba ${customerName}, randevunuz onaylandı.</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px 0;color:#888;width:120px">Hizmet</td><td style="padding:8px 0;color:#333;font-weight:600">${serviceName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Berber</td><td style="padding:8px 0;color:#333;font-weight:600">${barberName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Tarih</td><td style="padding:8px 0;color:#333;font-weight:600">${formatDate(date)}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Saat</td><td style="padding:8px 0;color:#333;font-weight:600">${formatTime(startTime)}</td></tr>
    </table>
    <p style="color:#2d7d46;font-weight:600">Lütfen randevunuza zamanında gelmeyi unutmayın.</p>
  `);
  return sendEmail(email, 'Randevunuz Onaylandı ✅ — KuaFlex', html);
}

// ═══════════════════════════════════════════════════════════════
// Randevu iptal edildi — müşteriye bilgi
// ═══════════════════════════════════════════════════════════════
async function sendAppointmentCancelled(email, { customerName, serviceName, barberName, date, startTime }) {
  const html = wrapTemplate(`
    <h3 style="color:#333;margin-top:0">Randevunuz İptal Edildi ❌</h3>
    <p style="color:#555">Merhaba ${customerName}, aşağıdaki randevunuz iptal edilmiştir.</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px 0;color:#888;width:120px">Hizmet</td><td style="padding:8px 0;color:#333;font-weight:600">${serviceName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Berber</td><td style="padding:8px 0;color:#333;font-weight:600">${barberName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Tarih</td><td style="padding:8px 0;color:#333;font-weight:600">${formatDate(date)}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Saat</td><td style="padding:8px 0;color:#333;font-weight:600">${formatTime(startTime)}</td></tr>
    </table>
    <p style="color:#888;font-size:13px">Yeni bir randevu oluşturmak için uygulamayı kullanabilirsiniz.</p>
  `);
  return sendEmail(email, 'Randevunuz İptal Edildi — KuaFlex', html);
}

// ═══════════════════════════════════════════════════════════════
// 1 saat kala hatırlatma — müşteriye
// ═══════════════════════════════════════════════════════════════
async function sendAppointmentReminder(email, { customerName, serviceName, barberName, date, startTime }) {
  const html = wrapTemplate(`
    <h3 style="color:#333;margin-top:0">Randevu Hatırlatması ⏰</h3>
    <p style="color:#555">Merhaba ${customerName}, randevunuza <strong>1 saat</strong> kaldı!</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0">
      <tr><td style="padding:8px 0;color:#888;width:120px">Hizmet</td><td style="padding:8px 0;color:#333;font-weight:600">${serviceName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Berber</td><td style="padding:8px 0;color:#333;font-weight:600">${barberName}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Tarih</td><td style="padding:8px 0;color:#333;font-weight:600">${formatDate(date)}</td></tr>
      <tr><td style="padding:8px 0;color:#888">Saat</td><td style="padding:8px 0;color:#333;font-weight:600">${formatTime(startTime)}</td></tr>
    </table>
    <p style="color:#C69749;font-weight:600">Lütfen zamanında salonda olun 💈</p>
  `);
  return sendEmail(email, 'Randevunuza 1 Saat Kaldı ⏰ — KuaFlex', html);
}

// ═══════════════════════════════════════════════════════════════
// Gün sonu berber özet maili
// ═══════════════════════════════════════════════════════════════
async function sendDailySummary(email, { barberName, date, appointments }) {
  let rows = '';
  if (appointments.length === 0) {
    rows = '<tr><td colspan="3" style="padding:12px;text-align:center;color:#888">Yarın için randevu yok</td></tr>';
  } else {
    rows = appointments.map(a => `
      <tr>
        <td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333">${formatTime(a.startTime)}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333">${a.customerName}</td>
        <td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333">${a.serviceName || '-'}</td>
      </tr>
    `).join('');
  }

  const html = wrapTemplate(`
    <h3 style="color:#333;margin-top:0">Günlük Randevu Özeti 📋</h3>
    <p style="color:#555">Merhaba ${barberName}, yarınki (${formatDate(date)}) randevu programınız:</p>
    <table style="width:100%;border-collapse:collapse;margin:16px 0;border:1px solid #eee;border-radius:8px">
      <tr style="background:#f5f5f5">
        <th style="padding:10px 12px;text-align:left;color:#666;font-size:13px">Saat</th>
        <th style="padding:10px 12px;text-align:left;color:#666;font-size:13px">Müşteri</th>
        <th style="padding:10px 12px;text-align:left;color:#666;font-size:13px">Hizmet</th>
      </tr>
      ${rows}
    </table>
    <p style="color:#888;font-size:13px">Toplam: <strong>${appointments.length}</strong> randevu</p>
  `);
  return sendEmail(email, `Yarınki Randevu Programınız (${appointments.length} randevu) — KuaFlex`, html);
}

module.exports = {
  sendAppointmentCreated,
  sendAppointmentConfirmed,
  sendAppointmentCancelled,
  sendAppointmentReminder,
  sendDailySummary,
};
