import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../services/firebase_phone_auth_service.dart';

class GuestBookingPage extends StatefulWidget {
  final String barberId;
  final String barberName;
  final String shopName;

  const GuestBookingPage({
    super.key,
    required this.barberId,
    required this.barberName,
    required this.shopName,
  });

  @override
  State<GuestBookingPage> createState() => _GuestBookingPageState();
}

class _GuestBookingPageState extends State<GuestBookingPage> {
  DateTime _selectedDay = DateTime.now();
  
  List<dynamic> _services = [];
  String? _selectedServiceId;
  
  List<dynamic> _availableSlots = [];
  String? _selectedTime;
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoadingServices = true;
  bool _isLoadingSlots = false;
  bool _isReserving = false;

  final _phoneAuthService = FirebasePhoneAuthService();

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/service/${widget.barberId}/services'));
      if (response.statusCode == 200) {
        setState(() {
          _services = jsonDecode(response.body);
          _isLoadingServices = false;
        });
      } else {
        throw Exception("Hizmet listesi yüklenemedi.");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _fetchAvailableTimeSlots() async {
    if (_selectedServiceId == null) return;
    
    setState(() {
      _isLoadingSlots = true;
      _selectedTime = null;
      _availableSlots = [];
    });

    try {
      final dateStr = _selectedDay.toIso8601String().substring(0, 10);
      final url = Uri.parse('${AppConstants.baseUrl}/api/appointment/musaitberber?barberId=${widget.barberId}&date=$dateStr&serviceId=$_selectedServiceId');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _availableSlots = jsonDecode(response.body);
          _isLoadingSlots = false;
        });
      } else {
        throw Exception("Uygun saatler yüklenemedi.");
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Uygun saatler yüklenemedi. Lütfen tekrar deneyin.', isError: true);
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  Future<void> _requestAppointment() async {
    if (_selectedServiceId == null || _selectedTime == null) {
      showAppSnackBar(context, 'Lütfen servis ve saat seçin.', isError: true);
      return;
    }
    
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Lütfen iletişim bilgilerinizi eksiksiz girin.', isError: true);
      return;
    }

    // Telefon numarasını +90 formatına çevir
    String phone = _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('+')) phone = '+90$phone';

    if (phone.length < 12) {
      showAppSnackBar(context, 'Geçerli bir telefon numarası girin.', isError: true);
      return;
    }

    setState(() => _isReserving = true);

