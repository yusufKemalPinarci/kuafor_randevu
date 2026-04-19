import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kuaflex/providers/shop_provider.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'providers/user_provider.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/BarberHomePage.dart';
import 'pages/AllAppointmentsPage.dart';
import 'pages/working_days_page.dart';
import 'pages/shop_selection_page.dart';
import 'pages/create_shop_page.dart';
import 'pages/profil_page.dart';
import 'pages/shop_detail_page.dart';
import 'pages/shop_edit_page.dart';
import 'pages/phone_verification_page.dart';
import 'pages/CustomerHomePage.dart';
import 'pages/GuestShopSelectionPage.dart';
import 'pages/SplashPage.dart';
import 'pages/service_management_page.dart';
import 'pages/subscription_page.dart';
import 'pages/admin/admin_home_page.dart';
import 'pages/barber_block_time_page.dart';
import 'pages/barber_manual_appointment_page.dart';
import 'pages/booking_link_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/settings_page.dart';
import 'pages/guest_appointment_lookup_page.dart';
import 'pages/appointment_detail_page.dart';
import 'pages/shop_options_page.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'services/api_client.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release modda HTTP güvenliği: geçersiz sertifikaları asla kabul etme
  if (kReleaseMode) {
    HttpOverrides.global = SecureHttpOverrides();
  }

  await Firebase.initializeApp();

  // FCM arka plan handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Bildirim servisini başlat
  await NotificationService().initialize();

  // Güvenlik kontrollerini başlat (root, debugger, hooking, tamper)
  // İlk release build'den sonra expectedCertHash'i doldurun:
  //   1. Release APK oluşturun
  //   2. Debug modda SecurityService().getSecurityStatus() ile hash'i alın
  //   3. Aşağıdaki değere yapıştırın
  await SecurityService().initialize(
    // expectedCertHash: 'RELEASE_APK_SHA256_HASH_BURAYA',
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: const BerberApp(),
    ),
  );
}


class BerberApp extends StatefulWidget {
  const BerberApp({super.key});

  @override
  State<BerberApp> createState() => _BerberAppState();
}

class _BerberAppState extends State<BerberApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  Timer? _securityTimer;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen(_handleDeepLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Bildirime tıklandığında randevu detayına git
    NotificationService().onNotificationTap = (appointmentId) {
      if (appointmentId == null) return;
      _navigateToAppointment(appointmentId);
    };

    // Periyodik güvenlik kontrolü (5 dk arayla — debugger/hook tespiti)
    if (kReleaseMode) {
      _securityTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => SecurityService().periodicCheck(),
      );
    }
  }

  @override
  void dispose() {
    _securityTimer?.cancel();
    super.dispose();
  }

  Future<void> _navigateToAppointment(String appointmentId) async {
    try {
      final userProvider =
          _navigatorKey.currentContext?.read<UserProvider>();
      final jwt = userProvider?.user?.jwtToken;
      if (jwt == null) return;

      final response = await ApiClient().get('/api/appointment/$appointmentId');
      if (response.statusCode == 200) {
        final appointment =
            jsonDecode(response.body) as Map<String, dynamic>;
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                AppointmentDetailPage(appointment: appointment),
          ),
        );
      }
    } catch (_) {
      // Navigasyon başarısız olursa sessizce geç
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'kuaflex' && uri.host == 'randevu') {
      final shopCode = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (shopCode != null && shopCode.isNotEmpty) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => BookingLinkPage(shopCode: shopCode),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (ctx, themeProvider, _) {
        final isDark = themeProvider.isDark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor:
              isDark ? AppColors.bg : const Color(0xFFF5F0E8),
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'KuaFlex',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: buildLightAppTheme(),
      darkTheme: buildAppTheme(),
      home: const SplashPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/barberHome': (context) => const BarberHomePage(),
        '/customerHome': (context) => const CustomerHomePage(),
        '/allAppointments': (context) => const AllAppointmentsPage(),
        '/working-hours': (context) => const WorkingDaysPage(),
        '/shop_selection_page': (context) => const ShopSelectionPage(),
        '/create-shop-page': (context) => CreateShopPage(),
        '/profile_page': (context) => const ProfilePage(),
        '/shop_detail_page': (context) => const ShopDetailPage(),
        '/shop_edit_page': (context) => const ShopEditPage(),
        '/phone_verification_page': (context) => const PhoneVerificationPage(),
        '/guestShopSelection': (context) => const GuestShopSelectionPage(),
        '/service_management': (context) => const ServiceManagementPage(),
        '/subscription': (context) => const SubscriptionPage(),
        '/adminHome': (context) => const AdminHomePage(),
        '/barberBlockTime': (context) => const BarberBlockTimePage(),
        '/barberManualAppointment': (context) => const BarberManualAppointmentPage(),
        '/forgotPassword': (context) => const ForgotPasswordPage(),
        '/settings': (context) => const SettingsPage(),
        '/guestAppointmentLookup': (context) => const GuestAppointmentLookupPage(),
        '/barber-shop-options': (context) => const ShopOptionPage(),
      },
      );
      },
    );
  }
}
