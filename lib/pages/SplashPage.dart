import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/shop_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _scaleAnimation = CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    await userProvider.loadUserFromLocal();
    await shopProvider.loadShopFromLocal();

    // ApiClient oturum süresi dolduğunda login'e yönlendir
    ApiClient().onSessionExpired = () {
      userProvider.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    };

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    if (userProvider.isLoggedIn) {
      // FCM token gönder
      _registerFcmToken(userProvider);

      final role = userProvider.user?.role;
      if (role == 'Admin') {
        Navigator.pushReplacementNamed(context, '/adminHome');
      } else if (role == 'Barber') {
        Navigator.pushReplacementNamed(context, '/barberHome');
      } else {
        Navigator.pushReplacementNamed(context, '/customerHome');
      }
    } else {
      // Token süresi dolmuşsa yerel verileri temizle
      await userProvider.logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _registerFcmToken(UserProvider userProvider) async {
    final jwt = userProvider.user?.jwtToken;
    if (jwt == null || jwt.isEmpty) return;

    final notifService = NotificationService();
    final fcmToken = await notifService.getToken();
    if (fcmToken != null) {
      await notifService.sendTokenToServer(fcmToken, jwt);
    }

    // Token yenilendiğinde de gönder
    notifService.onTokenRefresh.listen((newToken) {
      notifService.sendTokenToServer(newToken, jwt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: Stack(
        children: [
          // Subtle radial glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.primary.withAlpha(30), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 40, offset: const Offset(0, 12)),
                      ],
                    ),
                    child: const Icon(Icons.content_cut, size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'KuaFlex',
                          style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                            fontSize: 32,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          'Randevunu kolayca yönet',
                          style: TextStyle(color: context.ct.textTertiary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.huge),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
