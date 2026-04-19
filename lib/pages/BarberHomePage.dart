import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kuaflex/pages/appointment_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';

class BarberHomePage extends StatefulWidget {
  const BarberHomePage({super.key});

  @override
  State<BarberHomePage> createState() => _BarberHomePageState();
}

class _BarberHomePageState extends State<BarberHomePage> {
  List<Map<String, dynamic>> todaysAppointments = [];
  bool isLoading = true;
  String? _shopCode;
  bool _isShopOwner = false;
  bool? _isSubscriptionActive;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _fetchShopCode();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchShopCode() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopId = userProvider.user?.shopId;
    final userId = userProvider.user?.id;
    if (shopId == null || shopId.trim().isEmpty) return;

    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/shop/$shopId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() {
          _shopCode = data['shopCode'];
          _isShopOwner = userId != null && data['ownerId']?.toString() == userId;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSubscriptionStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopId = userProvider.user?.shopId;
    if (shopId == null || shopId.trim().isEmpty) return;

    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/subscription/status/$shopId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() {
          _isSubscriptionActive = data['isActive'] == true;
        });
      } else {
        if (mounted) setState(() => _isSubscriptionActive = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSubscriptionActive = false);
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() => isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.user?.jwtToken;
      if (token == null) return;

      final response = await ApiClient().get('/api/appointment/my_berber');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final filteredData = data.where((appt) => appt['date'] == todayStr).toList();

        setState(() {
          todaysAppointments = filteredData.map((appt) {
            String formattedTime = '';
            if (appt['startTime'] != null) {
              try {
                final startTime = DateTime.parse(appt['startTime']).toLocal();
                formattedTime = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
              } catch (_) {
                formattedTime = appt['startTime'].toString();
              }
            }
            return {
              'id': appt['_id'],
              'customer': appt['customerName'] ?? 'Bilinmeyen Müşteri',
              'time': formattedTime,
              'phone': appt['customerPhone'] ?? '-',
              'date': appt['date'],
              'status': appt['status'] ?? 'pending',
              'notes': appt['notes'] ?? '',
            };
          }).toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final userName = user?.name ?? 'Berber';
    final shopId = user?.shopId;
    final hasShop = shopId != null && shopId.trim().isNotEmpty;
    final totalAppointments = todaysAppointments.length;

    final now = DateTime.now();
    final days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final dateLabel = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: context.ct.surface,
          onRefresh: _fetchAppointments,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xl, Spacing.xxl, Spacing.sm),
                  child: Row(
                    children: [
                      AppAvatar(letter: userName, size: 48),
                      const SizedBox(width: Spacing.md + 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateLabel, style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('Merhaba, $userName 👋', style: TextStyle(color: context.ct.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      AppIconBtn(
                        icon: Icons.storefront_rounded,
                        onTap: () {
                          if (hasShop) {
                            Navigator.pushNamed(context, '/shop_detail_page');
                          } else {
                            _showShopOptionsBottomSheet();
                          }
                        },
                      ),
                      const SizedBox(width: Spacing.sm),
                      AppIconBtn(icon: Icons.person_outline, onTap: () => Navigator.pushNamed(context, '/profile_page')),
                    ],
                  ),
                ),
              ),

              // Subscription Warning Banner (sadece dükkan sahibine, abonelik yoksa/dolmuşsa)
              if (hasShop && _isShopOwner && _isSubscriptionActive == false)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.sm, Spacing.xxl, 0),
                    child: Material(
                      color: context.ct.errorSoft,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/subscription'),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg + 2, vertical: Spacing.md + 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.error.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Spacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withAlpha(22),
                                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                              ),
                              const SizedBox(width: Spacing.md + 2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Abonelik Gerekli', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 2),
                                    Text(
                                      'Dükkanınız müşterilere gösterilmiyor. Abone olun!',
                                      style: TextStyle(color: context.ct.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: AppColors.error, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Onboarding Banner (no shop)
              if (!hasShop)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
                    child: Material(
                      color: context.ct.warningSoft,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: InkWell(
                        onTap: () => _showShopOptionsBottomSheet(),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.xl),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: AppColors.primary.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Spacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(22),
                                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                                ),
                                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(width: Spacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dükkanını Kur!', style: TextStyle(color: context.ct.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: Spacing.xs),
                                    Text('Bir dükkan oluştur veya mevcut bir dükkana katıl', style: TextStyle(color: context.ct.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
                  child: Row(
                    children: [
                      AppStatCard(
                        label: 'Bugün',
                        value: '$totalAppointments',
                        icon: Icons.event_available,
                        bgColor: context.ct.successSoft,
                        accentColor: AppColors.success,
                      ),
                      const SizedBox(width: Spacing.md),
                      AppStatCard(
                        label: 'Doluluk',
                        value: '${totalAppointments > 0 ? (totalAppointments / 10 * 100).toStringAsFixed(0) : 0}%',
                        icon: Icons.pie_chart_outline,
                        bgColor: context.ct.infoSoft,
                        accentColor: AppColors.info,
                        onTap: () => Navigator.pushNamed(context, '/allAppointments'),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              if (hasShop)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.person_add_alt_1_rounded,
                            label: 'Manuel Randevu',
                            color: AppColors.success,
                            bgColor: context.ct.successSoft,
                            onTap: () async {
                              final result = await Navigator.pushNamed(context, '/barberManualAppointment');
                              if (result == true) _fetchAppointments();
                            },
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.block_rounded,
                            label: 'Meşgul Saatler',
                            color: AppColors.warning,
                            bgColor: context.ct.warningSoft,
                            onTap: () => Navigator.pushNamed(context, '/barberBlockTime'),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.link_rounded,
                            label: 'Randevu Linki',
                            color: AppColors.primary,
                            bgColor: context.ct.primarySoft,
                            onTap: () {
                              if (_isSubscriptionActive == true && _shopCode != null) {
                                Share.share(
                                  'KuaFlex uygulamasıyla randevu alın:\nkuaflex://randevu/$_shopCode',
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bu özellik için aktif abonelik gerekli.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Today's Appointments Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xxxl - 4, Spacing.xxl, Spacing.md),
                  child: AppSectionLabel(
                    text: 'Bugünün Randevuları',
                    trailing: 'Tümü',
                    onTrailingTap: () => Navigator.pushNamed(context, '/allAppointments'),
                  ),
                ),
              ),

              // Appointments
              isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : todaysAppointments.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.event_busy,
                            title: 'Bugün randevunuz yok',
                            subtitle: 'Müşterileriniz randevu aldığında burada görünecek',
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xxl),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildAppointmentCard(todaysAppointments[i]),
                              childCount: todaysAppointments.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppointmentDetailPage(
                  appointment: {
                    'id': appt['id'],
                    'customer': appt['customer'],
                    'date': appt['date'] ?? '',
                    'time': appt['time'],
                    'phone': appt['phone'],
                    'status': appt['status'] ?? 'pending',
                    'notes': appt['notes'] ?? '',
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Row(
              children: [
                // Time badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Center(
                    child: Text(
                      appt['time'] ?? '??',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt['customer'] ?? 'Müşteri',
                        style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: Spacing.xs + 1),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, color: context.ct.textTertiary, size: 14),
                          const SizedBox(width: 4),
                          Text(appt['phone'] ?? '-', style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
                          const SizedBox(width: Spacing.sm + 2),
                          AppStatusBadge(status: appt['status'] ?? 'pending'),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: context.ct.textHint, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.ct.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg, horizontal: Spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: Spacing.sm + 2),
              Text(
                label,
                style: TextStyle(color: context.ct.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShopOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, Spacing.xxxl),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: context.ct.surfaceBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: Spacing.xxl),
            Text('Dükkan Seçenekleri', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Text('Bir dükkan oluşturun veya mevcut bir dükkana katılın.', style: TextStyle(color: context.ct.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xxl),
            _buildBottomSheetOption(
              icon: Icons.add_business_rounded,
              title: 'Dükkan Oluştur',
              subtitle: 'Yeni bir dükkan kurun ve yönetin',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/create-shop-page');
              },
            ),
            const SizedBox(height: Spacing.md),
            _buildBottomSheetOption(
              icon: Icons.group_add_outlined,
              title: 'Dükkana Katıl',
              subtitle: 'Davet kodu ile mevcut bir dükkana katılın',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/shop_selection_page');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: context.ct.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.ct.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: Spacing.xs),
                    Text(subtitle, style: TextStyle(color: context.ct.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: context.ct.textHint, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
