import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../services/api_client.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _stats;
  List<dynamic> _recentUsers = [];
  List<dynamic> _recentAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final response = await ApiClient().get('/api/admin/dashboard');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = data['stats'];
          _recentUsers = data['recentUsers'] ?? [];
          _recentAppointments = data['recentAppointments'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) showAppSnackBar(context, 'Panel verileri yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Bağlantı hatası.', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_stats == null) {
      return AppEmptyState(icon: Icons.error_outline, title: 'Veriler yüklenemedi');
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.ct.surface,
      onRefresh: _fetchDashboard,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: Spacing.lg),

          // Greeting
          Text('Admin Paneli', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: Spacing.xs),
          Text('Genel bakış ve yönetim', style: TextStyle(color: context.ct.textTertiary, fontSize: 14)),
          const SizedBox(height: Spacing.xxl),

          // Stats Grid
          _buildStatRow([
            _StatItem('Toplam Kullanıcı', '${_stats!['totalUsers'] ?? 0}', Icons.people, AppColors.info, context.ct.infoSoft),
            _StatItem('Berberler', '${_stats!['totalBarbers'] ?? 0}', Icons.content_cut, AppColors.primary, context.ct.warningSoft),
          ]),
          const SizedBox(height: Spacing.md),
          _buildStatRow([
            _StatItem('Müşteriler', '${_stats!['totalCustomers'] ?? 0}', Icons.person, AppColors.success, context.ct.successSoft),
            _StatItem('Dükkanlar', '${_stats!['totalShops'] ?? 0}', Icons.storefront, AppColors.warning, context.ct.warningSoft),
          ]),
          const SizedBox(height: Spacing.md),
          _buildStatRow([
            _StatItem('Aktif Abonelik', '${_stats!['activeSubscriptions'] ?? 0}', Icons.workspace_premium, AppColors.success, context.ct.successSoft),
            _StatItem('Süresi Dolmuş', '${_stats!['expiredSubscriptions'] ?? 0}', Icons.timer_off, AppColors.error, context.ct.errorSoft),
          ]),
          const SizedBox(height: Spacing.md),
          _buildStatRow([
            _StatItem('Bugünkü Randevu', '${_stats!['todayAppointments'] ?? 0}', Icons.today, AppColors.info, context.ct.infoSoft),
            _StatItem('Bu Ay', '${_stats!['monthAppointments'] ?? 0}', Icons.calendar_month, AppColors.primary, context.ct.warningSoft),
          ]),
          const SizedBox(height: Spacing.md),

          // Revenue card
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                ),
                const SizedBox(width: Spacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tahmini Gelir', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('₺${_stats!['estimatedRevenue'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.xxxl),

          // Recent Users
          Text('SON KAYIT OLAN KULLANICILAR', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: Spacing.md),
          ..._recentUsers.map((u) => _buildRecentUserTile(u)),

          const SizedBox(height: Spacing.xxl),

          // Recent Appointments
          Text('SON RANDEVULAR', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: Spacing.md),
          ..._recentAppointments.map((a) => _buildRecentAppointmentTile(a)),

          const SizedBox(height: Spacing.huge),
        ],
      ),
    );
  }

  Widget _buildStatRow(List<_StatItem> items) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: item == items.first ? Spacing.sm : 0, left: item == items.last ? Spacing.sm : 0),
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: item.bgColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: item.color.withAlpha(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: item.color, size: 22),
                const SizedBox(height: Spacing.sm + 2),
                Text(item.value, style: TextStyle(color: item.color, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item.label, style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentUserTile(dynamic user) {
    final role = user['role'] ?? '';
    final roleBadge = role == 'Barber' ? '✂️' : role == 'Admin' ? '🛡️' : '👤';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md + 2),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
        ),
        child: Row(
          children: [
            AppAvatar(letter: user['name'] ?? '?', size: 40, withShadow: false),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(user['email'] ?? '-', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            Text(roleBadge, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAppointmentTile(dynamic appt) {
    final barberName = appt['barberId'] is Map ? (appt['barberId']['name'] ?? '-') : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md + 2),
        decoration: BoxDecoration(
          color: context.ct.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
        ),
        child: Row(
          children: [
            AppAvatar(letter: appt['customerName'] ?? '?', size: 40, withShadow: false),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt['customerName'] ?? '-', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Berber: $barberName', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            AppStatusBadge(status: appt['status'] ?? 'pending'),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  _StatItem(this.label, this.value, this.icon, this.color, this.bgColor);
}
