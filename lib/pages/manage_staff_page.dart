import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/user_provider.dart';

class ManageStaffPage extends StatefulWidget {
  final String shopId;
  const ManageStaffPage({super.key, required this.shopId});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  List<dynamic> _staff = [];
  bool _isLoading = true;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/shop/${widget.shopId}/staff'));
      if (response.statusCode == 200) {
        setState(() {
          _staff = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching staff: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addStaff() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/shop/${widget.shopId}/add-staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userProvider.user?.jwtToken}',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        _emailController.clear();
        _fetchStaff();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan başarıyla eklendi.')));
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error['message'] ?? 'Ekleme başarısız.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _removeStaff(String email) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/shop/${widget.shopId}/remove-staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userProvider.user?.jwtToken}',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        _fetchStaff();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan çıkarıldı.')));
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Çalışanları Yönet', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Çalışan e-posta adresi',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69749),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ekle', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
                : _staff.isEmpty
                    ? const Center(child: Text('Henüz çalışan yok.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _staff.length,
                        itemBuilder: (context, index) {
                          final person = _staff[index];
                          return Card(
                            color: const Color(0xFF2C2C2C),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1F1F1F),
                                child: Icon(Icons.person, color: Color(0xFFC69749)),
                              ),
                              title: Text(person['name'] ?? '', style: const TextStyle(color: Colors.white)),
                              subtitle: Text(person['email'] ?? '', style: const TextStyle(color: Colors.white70)),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                onPressed: () => _removeStaff(person['email']),
                              ),
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
