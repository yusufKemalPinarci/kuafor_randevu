import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';

class BarberBlockTimePage extends StatefulWidget {
  const BarberBlockTimePage({super.key});

  @override
  State<BarberBlockTimePage> createState() => _BarberBlockTimePageState();
}

class _BarberBlockTimePageState extends State<BarberBlockTimePage> {
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlocks();
  }

  String? get _token =>
      Provider.of<UserProvider>(context, listen: false).user?.jwtToken;

  Future<void> _fetchBlocks() async {
    final token = _token;
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDay.toIso8601String().substring(0, 10);
      final response = await ApiClient().get('/api/appointment/block?date=$dateStr');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => _blocks = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteBlock(String id) async {
    final token = _token;
    if (token == null) return;

    try {
      final response = await ApiClient().delete('/api/appointment/block/$id');
      if (response.statusCode == 200) {
        showAppSnackBar(context, 'Bloke saat silindi');
        _fetchBlocks();
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Meşgul saat silinemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'Bağlantı hatası oluştu. Lütfen tekrar deneyin.', isError: true);
    }
  }

  Future<void> _showAddBlockDialog() async {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: context.ct.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl)),
            title: Text('Meşgul Saat Ekle',
                style: TextStyle(
                    color: context.ct.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tarih gösterimi
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: context.ct.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        '${_selectedDay.day.toString().padLeft(2, '0')}.${_selectedDay.month.toString().padLeft(2, '0')}.${_selectedDay.year}',
                        style: TextStyle(
                            color: context.ct.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                // Start Time
                _buildTimePickerTile(
                  label: 'Başlangıç',
                  time: startTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                      builder: (ctx, child) => MediaQuery(
                        data: MediaQuery.of(ctx)
                            .copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setStateDialog(() => startTime = picked);
                    }
                  },
                ),
                const SizedBox(height: Spacing.sm),
                // End Time
                _buildTimePickerTile(
                  label: 'Bitiş',
                  time: endTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 18, minute: 0),
                      builder: (ctx, child) => MediaQuery(
                        data: MediaQuery.of(ctx)
                            .copyWith(alwaysUse24HourFormat: true),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setStateDialog(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: Spacing.lg),
                // Reason
                TextField(
                  controller: reasonController,
                  style: TextStyle(
                      color: context.ct.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Sebep (opsiyonel)',
                    prefixIcon:
                        Icon(Icons.note_alt_outlined, color: AppColors.primary),
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
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () {
                        if (startTime == null || endTime == null) {
                          showAppSnackBar(context, 'Lütfen saat aralığı seçin',
                              isError: true);
                          return;
                        }
                        final startMin =
                            startTime!.hour * 60 + startTime!.minute;
                        final endMin = endTime!.hour * 60 + endTime!.minute;
                        if (endMin <= startMin) {
                          showAppSnackBar(
                              context, 'Bitiş saati başlangıçtan büyük olmalı',
                              isError: true);
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md)),
                      ),
                      child: const Text('Kaydet',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    if (result == true && startTime != null && endTime != null) {
      await _createBlock(
        startTime: startTime!,
        endTime: endTime!,
        reason: reasonController.text.trim(),
      );
    }
    reasonController.dispose();
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.ct.surfaceLight,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.ct.surfaceBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.primary, size: 20),
              const SizedBox(width: Spacing.md),
              Text(label,
                  style: TextStyle(
                      color: context.ct.textSecondary, fontSize: 14)),
              const Spacer(),
              Text(
                time != null
                    ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                    : 'Seçin',
                style: TextStyle(
                  color: time != null
                      ? context.ct.textPrimary
                      : context.ct.textHint,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBlock({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String reason,
  }) async {
    final token = _token;
    if (token == null) return;

    final dateStr = _selectedDay.toIso8601String().substring(0, 10);
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    try {
      final response = await ApiClient().post(
        '/api/appointment/block',
        body: jsonEncode({
          'date': dateStr,
          'startTime': startStr,
          'endTime': endStr,
          'reason': reason,
        }),
      );

      if (response.statusCode == 201) {
        showAppSnackBar(context, 'Meşgul saat eklendi');
        _fetchBlocks();
      } else {
        final err = jsonDecode(response.body);
        showAppSnackBar(context, err['error'] ?? 'Meşgul saat eklenemedi. Lütfen tekrar deneyin.', isError: true);
      }
    } catch (_) {
      showAppSnackBar(context, 'Bağlantı hatası oluştu. Lütfen tekrar deneyin.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Meşgul Saatler'),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: context.ct.surface,
                onRefresh: _fetchBlocks,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Container(
                        decoration: BoxDecoration(
                          color: context.ct.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                              color: context.ct.surfaceBorder.withAlpha(80)),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.now(),
                          lastDay:
                              DateTime.now().add(const Duration(days: 90)),
                          focusedDay: _selectedDay,
                          calendarFormat: CalendarFormat.week,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay),
                          onDaySelected: (sDay, fDay) {
                            setState(() => _selectedDay = sDay);
                            _fetchBlocks();
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleTextStyle: TextStyle(
                                color: context.ct.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            leftChevronIcon: Icon(Icons.chevron_left_rounded,
                                color: context.ct.textSecondary),
                            rightChevronIcon: Icon(
                                Icons.chevron_right_rounded,
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
                            defaultTextStyle: TextStyle(
                                color: context.ct.textPrimary),
                            weekendTextStyle: TextStyle(
                                color: context.ct.textSecondary),
                          ),
                        ),
                      ),

                      const SizedBox(height: Spacing.xxl),
                      AppSectionLabel(text: 'Bloke Edilen Saatler'),
                      const SizedBox(height: Spacing.md),

                      if (_isLoading)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(Spacing.xxl),
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ))
                      else if (_blocks.isEmpty)
                        AppEmptyState(
                          icon: Icons.event_available,
                          title: 'Bloke saat yok',
                          subtitle:
                              'Bu tarihte henüz meşgul saat eklenmemiş',
                        )
                      else
                        ..._blocks.map((block) => _buildBlockCard(block)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBlockDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.block),
        label: const Text('Meşgul Saat Ekle',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBlockCard(Map<String, dynamic> block) {
    final start = block['startTime'] ?? '';
    final end = block['endTime'] ?? '';
    final reason = block['reason'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.error.withAlpha(40)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.ct.errorSoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Center(
                  child: Icon(Icons.block, color: AppColors.error, size: 24),
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$start — $end',
                        style: TextStyle(
                            color: context.ct.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(reason,
                          style: TextStyle(
                              color: context.ct.textSecondary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showDeleteConfirmation(block['_id']),
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text('Bloke Saati Sil',
            style: TextStyle(
                color: context.ct.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Bu bloke saati silmek istediğinize emin misiniz? Müşteriler bu saatlerde randevu alabilecek.',
          style: TextStyle(color: context.ct.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal',
                style: TextStyle(color: context.ct.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteBlock(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
