/**
 * auth.middleware.test.js
 *
 * JWT kimlik doğrulama middleware'inin güvenlik testleri.
 * Saldırı senaryoları: alg:none, signature tampering, expired token,
 * silinen kullanıcı, yanlış secret, random string vb.
 */

const jwt = require('jsonwebtoken');

jest.mock('../models/User', () => ({
  User: {
    findById: jest.fn(),
  },
  UserRole: { CUSTOMER: 'Customer', BARBER: 'Barber', ADMIN: 'Admin' },
}));

const { User } = require('../models/User');
const authMiddleware = require('../middlewares/auth');

// ─── Yardımcı fonksiyonlar ────────────────────────────────────────────────────

function makeReq(token) {
  return {
    headers: {
      authorization: token ? `Bearer ${token}` : undefined,
    },
  };
}

function makeRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function validToken(overrides = {}) {
  return jwt.sign(
    { id: 'user123', sub: 'test@test.com', role: 'Customer', ...overrides },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
}

// ─── Testler ──────────────────────────────────────────────────────────────────

describe('Auth Middleware — Güvenlik Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  // ── Eksik/Hatalı Header ───────────────────────────────────────────────────

  test('GÜVENLIK: Authorization header yok → 401 döner', async () => {
    const req = { headers: {} };
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Authorization header var ama Bearer prefix yok → 401', async () => {
    const req = { headers: { authorization: 'Basic dXNlcjpwYXNz' } };
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Tamamen rastgele string token olarak gönderilir → 401', async () => {
    const req = makeReq('bu-bir-jwt-degildir-ama-bearer-sonrasi-geldi');
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Boş Bearer token → 401', async () => {
    const req = { headers: { authorization: 'Bearer ' } };
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  // ── JWT Saldırıları ───────────────────────────────────────────────────────

  test('GÜVENLIK: alg:none saldırısı (imzasız JWT) → 401', async () => {
    // Saldırgan kendi payload'ını imzasız gönderiyor
    const header = Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({ id: 'evil-admin-id', role: 'Admin', sub: 'evil@evil.com' })
    ).toString('base64url');
    const noneToken = `${header}.${payload}.`;

    const req = makeReq(noneToken);
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Süresi dolmuş JWT → 401', async () => {
    const expiredToken = jwt.sign(
      { id: 'user123', sub: 'test@test.com' },
      process.env.JWT_SECRET,
      { expiresIn: '-1s' }  // geçmişte süresi dolmuş
    );
    const req = makeReq(expiredToken);
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: İmza manipülasyonu (son karakter değiştirilmiş) → 401', async () => {
    const token = validToken();
    const parts = token.split('.');
    const lastChar = parts[2].slice(-1);
    const manipulated = parts[2].slice(0, -1) + (lastChar === 'A' ? 'B' : 'A');
    const tamperedToken = `${parts[0]}.${parts[1]}.${manipulated}`;

    const req = makeReq(tamperedToken);
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Payload manipülasyonu (role:Admin olarak değiştirilmiş) → 401', async () => {
    const token = validToken({ role: 'Customer' });
    const parts = token.split('.');
    // Payload'ı decode edip Admin role ile yeniden encode et
    const originalPayload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    originalPayload.role = 'Admin';
    const manipulatedPayload = Buffer.from(JSON.stringify(originalPayload)).toString('base64url');
    const tamperedToken = `${parts[0]}.${manipulatedPayload}.${parts[2]}`;

    const req = makeReq(tamperedToken);
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('GÜVENLIK: Yanlış secret ile imzalanmış JWT → 401', async () => {
    const wrongToken = jwt.sign(
      { id: 'user123', role: 'Admin' },
      'wrong-secret-key-attacker-knows',
      { expiresIn: '7d' }
    );
    const req = makeReq(wrongToken);
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  // ── Silinmiş Kullanıcı ────────────────────────────────────────────────────

  test('GÜVENLIK: Geçerli JWT ama kullanıcı veritabanında yok (hesap silindi) → 401', async () => {
    User.findById.mockResolvedValue(null);
    const req = makeReq(validToken());
    const res = makeRes();
    await authMiddleware(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  // ── Başarılı Durum ─────────────────────────────────────────────────────────

  test('BAŞARI: Geçerli JWT + mevcut kullanıcı → next() çağrılır', async () => {
    const mockUser = { _id: 'user123', email: 'test@test.com', role: 'Customer' };
    User.findById.mockResolvedValue(mockUser);
    const req = makeReq(validToken());
    const res = makeRes();
    const next = jest.fn();

    await authMiddleware(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.user).toEqual(mockUser);
    expect(res.status).not.toHaveBeenCalled();
  });

  test('BAŞARI: Admin rolündeki geçerli token → next() çağrılır', async () => {
    const adminUser = { _id: 'admin1', email: 'admin@test.com', role: 'Admin' };
    User.findById.mockResolvedValue(adminUser);
    const adminToken = jwt.sign(
      { id: 'admin1', sub: 'admin@test.com', role: 'Admin' },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );
    const req = makeReq(adminToken);
    const res = makeRes();
    const next = jest.fn();

    await authMiddleware(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.user).toEqual(adminUser);
  });
});
