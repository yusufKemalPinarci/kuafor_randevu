import 'package:flutter/material.dart';

class WorkingDaysPage extends StatefulWidget {
  const WorkingDaysPage({super.key});

  @override
  State<WorkingDaysPage> createState() => _WorkingDaysPageState();
}

class _WorkingDaysPageState extends State<WorkingDaysPage> {
  final List<String> _days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  final Map<String, bool> _selectedDays = {};
  final Map<String, List<TimeOfDayRange>> _timeRanges = {};

  /*
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ⚠️ Bu değerleri sen normalde bir kullanıcı servisinden ya da Provider'dan alırsın
    final isEmailVerified = false; // buraya gerçek değer gelecek
    final isPhoneVerified = false; // buraya gerçek değer gelecek

    if (!isEmailVerified || !isPhoneVerified) {
      // Sayfa yüklendikten sonra yönlendirme yap
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/verification-required');
      });
    }
  }*/


  @override
  void initState() {
    super.initState();
    for (var day in _days) {
      _selectedDays[day] = false;
      _timeRanges[day] = [];
    }
  }

  void _addTimeRange(String day) async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: 0),
    );
    if (end == null) return;

    setState(() {
      _timeRanges[day]!.add(TimeOfDayRange(start, end));
    });
  }

  void _saveAvailability() {
    final result = {
      for (var day in _days)
        if (_selectedDays[day] == true) day: _timeRanges[day]
    };

    // API’ye gönderilebilir.
    print(result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çalışma saatleri kaydedildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Çalışma Günleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAvailability,
          )
        ],
      ),
      body: ListView.builder(
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final selected = _selectedDays[day] ?? false;
          final ranges = _timeRanges[day] ?? [];

          return Card(
            color: const Color(0xFF2C2C2C),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        activeColor: const Color(0xFFC69749),
                        onChanged: (val) {
                          setState(() {
                            _selectedDays[day] = val!;
                          });
                        },
                      ),
                      Text(
                        day,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const Spacer(),
                      if (selected)
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => _addTimeRange(day),
                        )
                    ],
                  ),
                  if (selected && ranges.isNotEmpty)
                    ...ranges.map((range) => Padding(
                      padding: const EdgeInsets.only(left: 40, top: 6),
                      child: Text(
                        "${range.start.format(context)} - ${range.end.format(context)}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange(this.start, this.end);
}
