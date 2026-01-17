import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/user_provider.dart';

class GuestInfoPage extends StatefulWidget {
  const GuestInfoPage({super.key});

  @override
  State<GuestInfoPage> createState() => _GuestInfoPageState();
}

class _GuestInfoPageState extends State<GuestInfoPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isLoggedIn) {
      _nameController.text = userProvider.user?.name ?? '';
      _phoneController.text = userProvider.user?.phone ?? '';
    }
  }

  Future<void> _handleBooking() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen isim ve telefon numarası giriniz.')));
      return;
    }

    setState(() => _isLoading = true);

    if (userProvider.isLoggedIn) {
      // Logged in user booking
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.baseUrl}/api/appointment'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${userProvider.user?.jwtToken}',
          },
          body: jsonEncode({
            'barberId': args['barber'].id,
            'date': args['date'],
            'startTime': args['startTime'],
            'serviceId': args['service']['_id'] ?? args['service']['id'],
          }),
        );

        if (response.statusCode == 200) {
          _showSuccessDialog();
        } else {
          final error = jsonDecode(response.body);
          _showError(error['error'] ?? 'Randevu alınamadı.');
        }
      } catch (e) {
        _showError('Hata oluştu: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Guest booking - Request OTP
      try {
        final response = await http.post(
          Uri.parse('${AppConstants.baseUrl}/api/appointment/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'barberId': args['barber'].id,
            'serviceId': args['service']['_id'] ?? args['service']['id'],
            'date': args['date'],
            'startTime': args['startTime'],
            'customerName': _nameController.text,
            'customerPhone': _phoneController.text,
            // 'endTime': ... // Backend calculates it in auth route, but here we might need to send or fix backend
          }),
        );

        if (response.statusCode == 200) {
          Navigator.pushNamed(
            context,
            '/otpVerification',
            arguments: {
              'phone': _phoneController.text,
            },
          );
        } else {
          final error = jsonDecode(response.body);
          _showError(error['error'] ?? 'OTP gönderilemedi.');
        }
      } catch (e) {
        _showError('Hata oluştu: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Başarılı', style: TextStyle(color: Colors.white)),
        content: const Text('Randevunuz başarıyla oluşturuldu.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Tamam', style: TextStyle(color: Color(0xFFC69749))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Bilgilerinizi Onaylayın', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('İletişim Bilgileri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Ad Soyad', Icons.person),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Telefon Numarası', Icons.phone),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC69749),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Randevu Al', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: const Color(0xFFC69749)),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
