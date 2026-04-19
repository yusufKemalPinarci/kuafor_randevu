const admin = require('firebase-admin');
const { initFirebase } = require('../utils/notificationService');

/**
 * Firebase Phone Auth ile telefon doğrulama middleware'i.
 * Authorization header'dan Firebase ID token alır,
 * admin SDK ile doğrular ve phone_number claim'ini req.verifiedPhone'a yazar.
 */
const phoneVerificationMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Telefon doğrulaması gerekli. Lütfen önce telefonunuzu doğrulayın.' });
  }

  const idToken = authHeader.split(' ')[1];

  try {
    await initFirebase();
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    const phoneNumber = decodedToken.phone_number;
    if (!phoneNumber) {
      return res.status(401).json({ error: 'Firebase token telefon bilgisi içermiyor.' });
    }

    req.verifiedPhone = phoneNumber;
    next();
  } catch (err) {
    if (err.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Doğrulama süresi doldu. Lütfen tekrar deneyin.' });
    }
    if (err.code === 'auth/argument-error' || err.code === 'auth/id-token-revoked') {
      return res.status(401).json({ error: 'Geçersiz doğrulama token.' });
    }
    return res.status(401).json({ error: 'Telefon doğrulaması başarısız.' });
  }
};

module.exports = phoneVerificationMiddleware;
