import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/constants.dart';
import '../models/subscription_model.dart';
import 'api_client.dart';

/// Google Play ürün ID'leri — Google Play Console'da tanımladığınız ürün kodları.
abstract final class SubscriptionProductIds {
  static const String standart = 'kuaflex_standart';
  // İleride eklenecek:
  // static const String pro = 'kuaflex_pro';
  // static const String premium = 'kuaflex_premium';

  /// Şu anda aktif olan ürünler (Google Play'de yayında olanlar).
  static const Set<String> active = {standart};
}

/// Abonelik servisinin hata kodları.
enum BillingError {
  storeUnavailable,
  productNotFound,
  purchaseFailed,
  userCancelled,
  purchasePending,
  verificationFailed,
  networkError,
  unknown,
}

/// Billing hata kodları → kullanıcı dostu mesajlar.
extension BillingErrorMessage on BillingError {
  String get userMessage => switch (this) {
    BillingError.storeUnavailable  => 'Google Play Store erişilemiyor. İnternet bağlantınızı kontrol edin.',
    BillingError.productNotFound   => 'Abonelik paketleri bulunamadı. Lütfen daha sonra tekrar deneyin.',
    BillingError.purchaseFailed    => 'Satın alma işlemi başarısız oldu.',
    BillingError.userCancelled     => 'Satın alma işlemi iptal edildi.',
    BillingError.purchasePending   => 'Satın alma işleminiz beklemede. Onaylandığında aktif olacak.',
    BillingError.verificationFailed => 'Satın alma doğrulanamadı. Lütfen destek ile iletişime geçin.',
    BillingError.networkError      => 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.',
    BillingError.unknown           => 'Beklenmeyen bir hata oluştu.',
  };
}

