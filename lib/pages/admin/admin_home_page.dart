import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../providers/user_provider.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_shops_page.dart';
import 'admin_subscriptions_page.dart';
import 'admin_appointments_page.dart';
import 'admin_promo_codes_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _currentIndex = 0;

  final _pages = const [
    AdminDashboardPage(),
    AdminUsersPage(),
    AdminShopsPage(),
    AdminSubscriptionsPage(),
    AdminAppointmentsPage(),
    AdminPromoCodesPage(),
  ];

  final _labels = const ['Panel', 'Kullanıcılar', 'Dükkanlar', 'Abonelikler', 'Randevular', 'Promo'];
  final _icons = const [
    Icons.dashboard_outlined,
    Icons.people_outlined,
    Icons.storefront_outlined,
    Icons.card_membership_outlined,
    Icons.calendar_today_outlined,
    Icons.qr_code_outlined,
  ];
  final _activeIcons = const [
    Icons.dashboard,
    Icons.people,
    Icons.storefront,
    Icons.card_membership,
    Icons.calendar_today,
    Icons.qr_code,
  ];

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Çıkış Yap', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: TextStyle(color: context.ct.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: context.ct.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkış Yap', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      appBar: AppBar(
        backgroundColor: context.ct.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
            ),
            const SizedBox(width: Spacing.md),
            Text('Admin Paneli', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
          ],
        ),
        actions: [
          AppIconBtn(
            icon: Icons.logout,
            tooltip: 'Çıkış Yap',
            onTap: _logout,
            iconColor: AppColors.error,
          ),
          const SizedBox(width: Spacing.md),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.ct.surface,
          border: Border(top: BorderSide(color: context.ct.surfaceBorder.withAlpha(60))),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_pages.length, (i) => _buildNavItem(i)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary.withAlpha(18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  isActive ? _activeIcons[index] : _icons[index],
                  color: isActive ? AppColors.primary : context.ct.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _labels[index],
                style: TextStyle(
                  color: isActive ? AppColors.primary : context.ct.textHint,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
