import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

/// Abonelik state yönetimi — UI ile SubscriptionService arasında köprü.
///
/// **Anti-Tampering Güvenlik Katmanı:**
/// - Abonelik durumu hiçbir zaman basit bir `bool isPremium` olarak tutulmaz.
/// - Durum her zaman sunucudan çekilen [SubscriptionInfo] nesnesi ile temsil edilir.
/// - Memory editor (Lucky Patcher vb.) koruması: getter üzerinden hesaplanmış değer döner,
///   doğrudan field olarak tutulmaz.
/// - Uygulama her ön plana geldiğinde `refreshSubscription()` çağrılarak
///   sunucudan yeniden doğrulanmalıdır.
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService.instance;

  // ─── State Fields ────────────────────────────────────────────

  /// Sunucudan doğrulanmış abonelik bilgisi.
  SubscriptionInfo? _subscriptionInfo;
  SubscriptionInfo? get subscriptionInfo => _subscriptionInfo;

  /// Google Play'den çekilen ürünler.
  List<SubscriptionProduct> _products = [];
  List<SubscriptionProduct> get products => List.unmodifiable(_products);

  /// Satın alma akışı durumu.
  PurchaseState _purchaseState = const PurchaseIdle();
  PurchaseState get purchaseState => _purchaseState;

  /// Genel yükleme durumu (abonelik verisi çekilirken).
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Hata mesajı.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Seçili paket (tier).
  SubscriptionTier _selectedTier = SubscriptionTier.standart;
  SubscriptionTier get selectedTier => _selectedTier;

  /// Seçili ürünün mevcut teklifleri (base plan'lar).
  List<SubscriptionOffer> get availableOffers {
    final product = _products.where((p) => p.tier == _selectedTier).firstOrNull;
    return product?.offers ?? [];
  }

  /// Seçili teklif (base plan).
  SubscriptionOffer? _selectedOffer;
  SubscriptionOffer? get selectedOffer => _selectedOffer;

  /// Referans kodu bilgileri.
  String? _referralValidation;
  String? get referralValidation => _referralValidation;

  String? _referralShopName;
  String? get referralShopName => _referralShopName;

  int? _referralBonusDays;
  int? get referralBonusDays => _referralBonusDays;

  bool _referralIsPromo = false;
  bool get referralIsPromo => _referralIsPromo;

  // ─── Computed Getters (Anti-Tampering) ──────────────────────

  /// Abonelik aktif mi? Her çağrıda sunucu verisinden hesaplanır.
  /// Memory-editor'ler basit `bool` değişkeni yakalayabilir,
  /// ama computed getter + sealed class yapısını değiştiremez.
  bool get isSubscriptionActive {
    final info = _subscriptionInfo;
    if (info == null) return false;
    // Hem status kontrolü hem tarih kontrolü — çift doğrulama
    if (!info.isActive) return false;
    if (info.endDate != null && info.endDate!.isBefore(DateTime.now())) return false;
    return true;
  }

  int get remainingDays => _subscriptionInfo?.remainingDays ?? 0;

  // ─── Lifecycle ──────────────────────────────────────────────

  /// Provider başlatma — uygulama açılışında çağrılır.
  Future<void> init(String? jwtToken) async {
    _isLoading = true;
    notifyListeners();

    // IAP bağlantısını başlat
    final available = await _service.initialize();
    if (!available) {
      _errorMessage = BillingError.storeUnavailable.userMessage;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Purchase stream'i dinle
    _service.onPurchaseUpdated = _handlePurchaseUpdates;

    // Ürünleri çek
    await _loadProducts();

    // Sunucudan abonelik durumunu çek
    if (jwtToken != null) {
      await refreshSubscription(jwtToken);
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.onPurchaseUpdated = null;
    super.dispose();
  }

  // ─── Ürün Yükleme ──────────────────────────────────────────

  Future<void> _loadProducts() async {
    final (products, error) = await _service.fetchProducts();
    _products = products;
    if (error != null && products.isEmpty) {
      _errorMessage = error.userMessage;
    }    // Varsayılan teklif seç: aylık (ilk teklif)
    final offers = availableOffers;
    if (offers.isNotEmpty && _selectedOffer == null) {
      _selectedOffer = offers.first;
    }  }

  // ─── Abonelik Yenileme (Sunucu Doğrulaması) ────────────────

  /// Sunucudan abonelik bilgisini çeker ve state'i günceller.
  /// Anti-tampering: Bu metot her görünüm değişikliğinde çağrılmalı.
  Future<void> refreshSubscription(String jwtToken) async {
    final info = await _service.fetchSubscription(jwtToken);
    _subscriptionInfo = info;
    _errorMessage = null;
    notifyListeners();
  }

  // ─ Paket & Teklif Seçimi ──────────────────────────────────────

  void selectTier(SubscriptionTier tier) {
    _selectedTier = tier;
    // Tier değişince ilk teklifi seç
    final offers = availableOffers;
    _selectedOffer = offers.isNotEmpty ? offers.first : null;
    notifyListeners();
  }

  void selectOffer(SubscriptionOffer offer) {
    _selectedOffer = offer;
    notifyListeners();
  }

  // ─── Referans Kodu Kontrolü ─────────────────────────────────

  Future<void> checkReferralCode(String code) async {
    if (code.trim().isEmpty) {
      _referralValidation = null;
      _referralShopName = null;
      _referralBonusDays = null;
      _referralIsPromo = false;
      notifyListeners();
      return;
    }

    final result = await _service.checkReferralCode(code.trim());
    _referralValidation = result.valid ? 'valid' : 'invalid';
    _referralShopName = result.shopName;
    _referralBonusDays = result.bonusDays;
    _referralIsPromo = result.isPromo;
    notifyListeners();
  }

  void clearReferralCode() {
    _referralValidation = null;
    _referralShopName = null;
    _referralBonusDays = null;
    _referralIsPromo = false;
    notifyListeners();
  }

  // ─── Satın Alma Akışı ─────────────────────────────────────

  /// Google Play satın alma akışını başlatır.
  Future<void> purchaseSubscription({
    required String shopId,
    required String jwtToken,
    String? referralCode,
  }) async {
    final offer = _selectedOffer;
    if (offer == null) return;

    final product = _products.where((p) => p.tier == _selectedTier).firstOrNull;
    if (product == null) return;

    _purchaseState = const PurchaseLoading('Satın alma başlatılıyor...');
    _shopIdForVerification = shopId;
    _jwtTokenForVerification = jwtToken;
    _referralCodeForVerification = referralCode;
    notifyListeners();

    final error = await _service.buySubscription(
      product.productId,
      offerToken: offer.offerToken,
    );
    if (error != null) {
      _purchaseState = PurchaseError(error.userMessage, error.name);
      notifyListeners();
    }
    // Başarı durumunda sonuç _handlePurchaseUpdates üzerinden gelecek.
  }

  // Pending purchase tamamlama için geçici state
  String? _shopIdForVerification;
  String? _jwtTokenForVerification;
  String? _referralCodeForVerification;

  /// Purchase stream callback — her satın alma güncellemesinde çağrılır.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _processPurchase(purchase);
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _purchaseState = const PurchaseLoading('Ödeme onayı bekleniyor...');
        notifyListeners();

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _purchaseState = const PurchaseLoading('Satın alma doğrulanıyor...');
        notifyListeners();

        // Sunucu doğrulaması — en kritik güvenlik adımı.
        await _verifyAndComplete(purchase);

      case PurchaseStatus.error:
        final errorMessage = _parsePurchaseError(purchase.error);
        _purchaseState = PurchaseError(errorMessage);
        notifyListeners();
        // Hata durumunda da completePurchase çağrılmalı
        await _service.completePurchase(purchase);

      case PurchaseStatus.canceled:
        _purchaseState = PurchaseError(BillingError.userCancelled.userMessage, 'cancelled');
        notifyListeners();
        await _service.completePurchase(purchase);
    }
  }

  /// Satın almayı sunucuda doğrular ve Google Play'e onay gönderir.
  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final token = _jwtTokenForVerification;
    final shopId = _shopIdForVerification;

    if (token == null || shopId == null) {
      _purchaseState = const PurchaseError('Doğrulama bilgileri eksik. Lütfen tekrar deneyin.');
      notifyListeners();
      await _service.completePurchase(purchase);
      return;
    }

    // serverVerificationData: Google Play'den dönen token
    final purchaseToken = purchase.verificationData.serverVerificationData;
    final productId = purchase.productID;

    final result = await _service.verifyPurchaseOnServer(
      purchaseToken: purchaseToken,
      productId: productId,
      shopId: shopId,
      jwtToken: token,
      referralCode: _referralCodeForVerification,
    );

    if (result.success) {
      _purchaseState = PurchaseSuccess(result.message);
      // Abonelik bilgisini yenile
      await refreshSubscription(token);
    } else {
      _purchaseState = PurchaseError(result.message);
    }

    notifyListeners();

    // Google Play'e satın alma tamamlandı bildirimi — ZORUNLU.
    // Bu çağrılmazsa Google Play 3 gün sonra otomatik iade yapar.
    await _service.completePurchase(purchase);
  }

  // ─── Restore Purchases ──────────────────────────────────────

  /// Mevcut satın alımları geri yükler (cihaz değişikliği, yeniden yükleme).
  Future<void> restorePurchases({
    required String shopId,
    required String jwtToken,
  }) async {
    _purchaseState = const PurchaseLoading('Satın alımlar geri yükleniyor...');
    _shopIdForVerification = shopId;
    _jwtTokenForVerification = jwtToken;
    notifyListeners();

    try {
      await _service.restorePurchases();
      // Sonuçlar purchase stream üzerinden gelecek.
      // Eğer hiç satın alma yoksa stream update gelmez,
      // timeout ile idle'a döndür.
      Future.delayed(const Duration(seconds: 10), () {
        if (_purchaseState is PurchaseLoading) {
          _purchaseState = const PurchaseError('Geri yüklenecek satın alma bulunamadı.');
          notifyListeners();
        }
      });
    } catch (e) {
      _purchaseState = PurchaseError('Geri yükleme hatası: $e');
      notifyListeners();
    }
  }

  // ─── Referans ile Otomatik Abonelik ─────────────────────────

  /// Dükkan oluştururken referans koduyla otomatik abonelik.
  Future<({bool success, String message})> subscribeWithReferral({
    required String shopId,
    required String referralCode,
    required String jwtToken,
  }) async {
    return _service.subscribeWithReferral(
      shopId: shopId,
      referralCode: referralCode,
      jwtToken: jwtToken,
    );
  }

  // ─── State Reset ───────────────────────────────────────────

  void resetPurchaseState() {
    _purchaseState = const PurchaseIdle();
    notifyListeners();
  }

  // ─── Private Helpers ────────────────────────────────────────

  String _parsePurchaseError(IAPError? error) {
    if (error == null) return BillingError.unknown.userMessage;

    // Google Play Billing hata kodlarını parse et
    final code = error.code;
    return switch (code) {
      'BillingResponse.userCanceled' => BillingError.userCancelled.userMessage,
      'BillingResponse.serviceUnavailable' => BillingError.storeUnavailable.userMessage,
      'BillingResponse.itemAlreadyOwned' => 'Bu abonelik zaten aktif.',
      'BillingResponse.itemUnavailable' => BillingError.productNotFound.userMessage,
      'BillingResponse.developerError' => 'Yapılandırma hatası. Lütfen destek ile iletişime geçin.',
      'BillingResponse.serviceDisconnected' => 'Google Play bağlantısı kesildi. Tekrar deneyin.',
      'BillingResponse.serviceTimeout' => 'Google Play zaman aşımı. Tekrar deneyin.',
      _ => error.message.isNotEmpty ? error.message : BillingError.unknown.userMessage,
    };
  }
}
