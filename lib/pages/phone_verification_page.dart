import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';
import '../services/firebase_phone_auth_service.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneAuthService = FirebasePhoneAuthService();

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  String _formattedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    String phone = _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+')) phone = '+90$phone';

    if (phone.length < 12) {
      showAppSnackBar(context, 'Geçerli bir telefon numarası girin.', isError: true);
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _formattedPhone = phone;
    });

    await _phoneAuthService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        if (mounted) {
          setState(() {
            _isSendingOtp = false;
            _codeSent = true;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isSendingOtp = false);
          showAppSnackBar(context, error, isError: true);
        }
      },
      onAutoVerified: (credential) async {
        try {
          await _phoneAuthService.signInWithCredential(credential);
          if (mounted) {
            setState(() => _isSendingOtp = false);
            await _onVerificationSuccess();
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isSendingOtp = false);
            showAppSnackBar(context, 'Otomatik doğrulama başarısız.', isError: true);
          }
        }
      },
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      showAppSnackBar(context, 'Lütfen 6 haneli doğrulama kodunu girin.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _phoneAuthService.verifyOtp(code);
      if (mounted) await _onVerificationSuccess();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'invalid-verification-code':
          msg = 'Hatalı doğrulama kodu.';
          break;
        case 'session-expired':
          msg = 'Kodun süresi doldu. Tekrar gönderin.';
          break;
        default:
          msg = e.message ?? 'Doğrulama başarısız.';
      }
      showAppSnackBar(context, msg, isError: true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Doğrulama hatası oluştu.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _onVerificationSuccess() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user != null) {
      final updatedUser = user.copyWith(
        phone: _formattedPhone,
        isPhoneVerified: true,
      );
      userProvider.saveUserToLocalAndProvider(updatedUser);

      try {
        await ApiClient().put(
          '/api/user/${user.id}/phone',
          body: {'phone': _formattedPhone},
        );
      } catch (_) {}
    }

    await _phoneAuthService.signOut();

    if (!mounted) return;
    showAppSnackBar(context, 'Telefon başarıyla doğrulandı!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Telefon Doğrulama'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                child: _codeSent ? _buildCodeStep() : _buildPhoneStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        const SizedBox(height: Spacing.huge),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_android, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: Spacing.xxl),
        Text(
          'Telefon numaranızı girin.\nDoğrulama kodu SMS ile gönderilecek.',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xxxl),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.ct.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            hintText: '5XX XXX XX XX',
            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
            prefixText: '+90 ',
          ),
        ),
        const SizedBox(height: Spacing.xxxl),
        AppLoadingButton(
          label: 'Kod Gönder',
          icon: Icons.send_rounded,
          isLoading: _isSendingOtp,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        const SizedBox(height: Spacing.huge),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sms_outlined, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: Spacing.xxl),
        Text(
          '$_formattedPhone\nnumarasına gönderilen 6 haneli kodu girin.',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xxxl),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TextStyle(color: context.ct.textPrimary, fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(color: context.ct.textHint, letterSpacing: 8),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: Spacing.xl),
          ),
        ),
        const SizedBox(height: Spacing.xxxl),
        AppLoadingButton(
          label: 'Doğrula',
          icon: Icons.verified_outlined,
          isLoading: _isVerifying,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: Spacing.lg),
        TextButton(
          onPressed: _isSendingOtp ? null : () {
            setState(() {
              _codeSent = false;
              _codeController.clear();
            });
          },
          child: Text(
            'Numarayı Değiştir',
            style: TextStyle(color: context.ct.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
