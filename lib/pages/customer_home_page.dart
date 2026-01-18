import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../models/shop_model.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  List<ShopModel> _allShops = [];
  List<ShopModel> _filteredShops = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/api/shop'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allShops = data.map((json) => ShopModel.fromJson(json)).toList();
          _filteredShops = _allShops;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching shops: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterShops(String query) {
    setState(() {
      _filteredShops = _allShops
          .where((shop) =>
              shop.name.toLowerCase().contains(query.toLowerCase()) ||
              shop.city.toLowerCase().contains(query.toLowerCase()) ||
              shop.neighborhood.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isLoggedIn = userProvider.isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Berberler', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          if (isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Color(0xFFC69749)),
              onPressed: () => Navigator.pushNamed(context, '/customer-appointments'),
            ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Color(0xFFC69749)),
              onPressed: () => Navigator.pushNamed(context, '/profile_page'),
            ),
          ]
          else
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Giriş Yap', style: TextStyle(color: Color(0xFFC69749))),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterShops,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Berber veya şehir ara...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFC69749)),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
                : _filteredShops.isEmpty
                    ? const Center(child: Text('Dükkan bulunamadı.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _filteredShops.length,
                        itemBuilder: (context, index) {
                          final shop = _filteredShops[index];
                          return Card(
                            color: const Color(0xFF2C2C2C),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F1F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.storefront, color: Color(0xFFC69749)),
                              ),
                              title: Text(shop.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('${shop.city}, ${shop.neighborhood}', style: const TextStyle(color: Colors.white70)),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFC69749), size: 16),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/customerShopDetail',
                                  arguments: shop,
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
