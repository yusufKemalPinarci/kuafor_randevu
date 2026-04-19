import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kuaflex/pages/appointment_detail_page.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../providers/user_provider.dart';
import '../services/api_client.dart';

class AllAppointmentsPage extends StatefulWidget {
  const AllAppointmentsPage({super.key});

  @override
  State<AllAppointmentsPage> createState() => _AllAppointmentsPageState();
}

class _AllAppointmentsPageState extends State<AllAppointmentsPage> {
  DateTime _selectedDay = DateTime.now();

  Map<String, List<Map<String, dynamic>>> _appointments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.user?.jwtToken;
      if (token == null) return;

      final response = await ApiClient().get('/api/appointment/my_berber');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        final Map<String, List<Map<String, dynamic>>> groupedAppointments = {};

        for (var appt in data) {
          final dateStr = appt['date'];
          if (dateStr == null) continue;

          String formattedTime = '';
          if (appt['startTime'] != null) {
            final startTime = DateTime.parse(appt['startTime']).toLocal();
            formattedTime = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
          }

          final mappedAppt = {
            'id': appt['_id'],
            'customer': appt['customerName'] ?? 'Bilinmeyen Müşteri',
            'time': formattedTime,
            'phone': appt['customerPhone'] ?? '-',
            'date': dateStr,
            'status': appt['status'] ?? 'pending',
            'notes': appt['notes'] ?? '',
          };

          if (groupedAppointments.containsKey(dateStr)) {
            groupedAppointments[dateStr]!.add(mappedAppt);
          } else {
            groupedAppointments[dateStr] = [mappedAppt];
          }
        }

        setState(() => _appointments = groupedAppointments);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Tüm randevuları çekerken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _selectedDayAppointments {
    final key = _selectedDay.toIso8601String().substring(0, 10);
    return _appointments[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: 'Tüm Randevular'),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              // ── Calendar ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                decoration: BoxDecoration(
                  color: context.ct.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
                ),
                child: TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _selectedDay,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    defaultTextStyle: TextStyle(color: context.ct.textPrimary),
                    weekendTextStyle: TextStyle(color: context.ct.textSecondary),
                    outsideTextStyle: TextStyle(color: context.ct.textHint),
                    cellMargin: const EdgeInsets.all(3),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: context.ct.textSecondary),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: context.ct.textSecondary),
                    headerPadding: EdgeInsets.symmetric(vertical: Spacing.md),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() => _selectedDay = selectedDay);
                  },
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final text = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'][day.weekday % 7];
                      return Center(
                        child: Text(text, style: TextStyle(color: context.ct.textTertiary, fontWeight: FontWeight.w600, fontSize: 12)),
                      );
                    },
                  ),
                  daysOfWeekHeight: 30,
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: context.ct.textTertiary),
                    weekendStyle: TextStyle(color: context.ct.textTertiary),
                  ),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableGestures: AvailableGestures.all,
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // ── Appointment List ──
              Expanded(
                child: _selectedDayAppointments.isEmpty
                    ? AppEmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'Seçilen gün için randevu yok',
                        subtitle: 'Takvimden başka bir gün seçebilirsiniz',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                        itemCount: _selectedDayAppointments.length,
                        itemBuilder: (context, index) {
                          final appt = _selectedDayAppointments[index];
                          return _buildAppointmentCard(appt);
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailPage(
                  appointment: {
                    'id': appt['id'],
                    'customer': appt['customer'],
                    'date': appt['date'] ?? _selectedDay.toIso8601String().substring(0, 10),
                    'time': appt['time'],
                    'phone': appt['phone'] ?? '-',
                    'status': appt['status'] ?? 'pending',
                    'notes': appt['notes'] ?? '',
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
            ),
            child: Row(
              children: [
                AppAvatar(letter: appt['customer'] ?? '?', size: 44, withShadow: false),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt['customer'] ?? '',
                        style: TextStyle(color: context.ct.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: context.ct.textTertiary, size: 14),
                          const SizedBox(width: Spacing.xs),
                          Text(appt['time'] ?? '', style: TextStyle(color: context.ct.textSecondary, fontSize: 13)),
                          const SizedBox(width: Spacing.md),
                          AppStatusBadge(status: appt['status'] ?? 'pending'),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: context.ct.textHint, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
