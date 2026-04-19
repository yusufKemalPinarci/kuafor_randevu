// Bu dosya, abonelik ve dükkan model birim testlerini içerir.
// Eski iyzico kart formatter testleri kaldırıldı — Google Play Billing ile değiştirildi.

import 'package:flutter_test/flutter_test.dart';
import 'package:kuaflex/models/subscription_model.dart';
import 'package:kuaflex/models/shop_model.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. SUBSCRIPTION MODEL TESTLERİ
  // ─────────────────────────────────────────────────────────────────────────

  group('SubscriptionInfo.fromJson — Parse Testleri', () {
    test('Aktif abonelik doğru parse edilir', () {
      final json = {
        '_id': '123',
        'status': 'active',
        'tier': 'standart',
        'billingPeriod': 'monthly',
        'endDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'referralCode': 'ABC123',
        'referralCount': 5,
      };
      final info = SubscriptionInfo.fromJson(json);
      expect(info.status, SubscriptionStatus.active);
      expect(info.isActive, isTrue);
      expect(info.tierLabel, 'Standart');
      expect(info.billingPeriodLabel, 'Aylık');
      expect(info.referralCode, 'ABC123');
      expect(info.remainingDays, greaterThanOrEqualTo(29));
    });

    test('Süresi dolmuş abonelik doğru parse edilir', () {
      final json = {
        'status': 'expired',
        'tier': 'standart',
        'billingPeriod': 'yearly',
        'endDate': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      };
      final info = SubscriptionInfo.fromJson(json);
      expect(info.status, SubscriptionStatus.expired);
      expect(info.isActive, isFalse);
      expect(info.billingPeriodLabel, 'Yıllık');
      expect(info.remainingDays, 0);
    });

    test('Ücretsiz deneme doğru parse edilir', () {
      final json = {
        'status': 'free_trial',
        'tier': 'standart',
        'billingPeriod': 'free_trial',
        'endDate': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
      };
      final info = SubscriptionInfo.fromJson(json);
      expect(info.status, SubscriptionStatus.freeTrial);
      expect(info.isActive, isTrue);
      expect(info.billingPeriodLabel, 'Ücretsiz Deneme');
    });

    test('Bilinmeyen status none olarak işlenir', () {
      final json = {'status': 'unknown_status', 'tier': 'standart'};
      final info = SubscriptionInfo.fromJson(json);
      expect(info.status, SubscriptionStatus.none);
      expect(info.isActive, isFalse);
    });

    test('Boş JSON güvenli şekilde parse edilir', () {
      final info = SubscriptionInfo.fromJson({});
      expect(info.status, SubscriptionStatus.none);
      expect(info.isActive, isFalse);
      expect(info.endDate, isNull);
      expect(info.referralCode, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. SUBSCRIPTION PRODUCT TESTLERİ
  // ─────────────────────────────────────────────────────────────────────────

  group('SubscriptionProduct — Model Testleri', () {
    test('Standart ürün tier ve offers doğru döner', () {
      const product = SubscriptionProduct(
        productId: 'kuaflex_standart',
        title: 'Standart',
        description: 'Standart abonelik',
        tier: SubscriptionTier.standart,
        offers: [
          SubscriptionOffer(
            basePlanId: 'standart-aylik',
            offerToken: 'token1',
            billingPeriod: BillingPeriod.monthly,
            price: '₺99,00',
            currencyCode: 'TRY',
            rawPrice: 99.0,
          ),
          SubscriptionOffer(
            basePlanId: 'standart-yillik',
            offerToken: 'token2',
            billingPeriod: BillingPeriod.yearly,
            price: '₺799,00',
            currencyCode: 'TRY',
            rawPrice: 799.0,
          ),
        ],
      );
      expect(product.tier, SubscriptionTier.standart);
      expect(product.offers.length, 2);
      expect(product.offers.first.billingPeriod, BillingPeriod.monthly);
      expect(product.offers.last.billingPeriod, BillingPeriod.yearly);
    });

    test('SubscriptionOffer monthlyEquivalent doğru hesaplanır', () {
      const monthly = SubscriptionOffer(
        basePlanId: 'standart-aylik',
        offerToken: 'token1',
        billingPeriod: BillingPeriod.monthly,
        price: '₺99,00',
        currencyCode: 'TRY',
        rawPrice: 99.0,
      );
      expect(monthly.monthlyEquivalent, 99.0);

      const yearly = SubscriptionOffer(
        basePlanId: 'standart-yillik',
        offerToken: 'token2',
        billingPeriod: BillingPeriod.yearly,
        price: '₺799,00',
        currencyCode: 'TRY',
        rawPrice: 799.0,
      );
      expect(yearly.monthlyEquivalent, closeTo(66.58, 0.01));

      const sixMonth = SubscriptionOffer(
        basePlanId: 'standart-6aylik',
        offerToken: 'token3',
        billingPeriod: BillingPeriod.sixMonth,
        price: '₺499,00',
        currencyCode: 'TRY',
        rawPrice: 499.0,
      );
      expect(sixMonth.monthlyEquivalent, closeTo(83.17, 0.01));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. PURCHASE STATE TESTLERİ (sealed class pattern matching)
  // ─────────────────────────────────────────────────────────────────────────

  group('PurchaseState — Sealed Class Testleri', () {
    test('PurchaseIdle default state', () {
      const state = PurchaseIdle();
      expect(state, isA<PurchaseState>());
    });

    test('PurchaseLoading mesaj taşır', () {
      const state = PurchaseLoading('Yükleniyor');
      expect(state.message, 'Yükleniyor');
    });

    test('PurchaseSuccess mesaj taşır', () {
      const state = PurchaseSuccess('Başarılı');
      expect(state.message, 'Başarılı');
    });

    test('PurchaseError mesaj ve kod taşır', () {
      const state = PurchaseError('Hata oluştu', 'E001');
      expect(state.message, 'Hata oluştu');
      expect(state.code, 'E001');
    });

    test('Pattern matching doğru çalışır', () {
      const PurchaseState state = PurchaseError('Test hata');
      final message = switch (state) {
        PurchaseIdle() => 'idle',
        PurchaseLoading(:final message) => message,
        PurchaseSuccess(:final message) => message,
        PurchaseError(:final message) => message,
      };
      expect(message, 'Test hata');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. SHOP MODEL TESTLERİ
  // ─────────────────────────────────────────────────────────────────────────

  group('ShopModel.fromJson — Parse Testleri', () {
    final validJson = {
      '_id': 'shop1',
      'name': 'Test Berberi',
      'fullAddress': 'Atatürk Cad. No:1',
      'neighborhood': 'Merkez',
      'city': 'İstanbul',
      'district': 'Kadıköy',
      'phone': '05321234567',
      'openingHour': '09:00',
      'closingHour': '20:00',
      'workingDays': ['Pazartesi', 'Salı', 'Çarşamba'],
      'ownerId': 'owner1',
      'shopCode': 'ABC123',
    };

    test('geçerli JSON doğru parse edilir', () {
      final shop = ShopModel.fromJson(validJson);
      expect(shop.id, 'shop1');
      expect(shop.name, 'Test Berberi');
      expect(shop.openingHour, '09:00');
      expect(shop.closingHour, '20:00');
      expect(shop.workingDays.length, 3);
      expect(shop.shopCode, 'ABC123');
      expect(shop.district, 'Kadıköy');
    });

    test('_id yoksa id alanına düşer', () {
      final json = Map<String, dynamic>.from(validJson);
      json.remove('_id');
      json['id'] = 'fallback_id';
      final shop = ShopModel.fromJson(json);
      expect(shop.id, 'fallback_id');
    });

    test('workingDays eksikse boş liste döner', () {
      final json = Map<String, dynamic>.from(validJson)..remove('workingDays');
      final shop = ShopModel.fromJson(json);
      expect(shop.workingDays, isEmpty);
    });

    test('opsiyonel alanlar null gelebilir', () {
      final minimal = {
        '_id': 'x',
        'name': 'A',
        'fullAddress': 'B',
        'neighborhood': 'C',
        'city': 'D',
        'openingHour': '08:00',
        'closingHour': '18:00',
        'workingDays': <String>[],
        'ownerId': 'o1',
      };
      final shop = ShopModel.fromJson(minimal);
      expect(shop.phone, isNull);
      expect(shop.district, isNull);
      expect(shop.shopCode, isNotNull); // boş string döner
    });

    test('toJson gidiş-dönüş tutarlı', () {
      final shop = ShopModel.fromJson(validJson);
      final json2 = shop.toJson();
      expect(json2['name'], shop.name);
      expect(json2['openingHour'], shop.openingHour);
      expect(json2['closingHour'], shop.closingHour);
    });

    test('workingDays 7 güne kadar çıkabilir', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['workingDays'] = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      final shop = ShopModel.fromJson(json);
      expect(shop.workingDays.length, 7);
    });
  });
}

