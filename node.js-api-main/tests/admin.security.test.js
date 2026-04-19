/**
 * admin.security.test.js
 *
 * Admin endpoint'lerine yetkisiz erişim testleri.
 * Kapsanan saldırılar: yatay yetki yükseltme, sahte token,
 * Customer/Barber → Admin erişim girişimi.
 */

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');

// ─── Mock'lar ─────────────────────────────────────────────────────────────────

jest.mock('../models/User', () => ({
  User: {
    findById: jest.fn(),
    find: jest.fn().mockResolvedValue([]),
    countDocuments: jest.fn().mockResolvedValue(0),
  },
  UserRole: { CUSTOMER: 'Customer', BARBER: 'Barber', ADMIN: 'Admin' },
}));

jest.mock('../models/Shop', () => ({
  countDocuments: jest.fn().mockResolvedValue(0),
  find: jest.fn().mockResolvedValue([]),
}));

jest.mock('../models/Appointment', () => ({
  countDocuments: jest.fn().mockResolvedValue(0),
  find: jest.fn().mockResolvedValue([]),
}));

jest.mock('../models/Subscription', () => {
  const makeChain = (result) => {
    const chain = {
      sort: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      populate: jest.fn().mockReturnThis(),
      then: (resolve, reject) => Promise.resolve(result).then(resolve, reject),
      catch: (reject) => Promise.resolve(result).catch(reject),
      finally: (cb) => Promise.resolve(result).finally(cb),
    };
    return chain;
  };
  return {
    Subscription: {
      find: jest.fn().mockImplementation(() => makeChain([])),
      findById: jest.fn(),
      countDocuments: jest.fn().mockResolvedValue(0),
      findByIdAndUpdate: jest.fn(),
    },
    SubscriptionPlan: { MONTHLY: 'monthly', YEARLY: 'yearly', FREE_TRIAL: 'free_trial' },
    SubscriptionStatus: { ACTIVE: 'active', EXPIRED: 'expired' },
  };
});

jest.mock('../models/PromoCode', () => ({
  find: jest.fn().mockResolvedValue([]),
  findById: jest.fn(),
  findByIdAndUpdate: jest.fn(),
  countDocuments: jest.fn().mockResolvedValue(0),
  prototype: {},
}));

jest.mock('../models/Settings', () => ({
  findOne: jest.fn().mockResolvedValue(null),
  findOneAndUpdate: jest.fn().mockResolvedValue({ key: 'test', value: 30 }),
}));

jest.mock('../models/Service', () => ({
  countDocuments: jest.fn().mockResolvedValue(0),
}));

// ─── Setup ────────────────────────────────────────────────────────────────────

const { User } = require('../models/User');
const adminRoutes = require('../routes/admin');

const app = express();
app.use(express.json());
app.use('/api/admin', adminRoutes);

// ─── Token Üreticiler ─────────────────────────────────────────────────────────

function makeToken(userId, role) {
  return jwt.sign(
    { id: userId, sub: `${role.toLowerCase()}@test.com`, role },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
}

const customerToken = makeToken('cust-01', 'Customer');
const barberToken = makeToken('barber-01', 'Barber');
const adminToken = makeToken('admin-01', 'Admin');

// ─── Testler ──────────────────────────────────────────────────────────────────

describe('Admin Routes — Yetki Yükseltme Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  // ── Kimlik Doğrulama Eksik ────────────────────────────────────────────────

  test('GÜVENLİK: Token olmadan /subscriptions → 401', async () => {
    const res = await request(app).get('/api/admin/subscriptions');
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: Token olmadan /users → 401', async () => {
    const res = await request(app).get('/api/admin/users');
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: Token olmadan /dashboard → 401', async () => {
    const res = await request(app).get('/api/admin/dashboard');
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: Token olmadan /settings → 401', async () => {
    const res = await request(app).get('/api/admin/settings');
    expect(res.status).toBe(401);
  });

  // ── Yetersiz Yetki ────────────────────────────────────────────────────────

  test('GÜVENLİK: Customer token ile /subscriptions → 403', async () => {
    User.findById.mockResolvedValue({ _id: 'cust-01', role: 'Customer' });
    const res = await request(app)
      .get('/api/admin/subscriptions')
      .set('Authorization', `Bearer ${customerToken}`);
    expect(res.status).toBe(403);
  });

  test('GÜVENLİK: Barber token ile /subscriptions → 403', async () => {
    User.findById.mockResolvedValue({ _id: 'barber-01', role: 'Barber' });
    const res = await request(app)
      .get('/api/admin/subscriptions')
      .set('Authorization', `Bearer ${barberToken}`);
    expect(res.status).toBe(403);
  });

  test('GÜVENLİK: Customer token ile /users → 403', async () => {
    User.findById.mockResolvedValue({ _id: 'cust-01', role: 'Customer' });
    const res = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${customerToken}`);
    expect(res.status).toBe(403);
  });

  test('GÜVENLİK: Customer token ile ayarları değiştirme → 403', async () => {
    User.findById.mockResolvedValue({ _id: 'cust-01', role: 'Customer' });
    const res = await request(app)
      .put('/api/admin/settings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ referralBonusDays: 999 });
    expect(res.status).toBe(403);
  });

  test('GÜVENLİK: Barber token ile ayarları değiştirme → 403', async () => {
    User.findById.mockResolvedValue({ _id: 'barber-01', role: 'Barber' });
    const res = await request(app)
      .put('/api/admin/settings')
      .set('Authorization', `Bearer ${barberToken}`)
      .send({ referralBonusDays: 999 });
    expect(res.status).toBe(403);
  });

  // ── Sahte Token Saldırıları ───────────────────────────────────────────────

  test('GÜVENLİK: Payload\'da role:Admin ama yanlış secret ile imzalanmış → 401', async () => {
    const forgedToken = jwt.sign(
      { id: 'evil-user', role: 'Admin' },
      'attacker-does-not-know-real-secret',
      { expiresIn: '7d' }
    );
    const res = await request(app)
      .get('/api/admin/subscriptions')
      .set('Authorization', `Bearer ${forgedToken}`);
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: alg:none ile Admin yetkisi kazanma girişimi → 401', async () => {
    const header = Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({ id: 'evil', role: 'Admin', sub: 'evil@evil.com' })
    ).toString('base64url');
    const noneToken = `${header}.${payload}.`;

    const res = await request(app)
      .get('/api/admin/subscriptions')
      .set('Authorization', `Bearer ${noneToken}`);
    expect(res.status).toBe(401);
  });

  // ── Admin Erişimi Başarılı ────────────────────────────────────────────────

  test('BAŞARI: Admin token ile /subscriptions → 401/403 değil', async () => {
    User.findById.mockResolvedValue({ _id: 'admin-01', role: 'Admin' });
    const { Subscription } = require('../models/Subscription');
    Subscription.find.mockReturnValue({
      sort: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      populate: jest.fn().mockReturnThis(),
      then: (resolve, reject) => Promise.resolve([]).then(resolve, reject),
      catch: (reject) => Promise.resolve([]).catch(reject),
      finally: (cb) => Promise.resolve([]).finally(cb),
    });
    Subscription.countDocuments.mockResolvedValue(0);

    const res = await request(app)
      .get('/api/admin/subscriptions')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });

  test('BAŞARI: Admin token ile /settings → 401/403 değil', async () => {
    User.findById.mockResolvedValue({ _id: 'admin-01', role: 'Admin' });
    const Settings = require('../models/Settings');
    Settings.findOne.mockResolvedValue({ key: 'referralBonusDays', value: 30 });

    const res = await request(app)
      .get('/api/admin/settings')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});
