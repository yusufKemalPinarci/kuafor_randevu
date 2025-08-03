import 'package:flutter/material.dart';

class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({super.key});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final TextEditingController _codeController = TextEditingController();

  void _verifyCode() {
    final code = _codeController.text.trim();
    if (code == "123456") {
      // Simülasyon: doğru kod
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Telefon doğrulandı!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod yanlış')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(title: const Text("Telefon Doğrulama")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Telefonunuza gönderilen 6 haneli kodu girin.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Doğrulama Kodu',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyCode,
              child: const Text("Doğrula"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC69749),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
