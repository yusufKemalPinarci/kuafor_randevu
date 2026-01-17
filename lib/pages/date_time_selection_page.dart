import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class DateTimeSelectionPage extends StatefulWidget {
  const DateTimeSelectionPage({super.key});

  @override
  State<DateTimeSelectionPage> createState() => _DateTimeSelectionPageState();
}

class _DateTimeSelectionPageState extends State<DateTimeSelectionPage> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _slots = [];
  bool _isLoading = false;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    // Fetch slots for today by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSlots();
    });
  }

  Future<void> _fetchSlots() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final barber = args['barber'] as UserModel;
    final service = args['service'];

    setState(() {
      _isLoading = true;
      _selectedTime = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final url = '${AppConstants.baseUrl}/api/appointment/musaitberber?barberId=${barber.id}&date=$dateStr&serviceId=${service['_id'] ?? service['id']}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _slots = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching slots: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Tarih ve Saat Seçimi', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          const Divider(color: Colors.white24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
                : _slots.isEmpty
                    ? const Center(child: Text('Bu tarihte müsaitlik bulunamadı.', style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          final isAvailable = slot['available'];
                          final isSelected = _selectedTime == slot['time'];

                          return GestureDetector(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      _selectedTime = slot['time'];
                                    });
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFC69749)
                                    : (isAvailable ? const Color(0xFF2C2C2C) : Colors.transparent),
                                border: Border.all(
                                  color: isAvailable ? const Color(0xFFC69749) : Colors.white10,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                slot['time'],
                                style: TextStyle(
                                  color: isAvailable ? Colors.white : Colors.white24,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedTime == null
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        '/guestInfo',
                        arguments: {
                          ...args,
                          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                          'startTime': _selectedTime,
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC69749),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Devam Et', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFFC69749)),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _fetchSlots();
              });
            },
          ),
          TextButton(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = picked;
                  _fetchSlots();
                });
              }
            },
            child: Text(
              DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFFC69749)),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
                _fetchSlots();
              });
            },
          ),
        ],
      ),
    );
  }
}
