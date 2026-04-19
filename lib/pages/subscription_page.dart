import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../models/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../providers/user_provider.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with WidgetsBindingObserver {
  final _referralController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProvider();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _referralController.dispose();
    super.dispose();
  }

  /// Uygulama ön plana geldiğinde abonelik durumunu yenile (Anti-Tampering).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSubscription();
    }
  }

  Future<void> _initProvider() async {
    final user = context.read<UserProvider>().user;
    final provider = context.read<SubscriptionProvider>();
    await provider.init(user?.jwtToken);
  }

  Future<void> _refreshSubscription() async {
    final user = context.read<UserProvider>().user;
    if (user?.jwtToken == null) return;
    await context.read<SubscriptionProvider>().refreshSubscription(user!.jwtToken!);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final hasShop = user?.shopId != null && user!.shopId!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, provider, _) {
            // Purchase state listener — snackbar gösterimi
            _listenPurchaseState(provider);

            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: AppPageHeader(title: 'Abonelik')),

                // Dükkan yok uyarı
                if (!hasShop)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Önce dükkan gerekli',
                      subtitle: 'Abonelik oluşturmak için önce bir dükkan oluşturmalısınız.',
                    ),
                  )
                // Hata durumu
                else if (provider.errorMessage != null && provider.subscriptionInfo == null && provider.availableOffers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorState(provider),
                  )
                // Aktif abonelik
                else if (provider.subscriptionInfo != null && provider.isSubscriptionActive) ...[
                  SliverToBoxAdapter(child: _buildActiveSubscriptionCard(provider)),
                  SliverToBoxAdapter(child: _buildReferralCodeCard(provider)),
                  SliverToBoxAdapter(child: const SizedBox(height: Spacing.xxl)),
                  SliverToBoxAdapter(child: _buildRestorePurchasesButton(provider)),
                ]
                // Süresi dolmuş
                else if (provider.subscriptionInfo != null && provider.subscriptionInfo!.status == SubscriptionStatus.expired) ...[
                  SliverToBoxAdapter(child: _buildExpiredCard()),
                  SliverToBoxAdapter(child: const SizedBox(height: Spacing.xxl)),
                  SliverToBoxAdapter(child: _buildTierSelection(provider)),
                  SliverToBoxAdapter(child: const SizedBox(height: Spacing.lg)),
                  SliverToBoxAdapter(child: _buildPurchaseSection(provider)),
                ]
                // Hiç abonelik yok
                else ...[
                  SliverToBoxAdapter(child: _buildNoPlanHeader()),
                  SliverToBoxAdapter(child: _buildTierSelection(provider)),
                  SliverToBoxAdapter(child: const SizedBox(height: Spacing.lg)),
                  SliverToBoxAdapter(child: _buildPurchaseSection(provider)),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: Spacing.huge)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Purchase State Listener ────────────────────────────────
  PurchaseState? _lastPurchaseState;

  void _listenPurchaseState(SubscriptionProvider provider) {
    final current = provider.purchaseState;
    if (current == _lastPurchaseState) return;
    _lastPurchaseState = current;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (current) {
        case PurchaseSuccess(:final message):
          showAppSnackBar(context, message);
          provider.resetPurchaseState();
        case PurchaseError(:final message):
          showAppSnackBar(context, message, isError: true);
          provider.resetPurchaseState();
        default:
          break;
      }
    });
  }

  // ─── Hata Durumu ────────────────────────────────────────────
  Widget _buildErrorState(SubscriptionProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              provider.errorMessage ?? 'Bir hata oluştu',
              style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xl),
            AppLoadingButton(
              label: 'Tekrar Dene',
              onPressed: _initProvider,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Aktif Abonelik Kartı ──────────────────────────────────
  Widget _buildActiveSubscriptionCard(SubscriptionProvider provider) {
    final info = provider.subscriptionInfo!;
    final remaining = info.remainingDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.xxl, 0),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xxl),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(40), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm + 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                ),
                const SizedBox(width: Spacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Aktif Abonelik', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${info.tierLabel} · ${info.billingPeriodLabel}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$remaining gün', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: Spacing.sm + 2),
                  Text(
                    info.endDate != null
                        ? 'Bitiş: ${info.endDate!.day.toString().padLeft(2, '0')}.${info.endDate!.month.toString().padLeft(2, '0')}.${info.endDate!.year}'
                        : 'Bitiş tarihi bilinmiyor',
                    style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            // Google Play üzerinden yönet bilgi notu
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withAlpha(180), size: 16),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Aboneliğinizi Google Play Store → Abonelikler bölümünden yönetebilirsiniz.',
                      style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Referans Kodu Kartı (aktif abonelik) ──────────────────
  Widget _buildReferralCodeCard(SubscriptionProvider provider) {
    final info = provider.subscriptionInfo!;
    final referralCode = info.referralCode ?? '';
    if (referralCode.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: AppColors.primary, size: 20),
                const SizedBox(width: Spacing.sm + 2),
                Text('Referans Kodunuz', style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: Spacing.sm + 2),
            Text(
              'Bu kodu arkadaşlarınızla paylaşın. Sizin kodunuzla abone olanlar ücretsiz başlar, siz de bonus gün kazanırsınız!',
              style: TextStyle(color: context.ct.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: Spacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: SelectableText(
                referralCode,
                style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3),
                textAlign: TextAlign.center,
              ),
            ),
            if ((info.referralCount ?? 0) > 0) ...[
              const SizedBox(height: Spacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, color: AppColors.success, size: 18),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${info.referralCount} kişi kodunuzu kullandı',
                      style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Süresi Dolmuş Kartı ──────────────────────────────────
  Widget _buildExpiredCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.xxl, 0),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xxl),
        decoration: BoxDecoration(
          color: context.ct.errorSoft,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.error.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Abonelik Süresi Doldu', style: TextStyle(color: AppColors.error, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Dükkanınız artık müşteri listesinde görünmüyor. Yenilemek için aşağıdan plan seçin.',
                    style: TextStyle(color: context.ct.textSecondary, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Plan Yok Header ───────────────────────────────────────
  Widget _buildNoPlanHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.xxl, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Dükkanınızı Listeleyin',
            style: TextStyle(color: context.ct.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm + 2),
          Text(
            'Abone olarak dükkanınızı müşterilere açın. Referans veya promosyon kodu ile ücretsiz başlayabilirsiniz!',
            style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Paket Seçimi (Tier) ─────────────────────────────────────
  Widget _buildTierSelection(SubscriptionProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.xxl),
          Text('Paket Seçin', style: TextStyle(color: context.ct.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              // Standart
              Expanded(child: _buildTierCard(
                provider: provider,
                tier: SubscriptionTier.standart,
                features: const ['Dükkan listeleme', 'Randevu yönetimi', 'Hizmet tanımlama', 'Randevu linki'],
                enabled: true,
              )),
              const SizedBox(width: Spacing.sm + 2),
              // Profesyonel
              Expanded(child: _buildTierCard(
                provider: provider,
                tier: SubscriptionTier.pro,
                features: const ['SMS bildirimler', 'Çalışan yönetimi', 'Gelişmiş raporlar'],
                enabled: false,
              )),
              const SizedBox(width: Spacing.sm + 2),
              // Premium
              Expanded(child: _buildTierCard(
                provider: provider,
                tier: SubscriptionTier.premium,
                features: const ['Tüm Pro özellikler', 'Öncelikli destek', 'Özel entegrasyonlar'],
                enabled: false,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required SubscriptionProvider provider,
    required SubscriptionTier tier,
    required List<String> features,
    required bool enabled,
  }) {
    final isSelected = provider.selectedTier == tier && enabled;

    return GestureDetector(
      onTap: enabled ? () => provider.selectTier(tier) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(Spacing.md + 2),
        decoration: BoxDecoration(
          color: !enabled
              ? context.ct.surfaceLight
              : isSelected
                  ? AppColors.primary.withAlpha(15)
                  : context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.ct.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (!enabled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text('Yakında', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              tier.label,
              style: TextStyle(
                color: !enabled
                    ? context.ct.textHint
                    : isSelected
                        ? AppColors.primary
                        : context.ct.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm + 2),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled ? Icons.check : Icons.lock_outline,
                    size: 12,
                    color: !enabled
                        ? context.ct.textHint
                        : isSelected
                            ? AppColors.primary
                            : context.ct.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      f,
                      style: TextStyle(
                        color: !enabled ? context.ct.textHint : context.ct.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: Spacing.md),
            Icon(
              isSelected ? Icons.check_circle : (enabled ? Icons.radio_button_unchecked : Icons.lock_outline),
              color: isSelected ? AppColors.primary : context.ct.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Satın Alma Bölümü ─────────────────────────────────────
  Widget _buildPurchaseSection(SubscriptionProvider provider) {
    final isPurchasing = provider.purchaseState is PurchaseLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Süre seçimi (base plan kartları)
          if (provider.selectedTier == SubscriptionTier.standart) ...[
            _buildOfferCards(provider),
            const SizedBox(height: Spacing.xxl),
          ],

          // Referans kodu
          _buildReferralInput(provider),
          const SizedBox(height: Spacing.xxl),

          // Referans bonus highlight
          if (provider.referralValidation == 'valid' && provider.referralBonusDays != null)
            _buildBonusDaysHighlight(provider),

          // Satın al butonu
          if (provider.availableOffers.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            _buildPurchaseButton(provider, isPurchasing),
          ],

          const SizedBox(height: Spacing.lg),

          // Geri yükle
          _buildRestorePurchasesButton(provider),

          const SizedBox(height: Spacing.lg),

          // Google Play güvenlik bilgisi
          _buildSecurityNote(),
        ],
      ),
    );
  }

  // ─── Süre Seçimi Kartları (Offer / Base Plan) ──────────────
  Widget _buildOfferCards(SubscriptionProvider provider) {
    final offers = provider.availableOffers;

    if (offers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: context.ct.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, color: context.ct.textTertiary, size: 32),
            const SizedBox(height: Spacing.md),
            Text(
              'Abonelik paketleri yüklenemedi',
              style: TextStyle(color: context.ct.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.md),
            AppLoadingButton(
              label: 'Tekrar Dene',
              onPressed: _initProvider,
            ),
          ],
        ),
      );
    }

    // Aylık fiyatı bul (tasarruf yüzdesi hesabı için)
    final monthlyOffer = offers.where((o) => o.billingPeriod == BillingPeriod.monthly).firstOrNull;
    final monthlyPrice = monthlyOffer?.rawPrice ?? offers.first.rawPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Süre Seçin', style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: Spacing.md),
        Row(
          children: offers.map((offer) {
            final isSelected = provider.selectedOffer?.basePlanId == offer.basePlanId;
            final isYearly = offer.billingPeriod == BillingPeriod.yearly;

            // Tasarruf yüzdesi hesapla
            int savingsPercent = 0;
            if (offer.billingPeriod == BillingPeriod.sixMonth && monthlyPrice > 0) {
              savingsPercent = ((1 - (offer.rawPrice / (monthlyPrice * 6))) * 100).round();
            } else if (offer.billingPeriod == BillingPeriod.yearly && monthlyPrice > 0) {
              savingsPercent = ((1 - (offer.rawPrice / (monthlyPrice * 12))) * 100).round();
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: offer == offers.first ? 0 : Spacing.sm,
                  right: offer == offers.last ? 0 : Spacing.sm,
                ),
                child: GestureDetector(
                  onTap: () => provider.selectOffer(offer),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(Spacing.xl),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withAlpha(15) : context.ct.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : context.ct.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isYearly) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(20),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text('En Popüler', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: Spacing.sm + 2),
                        ] else if (savingsPercent > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(20),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text('%$savingsPercent Tasarruf', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: Spacing.sm + 2),
                        ],
                        Text(
                          offer.billingPeriod.label,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : context.ct.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          offer.price,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : context.ct.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          offer.billingPeriod.suffix,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary.withAlpha(180) : context.ct.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? AppColors.primary : context.ct.textHint,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Referans Kodu Input ───────────────────────────────────
  Widget _buildReferralInput(SubscriptionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard, color: AppColors.primary, size: 18),
            const SizedBox(width: Spacing.sm),
            Text('Referans Kodu (Opsiyonel)', style: TextStyle(color: context.ct.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: Spacing.sm + 2),
        Text(
          'Referans veya promosyon kodunuz varsa girin — kazanılan ücretsiz gün sayısı anında görüntülenecek.',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _referralController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2),
                onChanged: (_) {
                  if (provider.referralValidation != null) {
                    provider.clearReferralCode();
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Referans kodu girin',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  suffixIcon: provider.referralValidation == 'valid'
                      ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                      : provider.referralValidation == 'invalid'
                          ? const Icon(Icons.cancel, color: AppColors.error, size: 22)
                          : null,
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                onTap: () => provider.checkReferralCode(_referralController.text),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.lg + 2),
                  child: const Icon(Icons.search, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
        if (provider.referralValidation == 'valid') ...[
          const SizedBox(height: Spacing.sm + 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              const SizedBox(width: Spacing.xs + 2),
              Text(
                provider.referralIsPromo ? 'Promosyon kodu geçerli ✓' : 'Referans kodu geçerli ✓',
                style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
        if (provider.referralValidation == 'invalid') ...[
          const SizedBox(height: Spacing.sm + 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.sm + 2),
            decoration: BoxDecoration(
              color: context.ct.errorSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 16),
                SizedBox(width: Spacing.sm),
                Text('Geçersiz referans kodu.', style: TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Ücretsiz Gün Vurgu Kartı ─────────────────────────────
  Widget _buildBonusDaysHighlight(SubscriptionProvider provider) {
    final days = provider.referralBonusDays!;
    final source = provider.referralIsPromo
        ? 'Promosyon kodu uygulandı'
        : 'Referans kodu doğrulandı${provider.referralShopName != null ? ' · ${provider.referralShopName}' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success.withAlpha(22), AppColors.success.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.success.withAlpha(70), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                const SizedBox(width: Spacing.xs + 2),
                Text(source, style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$days',
                style: const TextStyle(color: AppColors.success, fontSize: 80, fontWeight: FontWeight.w900, height: 0.9),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(' GÜN', style: TextStyle(color: AppColors.success, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          const Text(
            'Ücretsiz Abonelik Kazandınız',
            style: TextStyle(color: AppColors.success, fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm + 2),
          Text(
            'Deneme süreniz boyunca tüm premium özellikler aktif olacaktır.',
            style: TextStyle(color: AppColors.success.withAlpha(190), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Satın Al Butonu ───────────────────────────────────────
  Widget _buildPurchaseButton(SubscriptionProvider provider, bool isPurchasing) {
    final user = context.read<UserProvider>().user;
    final isTrialMode = provider.referralValidation == 'valid' && provider.referralBonusDays != null;

    // Seçili offer'ın fiyat bilgisi
    final offer = provider.selectedOffer;
    final priceLabel = offer?.price ?? '';
    final periodLabel = offer?.billingPeriod.suffix ?? '';

    final label = isTrialMode
        ? '${provider.referralBonusDays} Gün Ücretsiz Başla'
        : '$priceLabel$periodLabel · Abone Ol';

    return AppLoadingButton(
      label: label,
      isLoading: isPurchasing,
      onPressed: () {
        if (user?.shopId == null || user?.jwtToken == null) return;
        final referralCode = provider.referralValidation == 'valid'
            ? _referralController.text.trim()
            : null;

        provider.purchaseSubscription(
          shopId: user!.shopId!,
          jwtToken: user.jwtToken!,
          referralCode: referralCode,
        );
      },
    );
  }

  // ─── Geri Yükle Butonu ─────────────────────────────────────
  Widget _buildRestorePurchasesButton(SubscriptionProvider provider) {
    final user = context.read<UserProvider>().user;

    return Center(
      child: TextButton.icon(
        onPressed: () {
          if (user?.shopId == null || user?.jwtToken == null) return;
          provider.restorePurchases(
            shopId: user!.shopId!,
            jwtToken: user.jwtToken!,
          );
        },
        icon: Icon(Icons.restore, color: context.ct.textSecondary, size: 18),
        label: Text(
          'Satın Alımları Geri Yükle',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  // ─── Güvenlik Notu ─────────────────────────────────────────
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm + 2),
      decoration: BoxDecoration(
        color: context.ct.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: context.ct.textTertiary, size: 14),
          const SizedBox(width: Spacing.xs + 2),
          Expanded(
            child: Text(
              'Ödemeler Google Play güvencesiyle gerçekleştirilir. Kart bilgileriniz Google tarafından korunur.',
              style: TextStyle(color: context.ct.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
