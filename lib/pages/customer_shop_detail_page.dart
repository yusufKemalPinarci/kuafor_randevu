import 'package:flutter/material.dart';
import '../models/shop_model.dart';

class CustomerShopDetailPage extends StatelessWidget {
  const CustomerShopDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shop = ModalRoute.of(context)!.settings.arguments as ShopModel;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(shop.name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.storefront, size: 80, color: Color(0xFFC69749)),
            ),
            const SizedBox(height: 24),
            Text(shop.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFC69749), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${shop.city}, ${shop.neighborhood}', style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Hakkında', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(shop.fullAddress, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.access_time, 'Çalışma Saatleri', '${shop.openingHour} - ${shop.closingHour}'),
            _buildInfoRow(Icons.phone, 'Telefon', shop.phone ?? 'Belirtilmemiş'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/staffSelection',
                  arguments: shop,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC69749),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Randevu Al', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC69749), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