/// In-App Purchase satın alma akışını, ürün listelemeyi ve bağlantı yönetimini
/// yapan servis katmanı.
///
/// **Güvenlik Tasarımı:**
/// - Satın alma onayı sonrası receipt (serverVerificationData) sunucuya gönderilir.
/// - Sunucu Google Play Developer API ile doğrulama yapar.
/// - Abonelik durumu istemcide basit bool olarak tutulmaz; her zaman sunucudan sorgulanır.
/// - Pending purchase mekanizması ile yarım kalan işlemler tamamlanır.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiClient _client = ApiClient();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  /// Satın alma stream callback — provider tarafından set edilir.
  void Function(List<PurchaseDetails>)? onPurchaseUpdated;

  bool _isInitialized = false;

  // ────────────────────────────────────────────────────────────
  // Bağlantı Yönetimi
  // ────────────────────────────────────────────────────────────

  /// IAP bağlantısını başlatır ve purchase stream'i dinlemeye başlar.
  /// Uygulama açılışında bir kere çağrılmalı.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final available = await _iap.isAvailable();
    if (!available) return false;

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: _onPurchaseStreamDone,
      onError: _onPurchaseStreamError,
    );

    _isInitialized = true;
    return true;
  }

  /// Kaynak temizliği — uygulama kapanırken çağrılır.
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _isInitialized = false;
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    onPurchaseUpdated?.call(purchases);
  }

  void _onPurchaseStreamDone() {
    if (kDebugMode) debugPrint('[SubscriptionService] Purchase stream closed.');
  }

  void _onPurchaseStreamError(Object error) {
    if (kDebugMode) debugPrint('[SubscriptionService] Purchase stream error: $error');
  }

  // ────────────────────────────────────────────────────────────
  // Ürün Listeleme
  // ────────────────────────────────────────────────────────────

  /// Google Play'den abonelik ürünlerini ve base plan tekliflerini çeker.
  Future<(List<SubscriptionProduct>, BillingError?)> fetchProducts() async {
    try {
      final response = await _iap.queryProductDetails(SubscriptionProductIds.active);

      if (response.notFoundIDs.isNotEmpty) {
        if (kDebugMode) debugPrint('[SubscriptionService] Products not found: ${response.notFoundIDs}');
      }

      if (response.productDetails.isEmpty) {
        return (const <SubscriptionProduct>[], BillingError.productNotFound);
      }

      final products = response.productDetails.map((detail) {
        // Her ürünün subscription offer details'ından base plan'ları çıkar
        final offers = <SubscriptionOffer>[];
        final googleDetail = detail is GooglePlayProductDetails ? detail : null;
        final subscriptionOffers = googleDetail?.productDetails.subscriptionOfferDetails;
        if (subscriptionOffers != null) {
          for (final offer in subscriptionOffers) {
            final pricingPhases = offer.pricingPhases;
            if (pricingPhases.isEmpty) continue;
            // Son pricing phase gerçek fiyatı verir (ilk phase trial olabilir)
            final phase = pricingPhases.last;
            final billingPeriod = _billingPeriodFromPhase(phase.billingPeriod);

            offers.add(SubscriptionOffer(
              basePlanId: offer.basePlanId,
              offerToken: offer.offerIdToken,
              billingPeriod: billingPeriod,
              price: phase.formattedPrice,
              currencyCode: phase.priceCurrencyCode,
              rawPrice: phase.priceAmountMicros / 1000000.0,
            ));
          }
        }

        // Teklifleri fiyata göre sırala (ucuzdan pahalıya)
        offers.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

        return SubscriptionProduct(
          productId: detail.id,
          title: detail.title,
          description: detail.description,
          tier: _tierFromProductId(detail.id),
          offers: offers,
        );
      }).toList();

      return (products, null);
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] fetchProducts error: $e');
      return (const <SubscriptionProduct>[], BillingError.unknown);
    }
  }

  SubscriptionTier _tierFromProductId(String productId) {
    if (productId.contains('premium')) return SubscriptionTier.premium;
    if (productId.contains('pro')) return SubscriptionTier.pro;
    return SubscriptionTier.standart;
  }

  BillingPeriod _billingPeriodFromPhase(String billingPeriod) {
    // ISO 8601 period: P1Y, P6M, P1M, P1W, etc.
    if (billingPeriod.contains('Y')) return BillingPeriod.yearly;
    if (billingPeriod.contains('6M')) return BillingPeriod.sixMonth;
    return BillingPeriod.monthly;
  }

  // ────────────────────────────────────────────────────────────
  // Satın Alma Akışı
  // ────────────────────────────────────────────────────────────

  /// Belirtilen ürün ve teklif için satın alma akışını başlatır.
  Future<BillingError?> buySubscription(String productId, {String? offerToken}) async {
    try {
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return BillingError.productNotFound;

      final productDetails = response.productDetails.first;

      final PurchaseParam purchaseParam;
      if (offerToken != null && Platform.isAndroid) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          offerToken: offerToken,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: productDetails);
      }

      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) return BillingError.purchaseFailed;
      return null; // Başarı — sonuç purchase stream'den gelecek.
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] buySubscription error: $e');
      return BillingError.purchaseFailed;
    }
  }

  // ────────────────────────────────────────────────────────────
  // Pending & Complete Purchase
  // ────────────────────────────────────────────────────────────

  /// Satın almayı tamamlar (Google Play'e onay gönderir).
  /// Bu çağrılmazsa Google Play 3 gün sonra satın almayı otomatik iptal eder.
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Restore Purchases
  // ────────────────────────────────────────────────────────────

  /// Mevcut satın alımları geri yükler (örn. cihaz değişikliği).
  /// Sonuçlar purchase stream üzerinden gelir.
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // ────────────────────────────────────────────────────────────
  // Sunucu Doğrulama (Server-Side Verification)
  // ────────────────────────────────────────────────────────────

  /// Satın alma receipt'ini sunucuya gönderir.
  /// Sunucu Google Play Developer API ile doğrulama yapmalıdır.
  ///
  /// **Güvenlik:** serverVerificationData ham olarak gönderilir,
  /// sunucu tarafında Google Play Developer API'ye sorularak doğrulanır.
  Future<({bool success, String message})> verifyPurchaseOnServer({
    required String purchaseToken,
    required String productId,
    required String shopId,
    required String jwtToken,
    String? referralCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'shopId': shopId,
        'purchaseToken': purchaseToken,
        'productId': productId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };
      if (referralCode != null && referralCode.isNotEmpty) {
        body['referralCode'] = referralCode;
      }

      final response = await _client.post(
        '/api/subscription/verify-purchase',
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          success: true,
          message: data['message'] as String? ?? 'Abonelik başarıyla aktifleştirildi!',
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          success: false,
          message: data['error'] as String? ?? 'Satın alma doğrulanamadı. Lütfen tekrar deneyin.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] verifyPurchaseOnServer error: $e');
      return (success: false, message: 'İnternet bağlantınızı kontrol edip tekrar deneyin.');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Sunucu Abonelik Durumu Sorgulama
  // ────────────────────────────────────────────────────────────

  /// Sunucudan mevcut abonelik bilgisini çeker.
  /// Anti-tampering: Abonelik durumu her zaman sunucudan doğrulanır,
  /// istemcide cache'lenmez.
  Future<SubscriptionInfo?> fetchSubscription(String jwtToken) async {
    try {
      final response = await _client.get('/api/subscription/my');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SubscriptionInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] fetchSubscription error: $e');
      return null;
    }
  }

  /// Referans/promosyon kodu doğrulama.
  Future<({bool valid, String? shopName, int? bonusDays, bool isPromo})> checkReferralCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/subscription/check-referral'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'referralCode': code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          valid: data['valid'] == true,
          shopName: data['shopName'] as String?,
          bonusDays: data['bonusDays'] as int?,
          isPromo: data['isPromo'] == true,
        );
      }
      return (valid: false, shopName: null, bonusDays: null, isPromo: false);
    } catch (e) {
      return (valid: false, shopName: null, bonusDays: null, isPromo: false);
    }
  }

  /// Abonelik aktif mi kontrol — BarberHomePage gibi yerler için.
  Future<({bool isActive, String? endDate})> checkSubscriptionStatus(String shopId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/subscription/status/$shopId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          isActive: data['isActive'] == true,
          endDate: data['endDate'] as String?,
        );
      }
      return (isActive: false, endDate: null);
    } catch (_) {
      return (isActive: false, endDate: null);
    }
  }

  /// Referans koduyla dükkan oluştururken otomatik abonelik.
  Future<({bool success, String message})> subscribeWithReferral({
    required String shopId,
    required String referralCode,
    required String jwtToken,
  }) async {
    try {
      final response = await _client.post(
        '/api/subscription/subscribe',
        body: {
          'shopId': shopId,
          'referralCode': referralCode,
        },
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          success: true,
          message: data['message'] as String? ?? 'Abonelik başarıyla oluşturuldu!',
        );
      }
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        success: false,
        message: err['error'] as String? ?? 'Abonelik oluşturulamadı. Lütfen tekrar deneyin.',
      );
    } catch (_) {
      return (
        success: false,
        message: 'Referans aboneliği aktifleştirilemedi. Abonelik sayfasından tekrar deneyebilirsiniz.',
      );
    }
  }
}
