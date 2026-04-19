import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../services/firebase_auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAppSnackBar(context, 'E-posta adresini girin.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final error = await FirebaseAuthService().sendPasswordResetEmail(email);
      if (!mounted) return;
      if (error != null) {
        showAppSnackBar(context, error, isError: true);
      } else {
        setState(() => _emailSent = true);
        _fadeController.forward(from: 0);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: context.ct.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                      Text(
                        _emailSent ? 'Şifre Sıfırlama E-postası Gönderildi' : 'Şifremi Unuttum',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        _emailSent
                            ? 'E-posta adresinize şifre sıfırlama bağlantısı gönderildi. Lütfen gelen kutunuzu kontrol edin.'
                            : 'Kayıtlı e-posta adresinizi girin. Size şifre sıfırlama bağlantısı gönderelim.',
                        style: TextStyle(fontSize: 14, color: context.ct.textTertiary),
                      ),
                      const SizedBox(height: Spacing.xxxl),

                      if (!_emailSent) ...[
                        // ── E-posta girişi ──
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined, size: 22),
                            hintText: 'Kayıtlı e-posta adresiniz',
                          ),
                        ),
                        const SizedBox(height: Spacing.xxxl),
                        AppLoadingButton(
                          label: 'Sıfırlama E-postası Gönder',
                          isLoading: _isLoading,
                          onPressed: _sendResetEmail,
                        ),
                      ] else ...[
                        // ── Başarılı mesajı ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(Spacing.xl),
                          decoration: BoxDecoration(
                            color: context.ct.successSoft,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.success.withAlpha(60)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.mark_email_read_outlined,
                                  color: AppColors.success, size: 48),
                              const SizedBox(height: Spacing.lg),
                              Text(
                                'E-posta adresinize şifre sıfırlama bağlantısı gönderildi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: context.ct.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                'E-postadaki bağlantıya tıklayarak yeni şifrenizi belirleyebilirsiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: context.ct.textTertiary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.lg)),
                            ),
                            child: const Text('Giriş Sayfasına Dön',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        Center(
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => setState(() {
                                      _emailSent = false;
                                      _fadeController.forward(from: 0);
                                    }),
                            child: const Text(
                              'Tekrar gönder',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.huge),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
