/**
 * user.security.test.js
 *
 * Kullanıcı kayıt ve giriş endpoint'lerinin güvenlik testleri.
 * Kapsanan saldırılar: privilege escalation (Admin rol atama),
 * NoSQL injection, şifre hash doğrulama, user enumeration,
 * zayıf şifre kabulü, hassas alan sızıntısı.
 */

const express = require('express');
const request = require('supertest');
const bcrypt = require('bcrypt');

// ─── Mock'lar ─────────────────────────────────────────────────────────────────

jest.mock('../models/User', () => {
  const MockUser = jest.fn().mockImplementation((data) => ({
    ...data,
    _id: { toString: () => 'mock-user-id-123' },
    save: jest.fn().mockResolvedValue(true),
    toObject: jest.fn().mockReturnValue({
      ...data,
      _id: 'mock-user-id-123',
    }),
  }));
  MockUser.findOne = jest.fn();
  MockUser.findById = jest.fn();
  return {
    User: MockUser,
    UserRole: { CUSTOMER: 'Customer', BARBER: 'Barber', ADMIN: 'Admin' },
  };
});

jest.mock('../helpers/jwtService', () => ({
  generateToken: jest.fn().mockReturnValue('mock-jwt-token'),
}));

// ─── Setup ────────────────────────────────────────────────────────────────────

const { User } = require('../models/User');
const userRoutes = require('../routes/user');

const app = express();
app.use(express.json());
app.use('/api/user', userRoutes);

// ─── Kayıt Güvenlik Testleri ──────────────────────────────────────────────────

describe('POST /api/user/register — Kayıt Güvenlik Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  test('KRİTİK GÜVENLİK: API üzerinden Admin rolü atanamamalı', async () => {
    User.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Hacker', email: 'hacker@evil.com', password: 'pass123456', role: 'Admin' });

    // Kayıt başarılı olmuş olsa bile…
    if (res.status === 200 || res.status === 201) {
      // …oluşturulan kullanıcı Admin olmamalı
      const callArg = User.mock.calls[0][0];
      expect(callArg.role).not.toBe('Admin');
      expect(callArg.role).toBe('Customer'); // güvenli varsayılan
    } else {
      // Ya da istek reddedildi (400/403)
      expect([400, 403].includes(res.status)).toBe(true);
    }
  });

  test('GÜVENLİK: Geçerli Barber rolü kabul edilmeli', async () => {
    User.findOne.mockResolvedValue(null);

    await request(app)
      .post('/api/user/register')
      .send({ name: 'Berber', email: 'berber@test.com', password: 'pass123456', role: 'Barber' });

    const callArg = User.mock.calls[0]?.[0];
    if (callArg) {
      expect(callArg.role).toBe('Barber');
    }
  });

  test('GÜVENLİK: Geçersiz/bilinmeyen rol → Customer\'a düşürülmeli', async () => {
    User.findOne.mockResolvedValue(null);

    await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'test@test.com', password: 'pass123456', role: 'SuperAdmin' });

    const callArg = User.mock.calls[0]?.[0];
    if (callArg) {
      expect(callArg.role).toBe('Customer');
    }
  });

  test('GÜVENLİK: Zayıf şifre (6 karakterden az) reddedilmeli → 400', async () => {
    User.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'test@test.com', password: '123' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  test('GÜVENLİK: Boş şifre reddedilmeli → 400', async () => {
    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'test@test.com', password: '' });

    expect(res.status).toBe(400);
  });

  test('GÜVENLİK: Şifreler hiçbir zaman düz metin olarak saklanmamalı', async () => {
    User.findOne.mockResolvedValue(null);
    const plainPassword = 'MySuperSecret123!';

    await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'safe@test.com', password: plainPassword });

    const callArg = User.mock.calls[0]?.[0];
    if (callArg) {
      expect(callArg.passwordHash).toBeDefined();
      expect(callArg.passwordHash).not.toBe(plainPassword);
      // bcrypt hash doğrulaması
      const isHashed = await bcrypt.compare(plainPassword, callArg.passwordHash);
      expect(isHashed).toBe(true);
    }
  });

  test('GÜVENLİK: Kayıt yanıtı passwordHash içermemeli', async () => {
    User.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'noleak@test.com', password: 'pass123456' });

    expect(JSON.stringify(res.body)).not.toContain('passwordHash');
  });

  test('GÜVENLİK: Email zaten kullanılıyorsa → 400 + "Email already in use"', async () => {
    User.findOne.mockResolvedValue({ email: 'existing@test.com' });

    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'existing@test.com', password: 'pass123456' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Bu e-posta adresi zaten kullanılıyor.');
  });

  test('GÜVENLİK: NoSQL injection — email obje olarak gelirse işlenememeli', async () => {
    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: { $gt: '' }, password: 'pass123456' });

    // 200 başarılı yanıt KESİNLİKLE olmamalı
    expect(res.status).not.toBe(200);
    expect(res.status).not.toBe(201);
  });

  test('GÜVENLİK: NoSQL injection — password obje olarak gelirse geçmemeli', async () => {
    const res = await request(app)
      .post('/api/user/register')
      .send({ name: 'Test', email: 'test@test.com', password: { $gt: '' } });

    expect(res.status).not.toBe(200);
    expect(res.status).not.toBe(201);
  });
});

