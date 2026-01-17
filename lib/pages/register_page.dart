import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _showMessage("Lütfen tüm alanları doldurun.");
      return;
    }

    if (pass != confirm) {
      _showMessage("Şifreler eşleşmiyor.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${AppConstants.baseUrl}/api/user/register');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': pass,
        }),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final userJson = data['user'];
        final user = UserModel.fromJson(userJson);

        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(user);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user.toJson()));

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/roleSelection');
      } else {
        final error = jsonDecode(response.body);
        _showMessage(error['error'] ?? "Kayıt başarısız oldu.");
      }
    } catch (e) {
      _showMessage("Bir hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt_1, size: 72, color: Color(0xFFC69749)),
                const SizedBox(height: 12),
                const Text(
                  'Kayıt Ol',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 36),

                _buildInputField(
                  label: 'Ad Soyad',
                  controller: _nameController,
                  hint: 'Adınızı ve soyadınızı girin',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  label: 'E-posta',
                  controller: _emailController,
                  hint: 'ornek@mail.com',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  label: 'Şifre',
                  controller: _passwordController,
                  hint: 'Şifre oluşturun',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isObscure: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  label: 'Şifre Tekrar',
                  controller: _confirmController,
                  hint: 'Şifrenizi tekrar girin',
                  icon: Icons.lock_reset,
                  isPassword: true,
                  isObscure: _obscureConfirm,
                  onToggleVisibility: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
                const SizedBox(height: 36),

                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFFC69749))
                    : ElevatedButton(
                  onPressed: _register,
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
                    'Kayıt Ol',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // login sayfasına geri dön
                  },
                  child: const Text(
                    'Zaten hesabın var mı? Giriş Yap',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword ? isObscure : false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                isObscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: onToggleVisibility,
            )
                : null,
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
