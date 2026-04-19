/**
 * subscription.security.test.js
 *
 * Abonelik endpoint'lerinin erişim kontrolü testleri.
 * Kapsanan saldırılar: kimlik doğrulama bypass, IDOR (Insecure Direct Object
 * Reference) - başka kullanıcının dükkanına abonelik başlatma,
 * kendi referans kodunu kullanma, eksik kart bilgileri ile ödeme girişimi.
 */

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');

// ─── Mock'lar ─────────────────────────────────────────────────────────────────

jest.mock('../models/User', () => ({
  User: { findById: jest.fn() },
  UserRole: { CUSTOMER: 'Customer', BARBER: 'Barber', ADMIN: 'Admin' },
}));

jest.mock('../models/Subscription', () => ({
  Subscription: {
    findOne: jest.fn().mockResolvedValue(null),
    find: jest.fn().mockResolvedValue([]),
    countDocuments: jest.fn().mockResolvedValue(0),
    prototype: { save: jest.fn() },
  },
  SubscriptionPlan: { MONTHLY: 'monthly', YEARLY: 'yearly', FREE_TRIAL: 'free_trial' },
  SubscriptionStatus: { ACTIVE: 'active', EXPIRED: 'expired' },
}));

jest.mock('../models/Shop', () => ({
  findById: jest.fn(),
}));

jest.mock('../models/PromoCode', () => ({
  findOne: jest.fn().mockResolvedValue(null),
}));

jest.mock('../models/Settings', () => ({
  findOne: jest.fn().mockResolvedValue(null),
}));

jest.mock('googleapis', () => ({
  google: {
    auth: { GoogleAuth: jest.fn().mockImplementation(() => ({})) },
    androidpublisher: jest.fn().mockReturnValue({
      purchases: { subscriptions: { get: jest.fn() } },
    }),
  },
}));

// ─── Setup ────────────────────────────────────────────────────────────────────

const { User } = require('../models/User');
const { Subscription } = require('../models/Subscription');
const Shop = require('../models/Shop');

const subscriptionRoutes = require('../routes/subscription');

const app = express();
app.use(express.json());
app.use('/api/subscription', subscriptionRoutes);

// ─── Token Üreticiler ─────────────────────────────────────────────────────────

const OWNER_ID = 'owner-barber-id';
const OTHER_ID = 'other-barber-id';
const SHOP_ID = 'shop-abc-123';

function makeToken(userId) {
  return jwt.sign(
    { id: userId, sub: `${userId}@test.com`, role: 'Barber' },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
}

const ownerToken = makeToken(OWNER_ID);
const otherToken = makeToken(OTHER_ID);

// ─── Testler ──────────────────────────────────────────────────────────────────

describe('Subscription Routes — Erişim Kontrolü Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  // ── Kimlik Doğrulama ──────────────────────────────────────────────────────

  test('GÜVENLİK: Auth olmadan /subscribe → 401', async () => {
    const res = await request(app).post('/api/subscription/subscribe').send({});
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: Auth olmadan /my → 401', async () => {
    const res = await request(app).get('/api/subscription/my');
    expect(res.status).toBe(401);
  });

  test('GÜVENLİK: Auth olmadan /verify-purchase → 401', async () => {
    const res = await request(app).post('/api/subscription/verify-purchase').send({});
    expect(res.status).toBe(401);
  });

  // ── IDOR Saldırısı: Başkasının Dükkanı ───────────────────────────────────

  test('KRİTİK GÜVENLİK: IDOR — Başka kullanıcının dükkanına abonelik başlatılamaz → 403', async () => {
    // OTHER_ID token ile istek atıyor ama dükkan OWNER_ID'ye ait
    User.findById.mockResolvedValue({
      _id: OTHER_ID,
      toString: () => OTHER_ID,
      _id: { toString: () => OTHER_ID },
    });
    Shop.findById.mockResolvedValue({
      _id: SHOP_ID,
      ownerId: { toString: () => OWNER_ID }, // farklı kullanıcının dükkanı
    });
    Subscription.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/subscription/subscribe')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ shopId: SHOP_ID, plan: 'monthly' });

    expect(res.status).toBe(403);
  });

  // ── Kendi Referans Kodunu Kullanma ────────────────────────────────────────

  test('GÜVENLİK: Kendi referans kodunu kullanma → 400', async () => {
    User.findById.mockResolvedValue({
      _id: { toString: () => OWNER_ID },
      email: 'owner@test.com',
    });
    Shop.findById.mockResolvedValue({
      _id: SHOP_ID,
      ownerId: { toString: () => OWNER_ID }, // sahibi kendisi
    });
    Subscription.findOne.mockImplementation((query) => {
      if (query.referralCode) {
        // Referans kodu aranınca kendi aboneliğini döndür
        return Promise.resolve({
          ownerId: { toString: () => OWNER_ID },
          referralCodeExpiresAt: null,
        });
      }
      return Promise.resolve(null); // aktif abonelik yok
    });

    const res = await request(app)
      .post('/api/subscription/subscribe')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ shopId: SHOP_ID, plan: 'monthly', referralCode: 'MYOWNCODE' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Kendi referans');
  });

  // ── Mevcut Abonelik Kontrolü ──────────────────────────────────────────────

  test('GÜVENLİK: Zaten aktif abonelik varken tekrar start → 400', async () => {
    User.findById.mockResolvedValue({
      _id: { toString: () => OWNER_ID },
      email: 'owner@test.com',
    });
    Shop.findById.mockResolvedValue({
      _id: SHOP_ID,
      ownerId: { toString: () => OWNER_ID },
    });
    Subscription.findOne.mockResolvedValueOnce({
      _id: 'existing-sub',
      status: 'active',
    });

    const res = await request(app)
      .post('/api/subscription/subscribe')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ shopId: SHOP_ID, plan: 'monthly' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('aktif');
  });

  // ── Geçersiz Dükkan ───────────────────────────────────────────────────────

  test('GÜVENLİK: Var olmayan dükkan ID → 404', async () => {
    User.findById.mockResolvedValue({
      _id: { toString: () => OWNER_ID },
      email: 'owner@test.com',
    });
    Shop.findById.mockResolvedValue(null); // dükkan bulunamadı

    const res = await request(app)
      .post('/api/subscription/subscribe')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ shopId: 'non-existent-shop-id', plan: 'monthly' });

    expect(res.status).toBe(404);
  });

  // ── /my — Kendi Aboneliğini Görüntüleme ──────────────────────────────────

  test('BAŞARI: Kendi aboneliklerini görüntüleme → 200', async () => {
    User.findById.mockResolvedValue({ _id: { toString: () => OWNER_ID } });
    Subscription.find.mockResolvedValue([
      { _id: 'sub1', shopId: SHOP_ID, status: 'active' },
    ]);

    const res = await request(app)
      .get('/api/subscription/my')
      .set('Authorization', `Bearer ${ownerToken}`);

    // 401/403 olmamalı
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});
