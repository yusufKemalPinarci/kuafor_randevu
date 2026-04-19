const admin = require('firebase-admin');

// Firebase Admin SDK başlatma
let firebaseInitialized = false;

async function initFirebase() {
  if (firebaseInitialized) return;

  try {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
      : require('../serviceAccountKey.json');

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    console.log('✅ Firebase Admin SDK başlatıldı');
  } catch (err) {
    console.error('⚠️ Firebase Admin SDK başlatılamadı:', err.message);
  }
}

/**
 * Tek bir FCM token'a bildirim gönderir.
 * Geçersiz token varsa siler.
 */
async function sendToToken(token, title, body, data = {}) {
  if (!firebaseInitialized) initFirebase();
  if (!firebaseInitialized || !token) return false;

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority: 'high',
        notification: {
          channelId: 'kuaflex_appointments',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
    return true;
  } catch (err) {
    // Token artık geçerli değilse false dön — çağıran taraf temizler
    if (
      err.code === 'messaging/invalid-registration-token' ||
      err.code === 'messaging/registration-token-not-registered'
    ) {
      return false;
    }
    console.error('FCM gönderim hatası:', err.message);
    return false;
  }
}

/**
 * Bir kullanıcının tüm cihazlarına bildirim gönderir.
 * Geçersiz token'ları otomatik temizler.
 */
async function sendToUser(user, title, body, data = {}) {
  if (!user || !user.fcmTokens || user.fcmTokens.length === 0) return;

  const invalidTokens = [];

  for (const token of user.fcmTokens) {
    const success = await sendToToken(token, title, body, data);
    if (!success) invalidTokens.push(token);
  }

  // Geçersiz token'ları DB'den temizle
  if (invalidTokens.length > 0) {
    console.warn(`⚠️ ${invalidTokens.length} geçersiz FCM token silindi (user: ${user._id})`);
    user.fcmTokens = user.fcmTokens.filter(t => !invalidTokens.includes(t));
    await user.save();
  }
}

module.exports = { initFirebase, sendToToken, sendToUser };
