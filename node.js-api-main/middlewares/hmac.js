const crypto = require('crypto');

/**
 * HMAC-SHA256 request imza doğrulama middleware.
 *
 * İstemci her istekte şu header'ları gönderir:
 *   X-Timestamp : Unix millis
 *   X-Nonce     : Rastgele hex string
 *   X-Signature : HMAC-SHA256(secret, timestamp:nonce:method:path:bodyHash)
 *
 * Sunucu aynı algoritmayı uygular ve imzaları karşılaştırır.
 * Timestamp ±5 dakika toleransla kabul edilir (replay attack önlemi).
 *
 * .env'ye ekleyin:
 *   HMAC_SECRET=a3f8c2e91b7d054f6a2e8c3b9d1f7042
 */
const HMAC_SECRET = process.env.HMAC_SECRET;
const MAX_DRIFT_MS = 5 * 60 * 1000; // 5 dakika

const hmacMiddleware = (req, res, next) => {
  // Sadece production'da zorunlu
  if (process.env.NODE_ENV !== 'production') return next();

  // Health check muaf
  if (req.path.endsWith('/health')) return next();

  // HMAC_SECRET tanımlı değilse middleware pasif
  if (!HMAC_SECRET) return next();

  const timestamp = req.headers['x-timestamp'];
  const nonce     = req.headers['x-nonce'];
  const signature = req.headers['x-signature'];

  if (!timestamp || !nonce || !signature) {
    return res.status(403).json({ error: 'Erişim reddedildi.' });
  }

  // Timestamp kontrolü
  const reqTime = parseInt(timestamp, 10);
  if (isNaN(reqTime) || Math.abs(Date.now() - reqTime) > MAX_DRIFT_MS) {
    return res.status(403).json({ error: 'İstek zaman aşımına uğradı.' });
  }

  // İmza hesapla
  const rawBody  = req.rawBody || '';
  const bodyHash = crypto.createHash('sha256').update(rawBody).digest('hex');
  const data     = `${timestamp}:${nonce}:${req.method}:${req.path}:${bodyHash}`;
  const expected = crypto.createHmac('sha256', HMAC_SECRET).update(data).digest('hex');

  // Timing-safe karşılaştırma
  if (
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature, 'utf8'), Buffer.from(expected, 'utf8'))
  ) {
    return res.status(403).json({ error: 'Geçersiz imza.' });
  }

  next();
};

module.exports = hmacMiddleware;
