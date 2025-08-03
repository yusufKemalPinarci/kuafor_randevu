import 'package:flutter/material.dart';
import 'package:kuafor_randevu/pages/shop_selection_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

import '../providers/shop_provider.dart';

class CreateShopPage extends StatefulWidget {
  const CreateShopPage({super.key});

  @override
  State<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();

  final _employeeEmailController = TextEditingController();
  List<String> _employeeEmails = [];

  final Map<String, bool> _workingDays = {
    'Pzt': false,
    'Sal': false,
    'Çar': false,
    'Per': false,
    'Cum': false,
    'Cmt': false,
    'Paz': false,
  };

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime != null &&
            (_endTime!.hour < _startTime!.hour ||
                (_endTime!.hour == _startTime!.hour &&
                    _endTime!.minute <= _startTime!.minute))) {
          _endTime = null;
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      if (_startTime == null) {
        _showMessage("Önce başlangıç saatini seçin.");
        return;
      }
      if (picked.hour < _startTime!.hour ||
          (picked.hour == _startTime!.hour &&
              picked.minute <= _startTime!.minute)) {
        _showMessage("Bitiş saati, başlangıç saatinden sonra olmalı.");
        return;
      }
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _addEmployee() {
    final email = _employeeEmailController.text.trim();
    if (email.isEmpty) {
      _showMessage("Lütfen e-posta adresi girin.");
      return;
    }
    if (!_isValidEmail(email)) {
      _showMessage("Geçerli bir e-posta girin.");
      return;
    }
    if (_employeeEmails.contains(email)) {
      _showMessage("Bu e-posta zaten listede.");
      return;
    }
    setState(() {
      _employeeEmails.add(email);
      _employeeEmailController.clear();
    });
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _removeEmployee(String email) {
    setState(() {
      _employeeEmails.remove(email);
    });
  }

  void _createShop() async {
    final name = _shopNameController.text.trim();
    final address = _shopAddressController.text.trim();
    final selectedDays = _workingDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (name.isEmpty || address.isEmpty) {
      _showMessage("Lütfen dükkan adı ve adresini girin.");
      return;
    }
    if (selectedDays.isEmpty) {
      _showMessage("Lütfen çalışma günlerinden en az birini seçin.");
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showMessage("Lütfen çalışma saatlerini seçin.");
      return;
    }

    final shopData = {
      'name': name,
      'address': address,
      'workingDays': selectedDays,
      'startTime': _startTime!.format(context),
      'endTime': _endTime!.format(context),
      'employees': _employeeEmails,
    };

    final url = Uri.parse("https://senin-api-url.com/api/shops"); // 🔧 BURAYI DEĞİŞTİR
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(shopData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage("Dükkan başarıyla oluşturuldu.");

        final createdShop = jsonDecode(response.body);
        final shopProvider = Provider.of<ShopProvider>(context, listen: false);
        await shopProvider.saveShopToLocal(createdShop);


        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RegistrationSuccessPage()),
        );
      } else {
        _showMessage("Hata oluştu: ${response.statusCode}");
      }
    } catch (e) {
      _showMessage("Sunucuya bağlanırken hata: $e");
    }
  }



  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _employeeEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text("Dükkan Oluştur",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputField("Dükkan Adı", _shopNameController, Icons.store),
            const SizedBox(height: 24),
            _buildInputField("Adres", _shopAddressController, Icons.location_on),
            const SizedBox(height: 32),

            const Text(
              "Çalışma Günleri",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14, // Küçültüldü
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: _workingDays.keys.map((day) {
                final isSelected = _workingDays[day]!;
                return FilterChip(
                  label: Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontSize: 13, // Küçültüldü
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFC69749),
                  backgroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (selected) {
                    setState(() {
                      _workingDays[day] = selected;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 36),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStartTime,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC69749)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _startTime == null
                          ? "Başlangıç Saati"
                          : "Başlangıç: ${_startTime!.format(context)}",
                      style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEndTime,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC69749)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      _endTime == null
                          ? "Bitiş Saati"
                          : "Bitiş: ${_endTime!.format(context)}",
                      style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            const Text(
              "Çalışan Ekle (Opsiyonel)",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _employeeEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Çalışan e-posta adresi",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69749),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                  ),
                  child: const Text("Ekle"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_employeeEmails.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _employeeEmails.map((email) {
                  return Chip(
                    label: Text(email, style: const TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF2C2C2C),
                    deleteIconColor: const Color(0xFFC69749),
                    onDeleted: () => _removeEmployee(email),
                  );
                }).toList(),
              ),

            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: _createShop,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC69749),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: Colors.black87,
              ),
              child: const Text(
                "Dükkan Oluştur",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
