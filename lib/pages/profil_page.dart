import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/shop_provider.dart';
import '../providers/user_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    final hasShop = user?.shopId != null && user!.shopId!.trim().isNotEmpty;
    final userName = user?.name ?? 'Kullanıcı';
    final userEmail = user?.email ?? '';
    final userPhone = user?.phone ?? 'Belirtilmedi';
    final isEmailVerified = user?.isEmailVerified ?? false;
    final isPhoneVerified = user?.isPhoneVerified ?? false;
    final userRole = user?.role ?? '';

    if (user == null) {
      return Scaffold(
        backgroundColor: context.ct.bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: AppPageHeader(title: 'Profil'),
            ),

            // Profile Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xxl, Spacing.xxl, 0),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.xxl),
                  decoration: BoxDecoration(
                    color: context.ct.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
                  ),
                  child: Column(
                    children: [
                      AppAvatar(letter: userName, size: 80),
                      const SizedBox(height: Spacing.lg),
                      Text(userName, style: TextStyle(color: context.ct.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: Spacing.xs),
                      Text(userEmail, style: TextStyle(color: context.ct.textSecondary, fontSize: 14)),
                      if (userPhone.isNotEmpty && userPhone != 'Belirtilmedi') ...[
                        const SizedBox(height: 2),
                        Text(userPhone, style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
                      ],
                      const SizedBox(height: Spacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 2, vertical: Spacing.xs + 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          userRole == 'Barber' ? '✂️ Berber' : '👤 Müşteri',
                          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isEmailVerified && isPhoneVerified) ...[
                        const SizedBox(height: Spacing.sm + 2),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, color: AppColors.success, size: 16),
                            SizedBox(width: 4),
                            Text('Doğrulanmış Hesap', style: TextStyle(color: AppColors.success, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Verification Alerts
            if (!isEmailVerified || !isPhoneVerified)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.lg, Spacing.xxl, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EYLEM BEKLİYOR', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm + 2),
                      if (!isEmailVerified) _buildAlertTile(Icons.email_outlined, 'E-postayı Doğrula', AppColors.warning, () async {
                        final error = await FirebaseAuthService().sendEmailVerification();
                        if (!mounted) return;
                        if (error != null) {
                          showAppSnackBar(context, error, isError: true);
                        } else {
                          showAppSnackBar(context, 'Doğrulama e-postası gönderildi. Gelen kutunuzu kontrol edin.');
                        }
                      }),
                      if (!isPhoneVerified) _buildAlertTile(Icons.phone_android, 'Telefonu Doğrula', AppColors.warning, () {
                        Navigator.pushNamed(context, '/phone_verification_page');
                      }),
                    ],
                  ),
                ),
              ),

            // Menu Items
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.xxl, Spacing.xxl, Spacing.xxl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HESAP VE YÖNETİM', style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: Spacing.sm + 2),

                    if (userRole == 'Barber') ...[
                      AppMenuItem(icon: Icons.content_cut, label: 'Hizmetlerim', onTap: () => Navigator.pushNamed(context, '/service_management')),
                      AppMenuItem(icon: Icons.access_time_rounded, label: 'Çalışma Saatleri', onTap: () {
                        if (hasShop) {
                          Navigator.pushNamed(context, '/working-hours');
                        } else {
                          showAppSnackBar(context, 'Çalışma saatlerini düzenlemek için önce bir dükkana katılın veya yeni bir dükkan oluşturun.', isError: true);
                        }
                      }),
                      if (hasShop)
                        AppMenuItem(icon: Icons.storefront_outlined, label: 'Dükkan Bilgileri', onTap: () => Navigator.pushNamed(context, '/shop_detail_page')),
                      if (hasShop)
                        AppMenuItem(icon: Icons.workspace_premium, label: 'Abonelik', onTap: () => Navigator.pushNamed(context, '/subscription')),
                    ],

                    const SizedBox(height: Spacing.lg),
                    AppMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Ayarlar',
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    AppMenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Çıkış Yap',
                      isDestructive: true,
                      onTap: () async {
                        final userProvider = Provider.of<UserProvider>(context, listen: false);
                        final shopProvider = Provider.of<ShopProvider>(context, listen: false);

                        // FCM token sil
                        final jwt = userProvider.user?.jwtToken;
                        if (jwt != null && jwt.isNotEmpty) {
                          await NotificationService().removeTokenFromServer(jwt);
                        }

                        await userProvider.logout();
                        await shopProvider.clearShop();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      },
                    ),

                    const SizedBox(height: Spacing.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm + 2),
      child: Material(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg + 2, vertical: Spacing.md + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: color.withAlpha(35)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: Spacing.md + 2),
                Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600))),
                Icon(Icons.arrow_forward_ios, color: color.withAlpha(120), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