    _phoneAuthService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        if (mounted) {
          setState(() => _isReserving = false);
          _showOtpDialog(phone);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isReserving = false);
          showAppSnackBar(context, error, isError: true);
        }
      },
      onAutoVerified: (credential) async {
        // Android auto-retrieve ile otomatik doğrulama
        try {
          await _phoneAuthService.signInWithCredential(credential);
          if (mounted) {
            setState(() => _isReserving = false);
            await _createConfirmedAppointment(phone);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isReserving = false);
            showAppSnackBar(context, 'Otomatik doğrulama başarısız oldu. Lütfen kodu manuel olarak girin.', isError: true);
          }
        }
      },
    );
  }

  /// Firebase doğrulaması başarılı olduktan sonra randevuyu direkt "confirmed" olarak kaydeder.
  Future<void> _createConfirmedAppointment(String phone) async {
    try {
      // Firebase doğrulanmış kullanıcıdan ID token al
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        if (mounted) showAppSnackBar(context, 'Telefon doğrulaması başarısız. Lütfen tekrar deneyin.', isError: true);
        return;
      }

      final dateStr = _selectedDay.toIso8601String().substring(0, 10);
      final email = _emailController.text.trim();
      final payload = {
        'barberId': widget.barberId,
        'serviceId': _selectedServiceId,
        'date': dateStr,
        'startTime': _selectedTime,
        'customerName': _nameController.text.trim(),
        'customerPhone': phone,
        if (email.isNotEmpty) 'customerEmail': email,
      };

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/appointment/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );

      // Firebase guest oturumunu kapat
      await _phoneAuthService.signOut();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final appointmentId = data['appointment']?['_id'] ?? '';
        if (mounted) _showSuccessScreen(appointmentId);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Randevu oluşturulamadı. Lütfen tekrar deneyin.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Randevu oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.', isError: true);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
              title: Text('Doğrulama Kodu', style: TextStyle(color: context.ct.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$phone numarasına gönderilen 6 haneli kodu girin.',
                    style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: Spacing.xl),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(color: context.ct.textPrimary, fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '······',
                      hintStyle: TextStyle(color: context.ct.textHint, letterSpacing: 6),
                      contentPadding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isVerifying ? null : () {
                          _phoneAuthService.signOut();
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.ct.textSecondary,
                          side: BorderSide(color: context.ct.surfaceBorder),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : () async {
                          final code = otpController.text.trim();
                          if (code.length != 6) return;
                          setStateDialog(() => isVerifying = true);
                          
                          try {
                            await _phoneAuthService.verifyOtp(code);
                            // Firebase doğrulaması başarılı — randevuyu kaydet
                            if (mounted) {
                              Navigator.pop(ctx);
                              await _createConfirmedAppointment(phone);
                            }
                          } on FirebaseAuthException catch (e) {
                            String msg;
                            switch (e.code) {
                              case 'invalid-verification-code':
                                msg = 'Hatalı doğrulama kodu.';
                                break;
                              case 'session-expired':
                                msg = 'Kodun süresi doldu. Tekrar deneyin.';
                                break;
                              default:
                                msg = e.message ?? 'Doğrulama başarısız.';
                            }
                            if (mounted) showAppSnackBar(context, msg, isError: true);
                          } catch (e) {
                            if (mounted) showAppSnackBar(context, 'Doğrulama sırasında bir sorun oluştu. Lütfen tekrar deneyin.', isError: true);
                          } finally {
                            setStateDialog(() => isVerifying = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: isVerifying
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Onayla', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        );
      }
    );
  }
  
  void _showSuccessScreen(String appointmentId) {
    // Seçilen hizmet adını bul
    final selectedService = _services.firstWhere(
      (s) => s['_id'] == _selectedServiceId,
      orElse: () => null,
    );
    final serviceName = selectedService?['title'] ?? '';
    final dateStr = '${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.year}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        contentPadding: const EdgeInsets.all(Spacing.xxxl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.ct.successSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success.withAlpha(30)),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 44),
            ),
            const SizedBox(height: Spacing.xxl),
            Text('Randevunuz Onaylandı!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xl),

            // Randevu detayları
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: context.ct.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
              ),
              child: Column(
                children: [
                  _detailRow(ctx, Icons.calendar_today_rounded, dateStr),
                  const SizedBox(height: Spacing.md),
                  _detailRow(ctx, Icons.access_time_rounded, _selectedTime ?? ''),
                  const SizedBox(height: Spacing.md),
                  _detailRow(ctx, Icons.content_cut_rounded, serviceName),
                  const SizedBox(height: Spacing.md),
                  _detailRow(ctx, Icons.person_outline_rounded, widget.barberName),
                  const SizedBox(height: Spacing.md),
                  _detailRow(ctx, Icons.store_rounded, widget.shopName),
                ],
              ),
            ),

            if (appointmentId.isNotEmpty) ...[
              const SizedBox(height: Spacing.xl),
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: context.ct.warningSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.primary.withAlpha(30)),
                ),
                child: Column(
                  children: [
                    Text('Randevu Referansı', style: TextStyle(color: context.ct.textTertiary, fontSize: 12)),
                    const SizedBox(height: Spacing.xs),
                    SelectableText(
                      appointmentId.length > 8 ? appointmentId.substring(appointmentId.length - 8).toUpperCase() : appointmentId.toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 3),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Spacing.sm),
            Text('Randevunuzu "Randevumu Sorgula" bölümünden takip edebilirsiniz.',
                style: TextStyle(color: context.ct.textTertiary, fontSize: 12, height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xxl),
            AppLoadingButton(
              label: 'Ana Sayfaya Dön',
              icon: Icons.home_rounded,
              onPressed: () => Navigator.of(ctx).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      )
    );
  }

  Widget _detailRow(BuildContext ctx, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: Spacing.md),
        Expanded(child: Text(text, style: TextStyle(color: ctx.ct.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildStepLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: widget.barberName),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.shopName, style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.xxl),
                    
                    // ── 1. Service Selection ──
                    _buildStepLabel('1. Hizmet Seçin'),
                    _isLoadingServices
                        ? const Center(child: CircularProgressIndicator())
                        : _services.isEmpty
                            ? const Text('Bu berber henüz servis eklememiş.', style: TextStyle(color: AppColors.error, fontSize: 14))
                            : DropdownButtonFormField<String>(
                                value: _selectedServiceId,
                                dropdownColor: context.ct.surface,
                                style: TextStyle(color: context.ct.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Lütfen bir hizmet seçin',
                                ),
                                items: _services.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s['_id'],
                                    child: Text('${s['title']} - ${s['durationMinutes']} Dk (₺${s['price']})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedServiceId = val);
                                  _fetchAvailableTimeSlots();
                                },
                              ),
                          
                    const SizedBox(height: Spacing.xxxl),
                    
                    // ── 2. Date Selection ──
                    _buildStepLabel('2. Tarih Seçin'),
                    Container(
                      decoration: BoxDecoration(
                        color: context.ct.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 30)),
                        focusedDay: _selectedDay,
                        calendarFormat: CalendarFormat.week,
                        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                        onDaySelected: (sDay, fDay) {
                          setState(() => _selectedDay = sDay);
                          _fetchAvailableTimeSlots();
                        },
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: context.ct.textSecondary),
                          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: context.ct.textSecondary),
                          headerPadding: EdgeInsets.symmetric(vertical: Spacing.md),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                          weekendStyle: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(color: AppColors.primary.withAlpha(40), shape: BoxShape.circle),
                          todayTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          defaultTextStyle: TextStyle(color: context.ct.textPrimary),
                          weekendTextStyle: TextStyle(color: context.ct.textSecondary),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: Spacing.xxxl),
                    
                    // ── 3. Time Selection ──
                    _buildStepLabel('3. Saat Seçin'),
                    if (_selectedServiceId == null)
                      Text('Lütfen önce bir hizmet seçin.', style: TextStyle(color: context.ct.textSecondary, fontSize: 14)),
                    if (_selectedServiceId != null && _isLoadingSlots)
                      const Center(child: Padding(padding: EdgeInsets.all(Spacing.xl), child: CircularProgressIndicator())),
                    if (_selectedServiceId != null && !_isLoadingSlots && _availableSlots.isEmpty)
                      const Text('Bu tarihte uygun saat bulunmuyor.', style: TextStyle(color: AppColors.error, fontSize: 14)),
                    if (_selectedServiceId != null && !_isLoadingSlots && _availableSlots.isNotEmpty)
                      Wrap(
                        spacing: Spacing.sm,
                        runSpacing: Spacing.sm,
                        children: _availableSlots.map((slot) {
                          final time = slot['time'];
                          final isAvailable = slot['available'];
                          final isSelected = _selectedTime == time;

                          return Material(
                            color: isSelected
                                ? AppColors.primary
                                : (isAvailable ? context.ct.surface : context.ct.bg),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              onTap: isAvailable ? () => setState(() => _selectedTime = time) : null,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isAvailable ? context.ct.surfaceBorder : context.ct.surfaceBorder.withAlpha(40)),
                                  ),
                                ),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    color: isAvailable ? (isSelected ? Colors.white : context.ct.textPrimary) : context.ct.textHint,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                       
                    const SizedBox(height: Spacing.xxxl),
                    
                    // ── 4. Contact Info ──
                    _buildStepLabel('4. İletişim Bilgileriniz'),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Telefon Numaranız',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'E-posta (opsiyonel)',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                      ),
                    ),
                    
                    const SizedBox(height: Spacing.huge),
                    
                    AppLoadingButton(
                      label: 'Doğrula ve Randevu Al',
                      icon: Icons.verified_rounded,
                      isLoading: _isReserving,
                      onPressed: _requestAppointment,
                    ),
                    const SizedBox(height: Spacing.huge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
