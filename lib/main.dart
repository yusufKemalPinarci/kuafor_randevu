import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/shop_provider.dart';
import 'providers/user_provider.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/role_selection_page.dart';
import 'pages/BarberHomePage.dart';
import 'pages/SetAvailabilityPage.dart';
import 'pages/AllAppointmentsPage.dart';
import 'pages/working_days_page.dart';
import 'pages/shop_options_page.dart';
import 'pages/shop_selection_page.dart';
import 'pages/create_shop_page.dart';
import 'pages/verification_required_page.dart';
import 'pages/profil_page.dart';
import 'pages/shop_detail_page.dart';
import 'pages/shop_edit_page.dart';
import 'pages/phone_verification_page.dart';
import 'pages/customer_home_page.dart';
import 'pages/customer_shop_detail_page.dart';
import 'pages/staff_selection_page.dart';
import 'pages/service_selection_page.dart';
import 'pages/date_time_selection_page.dart';
import 'pages/guest_info_page.dart';
import 'pages/otp_verification_page.dart';
import 'pages/manage_services_page.dart';
import 'pages/customer_appointments_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }



  Future<void> _loadUser() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    await userProvider.loadUserFromLocal();
    await shopProvider.loadShopFromLocal(); // ← BURAYA EKLENDİ

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    print("isLoggedIn: ${userProvider.isLoggedIn}");
    print("user: ${userProvider.user}");
    //print("tokenExpiry: ${userProvider.user?.tokenExpiry}");
   // print("isTokenValid: ${userProvider.user?.isTokenValid}");

    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator(color: Color(0xFFC69749))),
        ),
      );
    }
    return MaterialApp(
      title: 'Berberim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC69749),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1F1F1F),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: userProvider.isLoggedIn
          ? (userProvider.user?.role == 'Barber' || userProvider.user?.role == 'Admin'
              ? const BarberHomePage()
              : const CustomerHomePage())
          : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/roleSelection': (context) => const RoleSelectionPage(),
        '/barberHome': (context) => const BarberHomePage(),
        '/customerHome': (context) => const CustomerHomePage(),
        '/setAvailability': (context) => const SetAvailabilityPage(),
        '/allAppointments': (context) => const AllAppointmentsPage(),
        '/working-hours': (context) => const WorkingDaysPage(),
        '/barber-shop-options': (context) => const ShopOptionPage(),
        '/shop_selection_page': (context) => const ShopSelectionPage(),
        '/create-shop-page': (context) => CreateShopPage(),
        '/verification-required': (context) => const VerificationRequiredPage(),
        '/profile_page': (context) => const ProfilePage(),
        '/shop_detail_page': (context) => const ShopDetailPage(),
        '/shop_edit_page': (context) => const ShopEditPage(),
        '/phone_verification_page': (context) => const PhoneVerificationPage(),
        '/customerShopDetail': (context) => const CustomerShopDetailPage(),
        '/staffSelection': (context) => const StaffSelectionPage(),
        '/serviceSelection': (context) => const ServiceSelectionPage(),
        '/dateTimeSelection': (context) => const DateTimeSelectionPage(),
        '/guestInfo': (context) => const GuestInfoPage(),
        '/otpVerification': (context) => const OtpVerificationPage(),
        '/manage-services': (context) => const ManageServicesPage(),
        '/customer-appointments': (context) => const CustomerAppointmentsPage(),
      },
    );
  }
}
