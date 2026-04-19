import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../services/firebase_phone_auth_service.dart';

class GuestAppointmentLookupPage extends StatefulWidget {
  const GuestAppointmentLookupPage({super.key});

  @override
  State<GuestAppointmentLookupPage> createState() =>
      _GuestAppointmentLookupPageState();
}

class _GuestAppointmentLookupPageState
    extends State<GuestAppointmentLookupPage> {
  final _phoneController = TextEditingController();
  final _phoneAuthService = FirebasePhoneAuthService();

  bool _isSendingOtp = false;
  bool _isVerified = false;
  bool _isLoadingAppointments = false;
  List<dynamic> _appointments = [];
  String? _verifiedPhone;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    String phone = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+')) phone = '+90$phone';
    return phone;
  }

  Future<void> _sendOtp() async {
    final phone = _formatPhone(_phoneController.text);
    if (phone.length < 12) {
      showAppSnackBar(context, 'Geçerli bir telefon numarası girin.', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);

    _phoneAuthService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        if (mounted) {
          setState(() => _isSendingOtp = false);
          _showOtpDialog(phone);
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
            await _onPhoneVerified(phone);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isSendingOtp = false);
            showAppSnackBar(context, 'Otomatik doğrulama başarısız oldu. Lütfen kodu manuel olarak girin.', isError: true);
          }
        }
      },
    );
  }

  Future<void> _onPhoneVerified(String phone) async {
    await _phoneAuthService.signOut();
    setState(() {
      _isVerified = true;
      _verifiedPhone = phone;
    });
    await _fetchAppointments(phone);
  }

  Future<void> _fetchAppointments(String phone) async {
    setState(() => _isLoadingAppointments = true);
    try {
      final url = Uri.parse(
          '${AppConstants.baseUrl}/api/appointment/guest-lookup?phone=${Uri.encodeComponent(phone)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _appointments = jsonDecode(response.body);
          _isLoadingAppointments = false;
        });
      } else {
        throw Exception('Randevularınız yüklenemedi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAppointments = false);
        showAppSnackBar(context, 'Randevularınız yüklenemedi. Lütfen tekrar deneyin.', isError: true);
      }
    }
  }

  void _showOtpDialog(String phone) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: context.ct.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xxl)),
              title: Text('Doğrulama Kodu',
                  style: TextStyle(
                      color: context.ct.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$phone numarasına gönderilen 6 haneli kodu girin.',
                    style: TextStyle(
                        color: context.ct.textSecondary,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: Spacing.xl),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(
                        color: context.ct.textPrimary,
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '······',
                      hintStyle: TextStyle(
                          color: context.ct.textHint, letterSpacing: 6),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: Spacing.xl),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                  Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isVerifying
                            ? null
                            : () {
                                _phoneAuthService.signOut();
                                Navigator.pop(ctx);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.ct.textSecondary,
                          side: BorderSide(color: context.ct.surfaceBorder),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isVerifying
                            ? null
                            : () async {
                                final code = otpController.text.trim();
                                if (code.length != 6) return;
                                setStateDialog(() => isVerifying = true);

                                try {
                                  await _phoneAuthService.verifyOtp(code);
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    await _onPhoneVerified(phone);
                                  }
                                } on FirebaseAuthException catch (e) {
                                  String msg;
                                  switch (e.code) {
                                    case 'invalid-verification-code':
                                      msg = 'Hatalı doğrulama kodu.';
                                      break;
                                    case 'session-expired':
                                      msg =
                                          'Kodun süresi doldu. Tekrar deneyin.';
                                      break;
                                    default:
                                      msg = e.message ?? 'Doğrulama başarısız.';
                                  }
                                  if (mounted) {
                                    showAppSnackBar(context, msg,
                                        isError: true);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    showAppSnackBar(context,
                                        'Doğrulama hatası.',
                                        isError: true);
                                  }
                                } finally {
                                  setStateDialog(() => isVerifying = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('Onayla',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final d = DateTime.parse(timeStr);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'pending':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  String _statusText(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Onaylandı';
      case 'cancelled':
        return 'İptal';
      case 'pending':
        return 'Bekliyor';
      default:
        return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Randevumu Sorgula'),
            Expanded(
              child: _isVerified ? _buildAppointmentsList() : _buildPhoneInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        children: [
          const SizedBox(height: Spacing.huge),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.ct.warningSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: Spacing.xxl),
          Text(
            'Randevunuzu Sorgulayın',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Kayıt olmadan aldığınız randevuları görmek için telefon numaranızı doğrulayın.',
            style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xxxl),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Telefon Numaranız',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          AppLoadingButton(
            label: 'Doğrula ve Sorgula',
            icon: Icons.verified_rounded,
            isLoading: _isSendingOtp,
            onPressed: _sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_isLoadingAppointments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 64, color: context.ct.textHint),
              const SizedBox(height: Spacing.xl),
              Text(
                'Randevu bulunamadı',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '$_verifiedPhone numarasına ait misafir randevu bulunamadı.',
                style: TextStyle(
                    color: context.ct.textSecondary,
                    fontSize: 14,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final apt = _appointments[index];
        final status = apt['status'] as String?;
        final barber = apt['barberId'];
        final service = apt['serviceId'];

        return Container(
          margin: const EdgeInsets.only(bottom: Spacing.md),
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: context.ct.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: Tarih + Durum
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: context.ct.textTertiary),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        _formatDate(apt['date']),
                        style: TextStyle(
                            color: context.ct.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.xs),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _statusText(status),
                      style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

              // Saat
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '${_formatTime(apt['startTime'])} - ${_formatTime(apt['endTime'])}',
                    style: TextStyle(
                        color: context.ct.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),

              // Hizmet
              if (service != null)
                Row(
                  children: [
                    Icon(Icons.content_cut_rounded,
                        size: 16, color: context.ct.textTertiary),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        '${service['title'] ?? ''} — ₺${service['price'] ?? ''}',
                        style: TextStyle(
                            color: context.ct.textSecondary, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              if (service != null) const SizedBox(height: Spacing.md),

              // Berber
              if (barber != null)
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 16, color: context.ct.textTertiary),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      barber['name'] ?? '',
                      style: TextStyle(
                          color: context.ct.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
