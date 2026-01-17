import 'package:flutter/material.dart';
import 'dart:convert';
// import 'package:http/http.dart' as http;

class ShopEditPage extends StatefulWidget {
  const ShopEditPage({super.key});

  @override
  State<ShopEditPage> createState() => _ShopEditPageState();
}

class _ShopEditPageState extends State<ShopEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Dükkan bilgileri
  String name = 'Altın Makas';
  String description = 'Profesyonel berber hizmeti';
  String address = 'Atatürk Caddesi No:12';
  String city = 'İstanbul';
  String phone = '0532 123 45 67';
  String email = 'altinmakas@example.com';
  String openTime = '09:00';
  String closeTime = '21:00';

  bool isLoading = false;

  Future<void> _saveShopData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    _formKey.currentState!.save();

    final updatedData = {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'phone': phone,
      'email': email,
      'openTime': openTime,
      'closeTime': closeTime,
    };

    // await http.put(
    //   Uri.parse('https://senin-api.com/api/shop/update'),
    //   headers: {
    //     'Content-Type': 'application/json',
    //     'Authorization': 'Bearer tokenBurayaGelecek',
    //   },
    //   body: jsonEncode(updatedData),
    // );

    await Future.delayed(const Duration(seconds: 1)); // API simülasyonu

    setState(() {
      isLoading = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dükkan bilgileri güncellendi.')),
    );

    Navigator.pop(context); // Önceki sayfaya dön
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: const Text('Dükkanı Düzenle'),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildInputField('Dükkan Adı', name, (val) => name = val),
              _buildInputField('Açıklama', description, (val) => description = val),
              _buildInputField('Adres', address, (val) => address = val),
              _buildInputField('Şehir', city, (val) => city = val),
              _buildInputField('Telefon', phone, (val) => phone = val, keyboardType: TextInputType.phone),
              _buildInputField('E-Posta', email, (val) => email = val, keyboardType: TextInputType.emailAddress),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField('Açılış', openTime, (val) => openTime = val),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField('Kapanış', closeTime, (val) => closeTime = val),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveShopData,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label,
      String initialValue,
      Function(String) onSaved, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        style: const TextStyle(color: Colors.white),
        initialValue: initialValue,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return '$label boş olamaz';
          return null;
        },
        onSaved: (value) => onSaved(value ?? ''),
      ),
    );
  }
}
