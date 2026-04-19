/**
 * Tek seferlik migration scripti:
 * Mevcut aboneliklerde `plan` alanını `tier` + `billingPeriod` yapısına dönüştürür.
 *
 * Kullanım: node utils/migrateSubscriptions.js
 */
const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI;

async function migrate() {
  if (!MONGO_URI) {
    console.error('MONGO_URI env değişkeni tanımlı değil.');
    process.exit(1);
  }

  await mongoose.connect(MONGO_URI);
  console.log('MongoDB bağlantısı kuruldu.');

  const db = mongoose.connection.db;
  const collection = db.collection('subscriptions');

  // 1. tier alanı olmayan kayıtlara tier: 'standart' ata
  const tierResult = await collection.updateMany(
    { tier: { $exists: false } },
    { $set: { tier: 'standart' } }
  );
  console.log(`tier eklendi: ${tierResult.modifiedCount} kayıt güncellendi.`);

  // 2. plan alanını billingPeriod'a dönüştür
  const planMappings = [
    { filter: { plan: 'monthly' }, billingPeriod: 'monthly' },
    { filter: { plan: 'yearly' }, billingPeriod: 'yearly' },
    { filter: { plan: 'free_trial' }, billingPeriod: 'free_trial' },
  ];

  for (const { filter, billingPeriod } of planMappings) {
    const result = await collection.updateMany(
      { ...filter, billingPeriod: { $exists: false } },
      { $set: { billingPeriod } }
    );
    console.log(`plan:'${filter.plan}' → billingPeriod:'${billingPeriod}': ${result.modifiedCount} kayıt`);
  }

  // 3. billingPeriod hâlâ atanmamış kayıtlara default ata
  const fallback = await collection.updateMany(
    { billingPeriod: { $exists: false } },
    { $set: { billingPeriod: 'monthly' } }
  );
  if (fallback.modifiedCount > 0) {
    console.log(`Varsayılan billingPeriod atandı: ${fallback.modifiedCount} kayıt`);
  }

  // 4. Eski plan alanını kaldır
  const unsetResult = await collection.updateMany(
    { plan: { $exists: true } },
    { $unset: { plan: '' } }
  );
  console.log(`Eski plan alanı kaldırıldı: ${unsetResult.modifiedCount} kayıt`);

  console.log('\nMigration tamamlandı.');
  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error('Migration hatası:', err);
  process.exit(1);
});
