import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://node-js-api-8m2g.onrender.com/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userJson = data['user'];
        final token = data['token'];

        final user = UserModel.fromJson({
          ...userJson,
          'jwtToken': token,
          'tokenExpiry': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        });

        /*
        // Provider'a aktar
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(user);

        // SharedPreferences'e kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user.toJson()));*/
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.saveUserToLocal(user);

        // Başarılı yönlendirme
        Navigator.pushReplacementNamed(context, '/barberHome');
      } else {
        final error = jsonDecode(response.body);
        _showMessage(error['error'] ?? 'Giriş başarısız.');
        print(error);

      }
    } catch (e) {
      _showMessage("Hata oluştu: $e");
      print("hata");
      print("$e");
    } finally {
      setState(() => _isLoading = false);
    }
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
                const Icon(Icons.cut, size: 72, color: Color(0xFFC69749)),
                const SizedBox(height: 16),
                const Text(
                  'Kuaför Randevu',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

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
                  hint: 'Şifrenizi girin',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 36),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69749),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black87,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Giriş Yap',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    'Hesabın yok mu? Kayıt Ol',
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white54,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
                : null,
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
