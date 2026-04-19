import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/shop_provider.dart';
import '../services/api_client.dart';

class WorkingDaysPage extends StatefulWidget {
  const WorkingDaysPage({super.key});

  @override
  State<WorkingDaysPage> createState() => _WorkingDaysPageState();
}

class _WorkingDaysPageState extends State<WorkingDaysPage> {
  final List<String> _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  final Map<String, bool> _selectedDays = {};
  final Map<String, List<TimeOfDayRange>> _timeRanges = {};
  bool _isSaving = false;
  bool _isLoading = true;

  int _dayToNumber(String day) {
    const map = {'Pazar': 0, 'Pazartesi': 1, 'Salı': 2, 'Çarşamba': 3, 'Perşembe': 4, 'Cuma': 5, 'Cumartesi': 6};
    return map[day] ?? 0;
  }

  String _numberToDay(int num) {
    const map = {0: 'Pazar', 1: 'Pazartesi', 2: 'Salı', 3: 'Çarşamba', 4: 'Perşembe', 5: 'Cuma', 6: 'Cumartesi'};
    return map[num] ?? 'Pazartesi';
  }

  @override
  void initState() {
    super.initState();
    for (var day in _days) {
      _selectedDays[day] = false;
      _timeRanges[day] = [];
    }
    _loadExistingAvailability();
  }

  Future<void> _loadExistingAvailability() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      if (user == null || user.jwtToken == null) return;

      final response = await ApiClient().get('/api/user/${user.id}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final availability = data['availability'] as List<dynamic>? ?? [];

        for (var entry in availability) {
          final dayOfWeek = entry['dayOfWeek'] as int;
          final dayName = _numberToDay(dayOfWeek);
          final timeRanges = entry['timeRanges'] as List<dynamic>? ?? [];

          if (timeRanges.isNotEmpty) {
            _selectedDays[dayName] = true;
            _timeRanges[dayName] = timeRanges.map((tr) {
              final startParts = (tr['startTime'] as String).split(':');
              final endParts = (tr['endTime'] as String).split(':');
              return TimeOfDayRange(
                TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
                TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
              );
            }).toList();
          }
        }
      }
    } catch (_) {
      // Mevcut müsaitlik yüklenemezse varsayılan boş değerlerle devam et
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _addTimeRange(String day) async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null) return;
    if (!mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: 0),
    );
    if (end == null) return;

    // Bitiş saati başlangıçtan büyük olmalı
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) {
      if (mounted) {
        showAppSnackBar(context, 'Bitiş saati başlangıç saatinden sonra olmalıdır.', isError: true);
      }
      return;
    }

    setState(() {
      _timeRanges[day]!.add(TimeOfDayRange(start, end));
    });
  }

  void _removeTimeRange(String day, int index) {
    setState(() {
      _timeRanges[day]!.removeAt(index);
    });
  }

  TimeOfDayRange _shopDefaultRange() {
    final shop = Provider.of<ShopProvider>(context, listen: false).shop;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);
    if (shop != null) {
      final oParts = shop.openingHour.split(':');
      final cParts = shop.closingHour.split(':');
      if (oParts.length == 2 && cParts.length == 2) {
        start = TimeOfDay(hour: int.tryParse(oParts[0]) ?? 9, minute: int.tryParse(oParts[1]) ?? 0);
        end = TimeOfDay(hour: int.tryParse(cParts[0]) ?? 18, minute: int.tryParse(cParts[1]) ?? 0);
      }
    }
    return TimeOfDayRange(start, end);
  }

  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      if (user == null) return;

      final List<Map<String, dynamic>> availability = [];
      for (var day in _days) {
        if (_selectedDays[day] == true && (_timeRanges[day]?.isNotEmpty ?? false)) {
          availability.add({
            'dayOfWeek': _dayToNumber(day),
            'timeRanges': _timeRanges[day]!.map((range) => {
              'startTime': '${range.start.hour.toString().padLeft(2, '0')}:${range.start.minute.toString().padLeft(2, '0')}',
              'endTime': '${range.end.hour.toString().padLeft(2, '0')}:${range.end.minute.toString().padLeft(2, '0')}',
            }).toList(),
          });
        }
      }

      final response = await ApiClient().put(
        '/api/user/barber/availability/${user.id}',
        body: {'availability': availability},
      );

      if (response.statusCode == 200) {
        if (mounted) showAppSnackBar(context, 'Çalışma saatleri başarıyla kaydedildi.');
      } else {
        throw Exception('Çalışma saatleri kaydedilemedi.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Çalışma saatleri kaydedilemedi. Lütfen tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Çalışma Saatleri',
              trailing: _isSaving
                  ? const SizedBox(width: 40, height: 40, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))))
                  : Material(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: _saveAvailability,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.check_rounded, color: AppColors.primary, size: 22),
                        ),
                      ),
                    ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxxl),
                      itemCount: _days.length,
                      itemBuilder: (context, index) {
                        final day = _days[index];
                        final selected = _selectedDays[day] ?? false;
                        final ranges = _timeRanges[day] ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: Spacing.md),
                          decoration: BoxDecoration(
                            color: context.ct.surface,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: selected ? AppColors.primary.withAlpha(40) : context.ct.surfaceBorder.withAlpha(80),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: selected,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        side: BorderSide(color: context.ct.surfaceBorder, width: 1.5),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedDays[day] = val!;
                                            if (val && (_timeRanges[day]?.isEmpty ?? true)) {
                                              _timeRanges[day] = [_shopDefaultRange()];
                                            }
                                            if (!val) {
                                              _timeRanges[day] = [];
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.md),
                                    Expanded(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color: selected ? context.ct.textPrimary : context.ct.textTertiary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Material(
                                        color: AppColors.primary.withAlpha(15),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                        child: InkWell(
                                          onTap: () => _addTimeRange(day),
                                          borderRadius: BorderRadius.circular(AppRadius.sm),
                                          child: const Padding(
                                            padding: EdgeInsets.all(Spacing.sm),
                                            child: Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (selected && ranges.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: Spacing.md),
                                    child: Column(
                                      children: ranges.asMap().entries.map((entry) {
                                        final i = entry.key;
                                        final range = entry.value;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: Spacing.sm),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                                            decoration: BoxDecoration(
                                              color: context.ct.surfaceLight,
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 16),
                                                const SizedBox(width: Spacing.sm),
                                                Text(
                                                  '${range.start.format(context)} - ${range.end.format(context)}',
                                                  style: TextStyle(color: context.ct.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                                                ),
                                                const Spacer(),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: () => _removeTimeRange(day, i),
                                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                                    child: const Padding(
                                                      padding: EdgeInsets.all(4),
                                                      child: Icon(Icons.close_rounded, color: AppColors.error, size: 16),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
