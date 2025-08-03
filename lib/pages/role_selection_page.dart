import 'package:flutter/material.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  void _selectRole(BuildContext context, String role) {
    // Seçilen rolü backend'e gönderip kayıt etmek istiyorsan burada yapabilirsin

    if (role == 'berber') {
      // Berber ana ekranına yönlendir
      Navigator.pushReplacementNamed(context, '/barber-shop-options');
    } else if (role == 'musteri') {
      // Müşteri ana ekranına yönlendir
      Navigator.pushReplacementNamed(context, '/customerHome');
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
