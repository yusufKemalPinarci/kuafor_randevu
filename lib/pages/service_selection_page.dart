import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../models/user_model.dart';

class ServiceSelectionPage extends StatefulWidget {
  const ServiceSelectionPage({super.key});

  @override
  State<ServiceSelectionPage> createState() => _ServiceSelectionPageState();
}

class _ServiceSelectionPageState extends State<ServiceSelectionPage> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final barber = args['barber'] as UserModel;
    _fetchServices(barber.id);
  }

  Future<void> _fetchServices(String barberId) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/service/$barberId/services'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _services = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching services: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final shop = args['shop'];
    final barber = args['barber'] as UserModel;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Hizmet Seçimi', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
          : _services.isEmpty
              ? const Center(child: Text('Bu berbere ait hizmet bulunamadı.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(service['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${service['durationMinutes']} dk - ${service['price']} TL', style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749), size: 16),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/dateTimeSelection',
                            arguments: {
                              'shop': shop,
                              'barber': barber,
                              'service': service,
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
