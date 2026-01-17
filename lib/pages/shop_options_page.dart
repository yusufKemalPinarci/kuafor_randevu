import 'package:flutter/material.dart';

class ShopOptionPage extends StatefulWidget {
  final bool redirectToSuccessPage;
  const ShopOptionPage({super.key,this.redirectToSuccessPage = true});

  @override
  State<ShopOptionPage> createState() => _ShopOptionPageState();
}

class _ShopOptionPageState extends State<ShopOptionPage> {
  void navigateTo(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dükkan Seçenekleri', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOption(
              context,
              icon: Icons.store,
              title: 'Dükkan Oluştur',
              onTap: () => navigateTo(context, '/create-shop-page'),
            ),
            const SizedBox(height: 16),
            _buildOption(
              context,
              icon: Icons.shopping_bag,
              title: 'Dükkan Seç',
              onTap: () => navigateTo(context, '/shop_selection_page'),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Center(
                child: Text(
                  'Şimdilik bu adımı atla',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context,
      {required IconData icon,
        required String title,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: const Color(0xFFC69749)),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            )
          ],
        ),
      ),
    );
  }
}
