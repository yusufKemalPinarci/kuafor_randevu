import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';
import 'GuestShopSelectionPage.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyAppointments();
  }

  Future<void> _fetchMyAppointments() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.user?.jwtToken;

    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await ApiClient().get('/api/appointment/my');

      if (response.statusCode == 200) {
        setState(() {
          _appointments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final userName = user?.name ?? 'Müşteri';

    final now = DateTime.now();
    final days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final dateLabel = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    final upcoming = _appointments.where((a) => a['status'] != 'cancelled').toList();
    final upcomingCount = upcoming.length;

    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: context.ct.surface,
          onRefresh: _fetchMyAppointments,
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
                      AppIconBtn(icon: Icons.person_outline, onTap: () => Navigator.pushNamed(context, '/profile_page')),
                    ],
                  ),
                ),
              ),

              // Book Now CTA
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.lg),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestShopSelectionPage())),
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.xxl),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withAlpha(40), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Yeni Randevu Al',
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                                  ),
                                  const SizedBox(height: Spacing.sm),
                                  Text(
                                    'Çevrenizdeki berberleri keşfedin',
                                    style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Spacing.lg),
                            Container(
                              padding: const EdgeInsets.all(Spacing.md + 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(45),
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              child: const Icon(Icons.content_cut, color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Stats Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                  child: Row(
                    children: [
                      AppStatCard(label: 'Aktif', value: '$upcomingCount', icon: Icons.calendar_today, bgColor: context.ct.successSoft, accentColor: AppColors.success),
                      const SizedBox(width: Spacing.md),
                      AppStatCard(label: 'Toplam', value: '${_appointments.length}', icon: Icons.history, bgColor: context.ct.infoSoft, accentColor: AppColors.info),
                    ],
                  ),
                ),
              ),

              // Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xxxl - 4, Spacing.xxl, Spacing.md),
                  child: Row(
                    children: [
                      Text('Randevularım', style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      if (_appointments.isNotEmpty)
                        Text('${_appointments.length} randevu', style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
                    ],
                  ),
                ),
              ),

              // Appointments List
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  : _appointments.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.calendar_today_outlined,
                            title: 'Henüz randevunuz yok',
                            subtitle: 'İlk randevunuzu hemen oluşturun',
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xxl),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildAppointmentCard(_appointments[i]),
                              childCount: _appointments.length,
                            ),
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(dynamic appt) {
    final barber = appt['barberId'];
    final service = appt['serviceId'];
    final status = appt['status'] ?? 'pending';
    final date = appt['date'] ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md + 2),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg + 2),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.content_cut, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: Spacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service is Map ? service['title'] ?? 'Hizmet' : 'Hizmet',
                        style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        barber is Map ? barber['name'] ?? 'Berber' : 'Berber',
                        style: TextStyle(color: context.ct.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                AppStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: Spacing.md + 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.sm + 2),
              decoration: BoxDecoration(
                color: context.ct.surfaceLight.withAlpha(100),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 15, color: context.ct.textTertiary),
                  const SizedBox(width: Spacing.sm),
                  Text(date, style: TextStyle(color: context.ct.textSecondary, fontSize: 14)),
                  if (service is Map && service['price'] != null) ...[
                    const Spacer(),
                    Text(
                      '₺${service['price']}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
