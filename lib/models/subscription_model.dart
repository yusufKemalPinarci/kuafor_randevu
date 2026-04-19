/// Abonelik durumu — sunucudan doğrulanmış son durum.
enum SubscriptionStatus {
  none,       // Hiç abonelik yok
  active,     // Aktif abonelik
  expired,    // Süresi dolmuş
  cancelled,  // İptal edilmiş
  freeTrial,  // Ücretsiz deneme
  pending,    // Satın alma beklemede
}

/// Abonelik paketi (tier).
enum SubscriptionTier {
  standart,
  pro,
  premium;

  String get label => switch (this) {
    SubscriptionTier.standart => 'Standart',
    SubscriptionTier.pro      => 'Profesyonel',
    SubscriptionTier.premium  => 'Premium',
  };

  static SubscriptionTier fromString(String? value) => switch (value) {
    'standart' => SubscriptionTier.standart,
    'pro'      => SubscriptionTier.pro,
    'premium'  => SubscriptionTier.premium,
    _          => SubscriptionTier.standart,
  };
}

/// Fatura dönemi.
enum BillingPeriod {
  monthly,
  sixMonth,
  yearly,
  freeTrial;

  String get label => switch (this) {
    BillingPeriod.monthly   => 'Aylık',
    BillingPeriod.sixMonth  => '6 Aylık',
    BillingPeriod.yearly    => 'Yıllık',
    BillingPeriod.freeTrial => 'Ücretsiz Deneme',
  };

  String get suffix => switch (this) {
    BillingPeriod.monthly   => '/ay',
    BillingPeriod.sixMonth  => '/6 ay',
    BillingPeriod.yearly    => '/yıl',
    BillingPeriod.freeTrial => '',
  };

  static BillingPeriod fromString(String? value) => switch (value) {
    'monthly'    => BillingPeriod.monthly,
    '6month'     => BillingPeriod.sixMonth,
    'yearly'     => BillingPeriod.yearly,
    'free_trial' => BillingPeriod.freeTrial,
    _            => BillingPeriod.monthly,
  };
}

/// Google Play'den çekilen bir base plan teklifi.
final class SubscriptionOffer {
  final String basePlanId;
  final String offerToken;
  final BillingPeriod billingPeriod;
  final String price;        // Formatlanmış fiyat: "₺99,00"
  final String currencyCode;
  final double rawPrice;

  const SubscriptionOffer({
    required this.basePlanId,
    required this.offerToken,
    required this.billingPeriod,
    required this.price,
    required this.currencyCode,
    required this.rawPrice,
  });

  double get monthlyEquivalent => switch (billingPeriod) {
    BillingPeriod.monthly   => rawPrice,
    BillingPeriod.sixMonth  => rawPrice / 6,
    BillingPeriod.yearly    => rawPrice / 12,
    BillingPeriod.freeTrial => 0,
  };

  int get savingsPercent {
    // aylık fiyat bazlı karşılaştırma yapılamaz burada, UI'da hesaplanmalı
    return 0;
  }
}

/// Google Play'den çekilen abonelik ürünü (subscription).
final class SubscriptionProduct {
  final String productId;
  final String title;
  final String description;
  final SubscriptionTier tier;
  final List<SubscriptionOffer> offers;

  const SubscriptionProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.tier,
    this.offers = const [],
  });
}

/// Sunucu tarafından doğrulanmış abonelik bilgisi.
final class SubscriptionInfo {
  final String? id;
  final SubscriptionStatus status;
  final SubscriptionTier tier;
  final BillingPeriod billingPeriod;
  final DateTime? endDate;
  final String? referralCode;
  final int? referralCount;
  final int remainingDays;

  const SubscriptionInfo({
    this.id,
    this.status = SubscriptionStatus.none,
    this.tier = SubscriptionTier.standart,
    this.billingPeriod = BillingPeriod.monthly,
    this.endDate,
    this.referralCode,
    this.referralCount,
    this.remainingDays = 0,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? '';
    final status = switch (statusStr) {
      'active'     => SubscriptionStatus.active,
      'expired'    => SubscriptionStatus.expired,
      'cancelled'  => SubscriptionStatus.cancelled,
      'free_trial' => SubscriptionStatus.freeTrial,
      'pending'    => SubscriptionStatus.pending,
      _            => SubscriptionStatus.none,
    };

    DateTime? endDate;
    if (json['endDate'] != null) {
      try { endDate = DateTime.parse(json['endDate'] as String); } catch (_) {}
    }

    final remaining = endDate != null
        ? endDate.difference(DateTime.now()).inDays.clamp(0, 99999)
        : 0;

    return SubscriptionInfo(
      id: json['_id'] as String?,
      status: status,
      tier: SubscriptionTier.fromString(json['tier'] as String?),
      billingPeriod: BillingPeriod.fromString(json['billingPeriod'] as String?),
      endDate: endDate,
      referralCode: json['referralCode'] as String?,
      referralCount: json['referralCount'] as int?,
      remainingDays: remaining,
    );
  }

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.freeTrial;

  String get tierLabel => tier.label;

  String get billingPeriodLabel => billingPeriod.label;
}

/// Satın alma akışı sırasındaki durum.
sealed class PurchaseState {
  const PurchaseState();
}

final class PurchaseIdle extends PurchaseState {
  const PurchaseIdle();
}

final class PurchaseLoading extends PurchaseState {
  final String message;
  const PurchaseLoading([this.message = 'İşleniyor...']);
}

final class PurchaseSuccess extends PurchaseState {
  final String message;
  const PurchaseSuccess([this.message = 'Satın alma başarılı!']);
}

final class PurchaseError extends PurchaseState {
  final String message;
  final String? code;
  const PurchaseError(this.message, [this.code]);
}
