import 'package:flutter/material.dart';
import 'package:kuafor_randevu/pages/appointment_detail_page.dart';
import 'package:table_calendar/table_calendar.dart';

class AllAppointmentsPage extends StatefulWidget {
  const AllAppointmentsPage({super.key});

  @override
  State<AllAppointmentsPage> createState() => _AllAppointmentsPageState();
}

class _AllAppointmentsPageState extends State<AllAppointmentsPage> {
  DateTime _selectedDay = DateTime.now();

  // Örnek randevular - tarih string olarak yyyy-MM-dd formatında
  final Map<String, List<Map<String, String>>> _appointments = {
    '2025-08-05': [
      {'customer': 'Ahmet Yılmaz', 'time': '10:00'},
      {'customer': 'Mehmet Kaya', 'time': '11:30'},
    ],
    '2025-08-06': [
      {'customer': 'Ayşe Demir', 'time': '14:00'},
    ],
  };

  List<Map<String, String>> get _selectedDayAppointments {
    final key = _selectedDay.toIso8601String().substring(0, 10);
    return _appointments[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: const Text('Tüm Randevular'),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _selectedDay,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Color(0xFFC69749),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFFC69749),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: Colors.white),
              selectedTextStyle: TextStyle(color: Colors.white),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
            selectedDayPredicate: (day) {
              return isSameDay(day, _selectedDay);
            },
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                final text = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'][day.weekday % 7];
                return Center(
                  child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                );
              },
            ),
            daysOfWeekHeight: 30,
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.white70),
            ),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.all,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _selectedDayAppointments.isEmpty
                ? const Center(
              child: Text(
                'Seçilen gün için randevu yok',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _selectedDayAppointments.length,
              itemBuilder: (context, index) {
                final appt = _selectedDayAppointments[index];
                return Card(
                  color: const Color(0xFF2C2C2C),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    title: Text(
                      appt['customer']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      appt['time']!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppointmentDetailPage(
                            appointment: {
                              'customer': appt['customer'],
                              'date': '2025-08-05', // uygun şekilde gün/datalar
                              'time': appt['time'],
                            },
                          ),
                        ),
                      );

                      // Randevu detay sayfasına git
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
