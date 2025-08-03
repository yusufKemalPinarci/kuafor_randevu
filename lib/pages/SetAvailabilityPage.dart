import 'package:flutter/material.dart';

class SetAvailabilityPage extends StatefulWidget {
  const SetAvailabilityPage({super.key});

  @override
  State<SetAvailabilityPage> createState() => _SetAvailabilityPageState();
}

class _SetAvailabilityPageState extends State<SetAvailabilityPage> {
  final Map<String, Map<String, TimeOfDay?>> availability = {
    'Pazartesi': {'start': null, 'end': null},
    'Salı': {'start': null, 'end': null},
    'Çarşamba': {'start': null, 'end': null},
    'Perşembe': {'start': null, 'end': null},
    'Cuma': {'start': null, 'end': null},
    'Cumartesi': {'start': null, 'end': null},
    'Pazar': {'start': null, 'end': null},
  };

  Future<void> _selectTime(BuildContext context, String day, String type) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        availability[day]![type] = picked;
      });
    }
  }

  void _saveAvailability() {
    for (var entry in availability.entries) {
      final start = entry.value['start'];
      final end = entry.value['end'];

      if (start != null && end != null && start.hour < end.hour) {
        print("${entry.key}: ${start.format(context)} - ${end.format(context)}");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uygun saatler kaydedildi!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: const Text("Uygun Saatleri Ayarla"),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var day in availability.keys)
            Card(
              color: const Color(0xFF2C2C2C),
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeSelector(day, 'start', 'Başlangıç'),
                        _buildTimeSelector(day, 'end', 'Bitiş'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC69749),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String day, String type, String label) {
    final selectedTime = availability[day]![type];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: () => _selectTime(context, day, type),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B3B3B),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            selectedTime != null ? selectedTime.format(context) : 'Seç',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