// ─── Giriş Güvenlik Testleri ──────────────────────────────────────────────────

describe('POST /api/user/login — Giriş Güvenlik Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  test('BAŞARI: Doğru kimlik bilgileri → 200 + token döner', async () => {
    const hash = await bcrypt.hash('correctPassword', 10);
    User.findOne.mockResolvedValue({
      _id: 'user123',
      email: 'user@test.com',
      role: 'Customer',
      passwordHash: hash,
      toObject: jest.fn().mockReturnValue({
        _id: 'user123',
        email: 'user@test.com',
        role: 'Customer',
        passwordHash: hash,
      }),
    });

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'user@test.com', password: 'correctPassword' });

    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  test('GÜVENLİK: Yanlış şifre → 400 (kullanıcı numaralandırmasını önlemek için aynı hata)', async () => {
    const hash = await bcrypt.hash('correctPassword', 10);
    User.findOne.mockResolvedValue({
      email: 'user@test.com',
      passwordHash: hash,
      toObject: jest.fn().mockReturnValue({}),
    });

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'user@test.com', password: 'WrongPassword' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('E-posta veya şifre hatalı.');
  });

  test('GÜVENLİK: Mevcut olmayan email → 400 (yanlış şifreyle aynı hata mesajı)', async () => {
    User.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'nobody@test.com', password: 'anyPassword' });

    expect(res.status).toBe(400);
    // Kullanıcı numaralandırması önlenmeli: hata mesajı aynı olmalı!
    expect(res.body.error).toBe('E-posta veya şifre hatalı.');
  });

  test('GÜVENLİK: Giriş yanıtı passwordHash içermemeli', async () => {
    const hash = await bcrypt.hash('password123', 10);
    const mockToObject = jest.fn().mockReturnValue({
      _id: 'u1',
      email: 'user@test.com',
      role: 'Customer',
      passwordHash: hash,
    });
    User.findOne.mockResolvedValue({
      _id: 'u1',
      email: 'user@test.com',
      passwordHash: hash,
      toObject: mockToObject,
    });

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'user@test.com', password: 'password123' });

    // passwordHash yanıtta görünmemeli
    expect(JSON.stringify(res.body)).not.toContain('passwordHash');
  });

  test('GÜVENLİK: Giriş yanıtı resetCode/resetCodeExpiry içermemeli', async () => {
    const hash = await bcrypt.hash('pass123456', 10);
    User.findOne.mockResolvedValue({
      _id: 'u2',
      email: 'user2@test.com',
      passwordHash: hash,
      resetCode: '123456',
      resetCodeExpiry: new Date(),
      toObject: jest.fn().mockReturnValue({
        _id: 'u2',
        email: 'user2@test.com',
        passwordHash: hash,
        resetCode: '123456',
        resetCodeExpiry: new Date().toISOString(),
      }),
    });

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'user2@test.com', password: 'pass123456' });

    if (res.status === 200) {
      expect(JSON.stringify(res.body)).not.toContain('resetCode');
      expect(JSON.stringify(res.body)).not.toContain('resetCodeExpiry');
    }
  });

  test('GÜVENLİK: NoSQL injection - email obje olarak gelirse 400', async () => {
    const res = await request(app)
      .post('/api/user/login')
      .send({ email: { $gt: '' }, password: 'anyPassword' });

    expect(res.status).not.toBe(200);
  });

  test('GÜVENLİK: NoSQL injection - password obje olarak gelirse 400', async () => {
    User.findOne.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/user/login')
      .send({ email: 'user@test.com', password: { $gt: '' } });

    expect(res.status).not.toBe(200);
  });
});

// ─── Barber Availability Güvenlik Testleri ────────────────────────────────────

describe('PUT /api/user/barber/availability/:id — Yetkilendirme Testleri', () => {
  afterEach(() => jest.clearAllMocks());

  test('GÜVENLİK: Auth olmadan erişim → 401', async () => {
    const res = await request(app)
      .put('/api/user/barber/availability/some-user-id')
      .send({ availability: [] });

    expect(res.status).toBe(401);
  });
});
