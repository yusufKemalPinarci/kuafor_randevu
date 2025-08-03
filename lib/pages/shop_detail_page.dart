import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

class ShopDetailPage extends StatefulWidget {
  const ShopDetailPage({super.key});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  Map<String, dynamic> shopData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShopData();
  }

  Future<void> _fetchShopData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopId = userProvider.user?.shopId;


    if (shopId == null) {
      print('Hata: Kullanıcının bağlı olduğu bir dükkan yok.');
      return;
    }

    final url = 'https://node-js-api-8m2g.onrender.com/api/shop/$shopId'; // BACKEND rotanla uyumlu olacak
    final response = await http.get(Uri.parse(url));
    print("dükkan bilgisi${shopId}", );
    if (response.statusCode == 200) {
      setState(() {
        shopData = jsonDecode(response.body);
        print("dükkan bilgisi${shopData}", );
        print("dükkan bilgisi${shopId}", );
        isLoading = false;
      });
    } else {
      print('Dükkan verisi alınamadı: ${response.statusCode}');
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1F1F1F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        title: const Text('Dükkan Bilgileri'),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoTile('Dükkan Adı', shopData['name']),
            _buildInfoTile('Açıklama', shopData['description']),
            _buildInfoTile('Adres', shopData['adress']),
            _buildInfoTile('Şehir', shopData['city']),
            _buildInfoTile('Telefon', shopData['phone']),
            _buildInfoTile('E-Posta', shopData['email']),
            _buildInfoTile('Açılış Saati', shopData['openTime']),
            _buildInfoTile('Kapanış Saati', shopData['closeTime']),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/shop_edit_page');
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Dükkanı Düzenle'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        backgroundColor: Colors.blueGrey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(

                      onPressed: () => _showLeaveShopConfirmation(context),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Dükkandan Ayrıl'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        backgroundColor: Colors.red,
                      ),

                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveShopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dükkandan Ayrıl'),
        content: const Text('Bu dükkandan ayrılmak istediğine emin misin?'),
        actions: [
          TextButton(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Ayrıl', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              // Buraya dükkan ayrılma API isteğini ekle
              Navigator.pushReplacementNamed(context, '/profile_page');
            },
          ),
        ],
      ),
    );
  }
}
