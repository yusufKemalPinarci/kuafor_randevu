import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../models/shop_model.dart';
import '../models/user_model.dart';

class StaffSelectionPage extends StatefulWidget {
  const StaffSelectionPage({super.key});

  @override
  State<StaffSelectionPage> createState() => _StaffSelectionPageState();
}

class _StaffSelectionPageState extends State<StaffSelectionPage> {
  List<UserModel> _staff = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shop = ModalRoute.of(context)!.settings.arguments as ShopModel;
    _fetchStaff(shop.id);
  }

  Future<void> _fetchStaff(String shopId) async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/shop/$shopId/staff'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _staff = data.map((json) => UserModel.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching staff: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = ModalRoute.of(context)!.settings.arguments as ShopModel;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Berber Seçimi', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
          : _staff.isEmpty
              ? const Center(child: Text('Bu dükkanda çalışan bulunamadı.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final barber = _staff[index];
                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1F1F1F),
                          child: const Icon(Icons.person, color: Color(0xFFC69749)),
                        ),
                        title: Text(barber.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Berber', style: TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749), size: 16),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/serviceSelection',
                            arguments: {
                              'shop': shop,
                              'barber': barber,
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
