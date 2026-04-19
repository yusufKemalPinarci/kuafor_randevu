import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';

class BarberManualAppointmentPage extends StatefulWidget {
  const BarberManualAppointmentPage({super.key});

  @override
  State<BarberManualAppointmentPage> createState() =>
      _BarberManualAppointmentPageState();
}

class _BarberManualAppointmentPageState
    extends State<BarberManualAppointmentPage> {
  DateTime _selectedDay = DateTime.now();

  List<dynamic> _services = [];
  String? _selectedServiceId;

  List<dynamic> _availableSlots = [];
  String? _selectedTime;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoadingServices = true;
  bool _isLoadingSlots = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? get _barberId =>
      Provider.of<UserProvider>(context, listen: false).user?.id;

  Future<void> _fetchServices() async {
    final barberId = _barberId;
    if (barberId == null) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/service/$barberId/services'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _services = jsonDecode(response.body);
          _isLoadingServices = false;
        });
      } else {
        throw Exception('Hizmet listesi yüklenemedi.');
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _fetchAvailableSlots() async {
    if (_selectedServiceId == null) return;

    setState(() {
      _isLoadingSlots = true;
      _selectedTime = null;
      _availableSlots = [];
    });

    try {
      final dateStr = _selectedDay.toIso8601String().substring(0, 10);
      final url = Uri.parse(
          '${AppConstants.baseUrl}/api/appointment/musaitberber?barberId=$_barberId&date=$dateStr&serviceId=$_selectedServiceId');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _availableSlots = jsonDecode(response.body);
          _isLoadingSlots = false;
        });
      } else {
        throw Exception('Uygun saatler yüklenemedi.');
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Uygun saatler yüklenemedi. Lütfen tekrar deneyin.', isError: true);
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  Future<void> _createManualAppointment() async {
    if (_selectedServiceId == null || _selectedTime == null) {
      showAppSnackBar(context, 'Lütfen servis ve saat seçin', isError: true);
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Müşteri adı ve telefonu zorunludur',
          isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      final dateStr = _selectedDay.toIso8601String().substring(0, 10);
      final payload = {
        'serviceId': _selectedServiceId,
        'date': dateStr,
        'startTime': _selectedTime,
        'customerName': _nameController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
      };

      final response = await ApiClient().post(
        '/api/appointment/manual',
        body: payload,
      );

      if (response.statusCode == 201) {
        if (mounted) {
          showAppSnackBar(context, 'Randevu oluşturuldu');
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Randevu oluşturulamadı. Lütfen tekrar deneyin.');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
            context, 'Randevu oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Manuel Randevu Oluştur'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: context.ct.infoSoft,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.info.withAlpha(30)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.info, size: 20),
                          SizedBox(width: Spacing.md),
                          Expanded(
                            child: Text(
                              'Telefonla arayan müşteriler için randevu oluşturun. OTP doğrulaması gerekmez.',
                              style: TextStyle(
                                  color: context.ct.textSecondary,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),

                    // 1. Service
                    _buildStepLabel('1. Hizmet Seçin'),
                    _isLoadingServices
                        ? const Center(child: CircularProgressIndicator())
                        : _services.isEmpty
                            ? const Text('Henüz servis eklenmemiş.',
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 14))
                            : DropdownButtonFormField<String>(
                                value: _selectedServiceId,
                                dropdownColor: context.ct.surface,
                                style: TextStyle(
                                    color: context.ct.textPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Bir hizmet seçin',
                                ),
                                items: _services.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s['_id'],
                                    child: Text(
                                        '${s['title']} - ${s['durationMinutes']} Dk (₺${s['price']})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedServiceId = val);
                                  _fetchAvailableSlots();
                                },
                              ),
                    const SizedBox(height: Spacing.xxxl),

                    // 2. Date
                    _buildStepLabel('2. Tarih Seçin'),
                    Container(
                      decoration: BoxDecoration(
                        color: context.ct.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                            color: context.ct.surfaceBorder.withAlpha(80)),
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay:
                            DateTime.now().add(const Duration(days: 60)),
                        focusedDay: _selectedDay,
                        calendarFormat: CalendarFormat.week,
                        selectedDayPredicate: (day) =>
                            isSameDay(day, _selectedDay),
                        onDaySelected: (sDay, fDay) {
                          setState(() => _selectedDay = sDay);
                          _fetchAvailableSlots();
                        },
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleTextStyle: TextStyle(
                              color: context.ct.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          leftChevronIcon: Icon(Icons.chevron_left_rounded,
                              color: context.ct.textSecondary),
                          rightChevronIcon: Icon(Icons.chevron_right_rounded,
                              color: context.ct.textSecondary),
                          headerPadding:
                              EdgeInsets.symmetric(vertical: Spacing.md),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                              color: context.ct.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          weekendStyle: TextStyle(
                              color: context.ct.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(40),
                              shape: BoxShape.circle),
                          todayTextStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                          selectedDecoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle),
                          selectedTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                          defaultTextStyle:
                              TextStyle(color: context.ct.textPrimary),
                          weekendTextStyle:
                              TextStyle(color: context.ct.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxxl),

                    // 3. Time
                    _buildStepLabel('3. Saat Seçin'),
                    if (_selectedServiceId == null)
                      Text('Lütfen önce bir hizmet seçin.',
                          style: TextStyle(
                              color: context.ct.textSecondary, fontSize: 14)),
                    if (_selectedServiceId != null && _isLoadingSlots)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(Spacing.xl),
                              child: CircularProgressIndicator())),
                    if (_selectedServiceId != null &&
                        !_isLoadingSlots &&
                        _availableSlots.isEmpty)
                      const Text('Bu tarihte uygun saat bulunmuyor.',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 14)),
                    if (_selectedServiceId != null &&
                        !_isLoadingSlots &&
                        _availableSlots.isNotEmpty)
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
                                : (isAvailable
                                    ? context.ct.surface
                                    : context.ct.bg),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              onTap: isAvailable
                                  ? () =>
                                      setState(() => _selectedTime = time)
                                  : null,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.xl,
                                    vertical: Spacing.md),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isAvailable
                                            ? context.ct.surfaceBorder
                                            : context.ct.surfaceBorder
                                                .withAlpha(40)),
                                  ),
                                ),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    color: isAvailable
                                        ? (isSelected
                                            ? Colors.white
                                            : context.ct.textPrimary)
                                        : context.ct.textHint,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: Spacing.xxxl),

                    // 4. Customer Info
                    _buildStepLabel('4. Müşteri Bilgileri'),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                          color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Müşteri Adı',
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                          color: context.ct.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Müşteri Telefonu',
                        prefixIcon: Icon(Icons.phone_outlined,
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: Spacing.huge),

                    // Submit
                    AppLoadingButton(
                      label: 'Randevu Oluştur',
                      icon: Icons.event_available_rounded,
                      isLoading: _isCreating,
                      onPressed: _createManualAppointment,
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

  Widget _buildStepLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
