import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isLoading = false;

  Future<void> _selectRole(BuildContext context, String role) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null || user.jwtToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata: Oturum bulunamadı.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final roleMap = {
        'berber': 'Barber',
        'musteri': 'Customer',
      };

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/user/role'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.jwtToken}',
        },
        body: jsonEncode({'role': roleMap[role]}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedUser = UserModel.fromJson({
          ...data['user'],
          'jwtToken': user.jwtToken,
        });

        await userProvider.saveUserToLocal(updatedUser);

        if (!mounted) return;
        if (role == 'berber') {
          Navigator.pushReplacementNamed(context, '/barber-shop-options');
        } else {
          Navigator.pushReplacementNamed(context, '/customerHome');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol güncellenemedi.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.switch_account, size: 80, color: Color(0xFFC69749)),
                const SizedBox(height: 16),
                const Text(
                  "Rolünü Seç",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 36),

                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFFC69749))
                else ...[
                  _buildRoleButton(
                    context,
                    label: "Berber",
                    icon: Icons.cut,
                    onTap: () => _selectRole(context, 'berber'),
                  ),
                  const SizedBox(height: 24),
                  _buildRoleButton(
                    context,
                    label: "Müşteri",
                    icon: Icons.person_outline,
                    onTap: () => _selectRole(context, 'musteri'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context,
      {required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC69749), width: 1.2),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFC69749)),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
