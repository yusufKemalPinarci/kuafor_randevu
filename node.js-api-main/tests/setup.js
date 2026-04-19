// Test ortamı için gerekli environment değişkenlerini tanımla.
// Gerçek .env dosyasına ihtiyaç duymadan testler çalışabilsin.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-256bit-kuaflex-jest-secret-abcdef0123456789';
process.env.JWT_ISSUER = 'kuaflex';
process.env.JWT_AUDIENCE = 'kuaflex_users';
process.env.JWT_EXPIRE_DAYS = '7';
process.env.MONGODB_URI = 'mongodb://localhost:27017/kuaflex-test';
process.env.EMAIL_USER = 'test@test.com';
process.env.EMAIL_PASS = 'testpass';
// Firebase Admin SDK mock (testlerde gerçek bağlantı kurmaz)
process.env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify({
  type: 'service_account',
  project_id: 'test-project',
  private_key_id: 'test-key-id',
  private_key: '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4PAtEsHAFBBK/TdHpBL0bFfCfS/\nGHB7s6rHfB3v0lHOHJ0lVhPxb3P2B5VxFmxdFYGW1IKqFNpmlqfUnlnVHnJ1v9RH\ntest-key-only\n-----END RSA PRIVATE KEY-----\n',
  client_email: 'test@test-project.iam.gserviceaccount.com',
  client_id: '123456789',
  token_uri: 'https://oauth2.googleapis.com/token',
});
