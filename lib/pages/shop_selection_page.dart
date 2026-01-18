import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/adress_model.dart';
import '../models/shop_model.dart';
import '../providers/user_provider.dart';
import '../services/user_service.dart';

class ShopSelectionPage extends StatefulWidget {
  final bool redirectToSuccessPage;

  const ShopSelectionPage({super.key, this.redirectToSuccessPage = true});

  @override
  State<ShopSelectionPage> createState() => _ShopSelectionPageState();
}

class _ShopSelectionPageState extends State<ShopSelectionPage> {
  List<ShopModel> _allShops = [];
  List<ShopModel> _filteredShops = [];
  String? _selectedShopId;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllShops();
  }

  Future<void> _fetchAllShops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${AppConstants.baseUrl}/api/shop');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<ShopModel> fetchedShops = jsonList.map((json) => ShopModel.fromJson(json)).toList();

        setState(() {
          _allShops = fetchedShops;
          _filteredShops = _allShops;
          _isLoading = false;
        });
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      print("Dükkanlar alınamadı: $e");
      setState(() {
        _allShops = [];
        _filteredShops = [];
        _isLoading = false;
      });
    }
  }

  void _filterShops(String query) {
    setState(() {
      _filteredShops = _allShops
          .where((shop) =>
              shop.name.toLowerCase().contains(query.toLowerCase()) ||
              shop.city.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }


  Future<void> _onShopSelected(ShopModel shop) async {
    setState(() {
      _selectedShopId = shop.id;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null || user.jwtToken == null) {
      print("Kullanıcı ya da token yok");
      return;
    }

    // 1. API'ye kaydet
    final userService = UserService(baseUrl: 'https://node-js-api-8m2g.onrender.com');
    final updatedUserFromApi = await userService.selectShop(
      jwtToken: user.jwtToken!,
      shopId: shop.id,
    );


    if (updatedUserFromApi == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dükkan seçimi API'de başarısız oldu")),
      );
      return;
    }

    // 2. Provider'ı güncelle
    final updatedUser = updatedUserFromApi.copyWith(
      selectedShop: shop,
    );
    userProvider.setUser(updatedUser);

    // 3. SharedPreferences güncelle
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedShop', jsonEncode(shop.toJson()));

    // 4. Yönlendirme
    if (!mounted) return;
    if (widget.redirectToSuccessPage) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationSuccessPage()),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/profile_page');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text("Çalıştığın Dükkanı Seç", style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
                hintText: 'Dükkan ara...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFC69749)),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
                : _filteredShops.isEmpty
                    ? const Center(child: Text('Dükkan bulunamadı.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredShops.length,
                        itemBuilder: (context, index) {
                          final shop = _filteredShops[index];
                          final isSelected = shop.id == _selectedShopId;

                          return GestureDetector(
                            onTap: () => _onShopSelected(shop),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFC69749) : const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.name,
                                        style: TextStyle(
                                          color: isSelected ? Colors.black : Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${shop.city}, ${shop.neighborhood}',
                                        style: TextStyle(
                                          color: isSelected ? Colors.black54 : Colors.white54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: isSelected ? Colors.black : const Color(0xFFC69749),
                                    size: 16,
                                  ),
                                ],
                              ),
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

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

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
                const Icon(Icons.check_circle_outline, size: 100, color: Color(0xFFC69749)),
                const SizedBox(height: 24),
                const Text(
                  "Her şey hazır!",
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Kayıt işlemi başarılı.",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC69749),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: Colors.black87,
                  ),
                  child: const Text(
                    "Giriş Sayfasına Git",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
