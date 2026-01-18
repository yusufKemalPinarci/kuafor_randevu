import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/user_provider.dart';

class CustomerAppointmentsPage extends StatefulWidget {
  const CustomerAppointmentsPage({super.key});

  @override
  State<CustomerAppointmentsPage> createState() => _CustomerAppointmentsPageState();
}

class _CustomerAppointmentsPageState extends State<CustomerAppointmentsPage> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/appointment/my'),
        headers: {
          'Authorization': 'Bearer ${userProvider.user?.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _appointments = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching customer appointments: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Randevularım', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
          : _appointments.isEmpty
              ? const Center(child: Text('Henüz randevunuz bulunmuyor.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(appt['barberId']?['name'] ?? 'Bilinmeyen Berber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${appt['date'].split('T')[0]} - ${appt['startTime']}', style: const TextStyle(color: Colors.white70)),
                            Text(appt['serviceId']?['title'] ?? '', style: const TextStyle(color: Color(0xFFC69749))),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: appt['status'] == 'confirmed' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appt['status'] == 'confirmed' ? 'Onaylandı' : 'Bekliyor',
                            style: TextStyle(color: appt['status'] == 'confirmed' ? Colors.green : Colors.orange, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
