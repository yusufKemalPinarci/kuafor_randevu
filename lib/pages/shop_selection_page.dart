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
  List<ShopModel> assignedShops = [];
  String? _selectedShopId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAssignedShops();
  }

  Future<void> fetchAssignedShops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user == null || user.email.isEmpty) {
        throw Exception("Kullanıcı e-posta bilgisi eksik.");
      }

      final url = Uri.parse('https://node-js-api-8m2g.onrender.com/api/shop/by-staff-email?email=${Uri.encodeComponent(user.email)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<ShopModel> fetchedShops = jsonList.map((json) => ShopModel.fromJson(json)).toList();

        setState(() {
          assignedShops = fetchedShops;
          _isLoading = false;
        });
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      print("Dükkanlar alınamadı: $e");
      setState(() {
        assignedShops = [];
        _isLoading = false;
      });
    }
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
        title: const Text("Dükkan Seç", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC69749)))
          : assignedShops.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Size atanmış dükkan bulunamadı.\n\n"
                "Eğer oluşturulan dükkana katılmak istiyorsanız, dükkanı oluşturan kişiden "
                "çalışan alanına sizin e-posta adresinizi girmesini isteyiniz. "
                "O zaman listede dükkanı görebileceksiniz.",
            style: TextStyle(color: Colors.white70, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: assignedShops.length,
        itemBuilder: (context, index) {
          final shop = assignedShops[index];
          final isSelected = shop.id == _selectedShopId;

          return GestureDetector(
            onTap: () => _onShopSelected(shop),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFC69749) : const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : null,
              ),
              child: Text(
                shop.name,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
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
