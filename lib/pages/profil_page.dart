import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kuafor_randevu/pages/shop_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/shop_provider.dart';
import '../providers/user_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  bool isEmailVerified = true;
  bool isPhoneVerified = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    final hasShop = user?.shopId != "";
    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';
    final userPhone = user?.phone?? ''; // Eğer phoneNumber alanı varsa
    final isEmailVerified = user?.isEmailVerified ?? false;
    final isPhoneVerified = user?.isPhoneVerified ?? false;
    isLoading = false;

    print("bu adam ${userProvider.user}");
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1F1F1F),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Profil', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Kullanıcı Bilgileri'),
                const SizedBox(height: 8),
                _buildUserInfoCard('Ad Soyad', userName),
                _buildUserInfoCard('E-Posta', userEmail, verified: isEmailVerified),
                _buildUserInfoCard('Telefon', userPhone, verified: isPhoneVerified),

                const SizedBox(height: 24),
                if (!isEmailVerified || !isPhoneVerified)
                  _buildSectionTitle('Doğrulama'),

                const SizedBox(height: 8),
                if (!isEmailVerified)
                  _buildActionButton(
                    icon: Icons.email_outlined,
                    label: 'E-Postayı Doğrula',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Doğrulama Maili Gönderildi"),
                          content: const Text("Lütfen e-posta kutunuzu kontrol edin."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Tamam"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (!isPhoneVerified)
                  _buildActionButton(
                    icon: Icons.phone_android_outlined,
                    label: 'Telefonu Doğrula',
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/phone_verification_page');
                    },
                  ),

                const SizedBox(height: 24),
                _buildSectionTitle('İşlemler'),
                const SizedBox(height: 8),
                _buildActionButton(
                  icon: Icons.access_time,
                  label: 'Çalışma Saatlerini Ayarla',
                  enabled: true,
                  onTap: () {
                    if (isEmailVerified && isPhoneVerified && hasShop) {
                      print (hasShop);
                      Navigator.pushNamed(context, '/working-hours');
                    } else {
                      String message = '';
                      if (!isEmailVerified && !isPhoneVerified && !hasShop) {
                        message = 'E-posta ve telefon doğrulaması yapmalı, ayrıca bir dükkanınız olmalıdır.';
                      } else if (!isEmailVerified && !isPhoneVerified) {
                        print ("dükkan var mı ${user?.shopId} ${hasShop}");
                        message = 'E-posta ve telefon doğrulaması yapmalısınız.';
                      } else if (!isEmailVerified) {
                        message = 'E-posta doğrulaması yapmalısınız.';
                      } else if (!isPhoneVerified) {
                        message = 'Telefon doğrulaması yapmalısınız.';
                      } else if (!hasShop) {
                        message = 'Öncelikle bir dükkan oluşturmalı veya seçmelisiniz.';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  },
                ),
                hasShop
                    ? _buildActionButton(
                  icon: Icons.info_outline,
                  label: 'Dükkan Bilgilerini Görüntüle',
                  enabled: true,
                  onTap: () => Navigator.pushNamed(context, '/shop_detail_page'),
                )
                    : Column(
                  children: [
                    _buildActionButton(
                      icon: Icons.storefront_outlined,
                      label: 'Dükkan Seç',
                      enabled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopSelectionPage(redirectToSuccessPage: false),
                        ),
                      ),
                    ),
                    _buildActionButton(
                      icon: Icons.add_business_outlined,
                      label: 'Yeni Dükkan Oluştur',
                      enabled: true,
                      onTap: () => Navigator.pushNamed(context, '/create-shop-page'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton.icon(
              onPressed: () async{
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final shopProvider = Provider.of<ShopProvider>(context, listen: false);
                final prefs = await SharedPreferences.getInstance();
                print("user bilgisi");
                print(prefs.getString('user'));

                await userProvider.logout();
                await shopProvider.clearShop(); // temizle

                if (!mounted) return;
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(String title, String value, {bool verified = true}) {
    return Card(
      color: const Color(0xFF2C2C2C),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white70)),
        subtitle: Text(value, style: const TextStyle(color: Colors.white)),
        trailing: verified
            ? const Icon(Icons.verified, color: Colors.green, size: 20)
            : const Icon(Icons.warning, color: Colors.orangeAccent, size: 20),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFFC69749) : Colors.grey.shade700,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
