import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final _firebaseAuth = FirebaseAuthService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAppSnackBar(context, "Lütfen tüm alanları doldurun.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _firebaseAuth.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (result.error != null) {
        showAppSnackBar(context, result.error!, isError: true);
        return;
      }

      final user = result.user;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.saveUserToLocal(user);

      _registerFcmToken(user.jwtToken);

      if (!mounted) return;
      _navigateByRole(user.role);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      // İlk deneme — role göndermeden
      final result = await _firebaseAuth.signInWithGoogle();

      if (!mounted) return;

      // Kullanıcı iptal etti
      if (result.error == null && result.needsRole == false && result.user.id.isEmpty) {
        return;
      }

      if (result.error != null) {
        showAppSnackBar(context, result.error!, isError: true);
        return;
      }

      // Yeni kullanıcı — rol seçimi gerekiyor
      if (result.needsRole) {
        final role = await _showRoleSelectionDialog(null, null);
        if (role == null || !mounted) return;

        final retryResult = await _firebaseAuth.signInWithGoogle(role: role);
        if (!mounted) return;

        if (retryResult.error != null) {
          showAppSnackBar(context, retryResult.error!, isError: true);
          return;
        }
        await _completeLogin(retryResult.user);
        return;
      }

      await _completeLogin(result.user);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<String?> _showRoleSelectionDialog(String? name, String? email) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Hoş Geldiniz!',
            style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null)
              Text(name, style: TextStyle(color: context.ct.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Nasıl kullanmak istersiniz?',
                style: TextStyle(color: context.ct.textTertiary, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'Customer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: context.ct.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: context.ct.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_outline, color: AppColors.primary, size: 30),
                          SizedBox(height: 8),
                          Text('Müşteri',
                              style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Randevu al',
                              style: TextStyle(color: context.ct.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'Barber'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: context.ct.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: context.ct.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.content_cut, color: AppColors.primary, size: 30),
                          SizedBox(height: 8),
                          Text('Berber',
                              style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Dükkan yönet',
                              style: TextStyle(color: context.ct.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('İptal', style: TextStyle(color: context.ct.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeLogin(UserModel user) async {
    if (!mounted) return;
    await Provider.of<UserProvider>(context, listen: false).saveUserToLocal(user);
    _registerFcmToken(user.jwtToken);
    if (!mounted) return;
    _navigateByRole(user.role);
  }

  void _navigateByRole(String role) {
    if (role == 'Admin') {
      Navigator.pushReplacementNamed(context, '/adminHome');
    } else if (role == 'Barber') {
      Navigator.pushReplacementNamed(context, '/barberHome');
    } else {
      Navigator.pushReplacementNamed(context, '/customerHome');
    }
  }

  void _registerFcmToken(String? jwtToken) async {
    if (jwtToken == null || jwtToken.isEmpty) return;
    final notifService = NotificationService();
    final fcmToken = await notifService.getToken();
    if (fcmToken != null) {
      await notifService.sendTokenToServer(fcmToken, jwtToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withAlpha(25), Colors.transparent]),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl + 4),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: Spacing.huge),

                      // Logo — uygulama ikonu
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 88,
                          height: 88,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),
                      Text('KuaFlex', style: Theme.of(context).textTheme.headlineLarge!.copyWith(letterSpacing: 1)),
                      const SizedBox(height: Spacing.sm),
                      Text('Randevunu kolayca yönet', style: TextStyle(fontSize: 14, color: context.ct.textTertiary)),
                      const SizedBox(height: Spacing.massive),

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                        cursorColor: AppColors.primary,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined, size: 22),
                          hintText: 'E-posta adresiniz',
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                        cursorColor: AppColors.primary,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, size: 22),
                          hintText: 'Şifreniz',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),

                      // Şifremi Unuttum linki
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/forgotPassword'),
                          child: const Text(
                            'Şifremi Unuttum?',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),

                      // Login button
                      AppLoadingButton(
                        label: 'Giriş Yap',
                        isLoading: _isLoading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: Spacing.xl),

                      // Register link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Hesabın yok mu? ', style: TextStyle(color: context.ct.textTertiary, fontSize: 14)),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              'Kayıt Ol',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.xxxl),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: context.ct.surfaceBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                            child: Text('veya', style: TextStyle(color: context.ct.textHint, fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: context.ct.surfaceBorder)),
                        ],
                      ),
                      const SizedBox(height: Spacing.xxl),

                      // Google Sign-In button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.ct.textPrimary,
                            side: BorderSide(color: context.ct.surfaceBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg)),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: AppColors.primary),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _GoogleIcon(),
                                    SizedBox(width: 10),
                                    Text('Google ile Giriş Yap',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 15)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),

                      // Guest links
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/guestShopSelection'),
                            child: Text(
                              'Kayıt Olmadan Randevu Al',
                              style: TextStyle(color: context.ct.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                            child: Text('·', style: TextStyle(color: context.ct.textHint, fontSize: 13)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/guestAppointmentLookup'),
                            child: Text(
                              'Randevumu Sorgula',
                              style: TextStyle(color: context.ct.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.huge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Google logo ikonu (basit beyaz daire içinde renkli G)
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
