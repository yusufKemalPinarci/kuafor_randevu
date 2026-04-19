import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/firebase_auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final _firebaseAuth = FirebaseAuthService();
  String _selectedRole = 'Customer';
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
    _confirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      showAppSnackBar(context, "Lütfen tüm alanları doldurun.", isError: true);
      return;
    }

    if (pass != confirm) {
      showAppSnackBar(context, "Şifreler eşleşmiyor.", isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    if (!emailRegex.hasMatch(email)) {
      showAppSnackBar(context, "Lütfen geçerli bir e-posta adresi girin.", isError: true);
      return;
    }

    if (pass.length < 6) {
      showAppSnackBar(context, "Şifre en az 6 karakter olmalıdır.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _firebaseAuth.registerWithEmail(
        name: name,
        email: email,
        password: pass,
        role: _selectedRole,
      );

      if (!mounted) return;

      if (result.error != null) {
        showAppSnackBar(context, result.error!, isError: true);
        return;
      }

      final user = result.user;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.saveUserToLocal(user);

      if (!mounted) return;
      if (user.role == 'Barber') {
        Navigator.pushReplacementNamed(context, '/barberHome');
      } else {
        Navigator.pushReplacementNamed(context, '/customerHome');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    final roleLabel = _selectedRole == 'Barber' ? 'Berber' : 'Müşteri';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Kayıtı Onayla',
            style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: context.ct.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedRole == 'Barber' ? Icons.content_cut : Icons.person_outline,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(roleLabel,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text('olarak Google ile kayıt olacaksınız',
                            style: TextStyle(color: context.ct.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Devam etmek istiyor musunuz?',
              style: TextStyle(color: context.ct.textTertiary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: context.ct.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Devam Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isGoogleLoading = true);
    try {
      final result = await _firebaseAuth.signInWithGoogle(role: _selectedRole);

      if (!mounted) return;

      // Kullanıcı iptal etti
      if (result.error == null && !result.needsRole && result.user.id.isEmpty) {
        return;
      }

      if (result.error != null) {
        showAppSnackBar(context, result.error!, isError: true);
        return;
      }

      final user = result.user;
      await Provider.of<UserProvider>(context, listen: false).saveUserToLocal(user);
      if (!mounted) return;
      if (user.role == 'Barber') {
        Navigator.pushReplacementNamed(context, '/barberHome');
      } else {
        Navigator.pushReplacementNamed(context, '/customerHome');
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
            left: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withAlpha(20), Colors.transparent]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: context.ct.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl + 4),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: Spacing.sm),
                          Text('Hesap Oluştur', style: Theme.of(context).textTheme.headlineLarge),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'KuaFlex\'e katıl ve randevularını kolayca yönet',
                            style: TextStyle(fontSize: 14, color: context.ct.textTertiary),
                          ),
                          const SizedBox(height: Spacing.xxxl),

                          // Role Selector
                          Container(
                            decoration: BoxDecoration(
                              color: context.ct.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: context.ct.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                _buildRoleTab('Customer', 'Müşteri', Icons.person_outline),
                                _buildRoleTab('Barber', 'Berber', Icons.content_cut),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),

                          // Name
                          TextField(
                            controller: _nameController,
                            style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline, size: 22),
                              hintText: 'Ad Soyad',
                            ),
                          ),
                          const SizedBox(height: Spacing.md + 2),

                          // Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                            cursorColor: AppColors.primary,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined, size: 22),
                              hintText: 'E-posta adresi',
                            ),
                          ),
                          const SizedBox(height: Spacing.md + 2),

                          // Password
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline, size: 22),
                              hintText: 'Şifre (min. 6 karakter)',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.md + 2),

                          // Confirm Password
                          TextField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_reset, size: 22),
                              hintText: 'Şifre tekrar',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.xxxl),

                          // Register Button
                          AppLoadingButton(
                            label: 'Kayıt Ol',
                            isLoading: _isLoading,
                            onPressed: _register,
                          ),
                          const SizedBox(height: Spacing.lg),

                          // Ayırıcı
                          Row(
                            children: [
                              Expanded(child: Divider(color: context.ct.surfaceBorder)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                                child: Text('veya',
                                    style: TextStyle(
                                        color: context.ct.textHint, fontSize: 13)),
                              ),
                              Expanded(child: Divider(color: context.ct.surfaceBorder)),
                            ],
                          ),
                          const SizedBox(height: Spacing.lg),

                          // Google ile Kayıt
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _isGoogleLoading ? null : _registerWithGoogle,
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
                                        Text('Google ile Kayıt Ol',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 15)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),

                          // Login link
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Zaten hesabın var mı? ', style: TextStyle(color: context.ct.textTertiary, fontSize: 14)),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text('Giriş Yap', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.huge),
                        ],
                      ),
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

  Widget _buildRoleTab(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : context.ct.textTertiary),
              const SizedBox(width: Spacing.sm),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.ct.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
