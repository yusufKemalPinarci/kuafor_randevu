import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_provider.dart';
import '../services/user_service.dart';
import '../core/constants.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';

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

    if (shopId == null || shopId.trim().isEmpty) {
      if (mounted) showAppSnackBar(context, 'Bağlı bir dükkan bulunamadı.', isError: true);
      return;
    }

    try {
      final url = '${AppConstants.baseUrl}/api/shop/$shopId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          shopData = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Dükkan bilgileri yüklenemedi. Lütfen tekrar deneyin.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final shopCode = shopData['shopCode'] ?? '';
    final user = Provider.of<UserProvider>(context, listen: false).user;
    final isOwner = user != null && shopData['ownerId']?.toString() == user.id;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: shopData['name'] ?? 'Dükkan Bilgileri'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Invite Code Card (Sadece Sahip) ──
                    if (isOwner && shopCode.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: Spacing.xxl),
                        padding: const EdgeInsets.all(Spacing.xxl),
                        decoration: BoxDecoration(
                          color: context.ct.warningSoft,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.primary.withAlpha(40)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2, color: AppColors.primary, size: 20),
                                const SizedBox(width: Spacing.sm),
                                Text('Dükkan Davet Kodu', style: TextStyle(color: context.ct.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: Spacing.md),
                            SelectableText(
                              shopCode,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              'Bu kodu çalışanlarınızla paylaşın',
                              style: TextStyle(color: context.ct.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    // ── Info Tiles ──
                    if (shopData['name'] != null) _buildInfoTile(Icons.storefront_rounded, 'Dükkan Adı', shopData['name']),
                    if (shopData['city'] != null && shopData['city'].toString().isNotEmpty) _buildInfoTile(Icons.location_city_rounded, 'Şehir', shopData['city']),
                    if (shopData['neighborhood'] != null && shopData['neighborhood'].toString().isNotEmpty) _buildInfoTile(Icons.map_rounded, 'Mahalle', shopData['neighborhood']),
                    if (shopData['adress'] != null && shopData['adress'].toString().isNotEmpty) _buildInfoTile(Icons.pin_drop_rounded, 'Adres', shopData['adress']),
                    if (shopData['phone'] != null && shopData['phone'].toString().isNotEmpty) _buildInfoTile(Icons.phone_rounded, 'Telefon', shopData['phone']),
                    if (shopData['openingHour'] != null) _buildInfoTile(Icons.access_time_rounded, 'Açılış', shopData['openingHour']),
                    if (shopData['closingHour'] != null) _buildInfoTile(Icons.access_time_filled_rounded, 'Kapanış', shopData['closingHour']),
                    if (isOwner)
                      _buildInfoTile(
                        Icons.event_available_rounded,
                        'Randevu Onayı',
                        (shopData['autoConfirmAppointments'] == true) ? 'Otomatik' : 'Manuel',
                      ),

                    const SizedBox(height: Spacing.xxxl),

                    // ── Action Buttons ──
                    if (isOwner)
                      // Sahip: sadece Düzenle
                      Material(
                        color: context.ct.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/shop_edit_page'),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: context.ct.surfaceBorder),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: Spacing.sm),
                                Text('Dükkanı Düzenle', style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      // Çalışan: sadece Ayrıl
                      Material(
                        color: context.ct.errorSoft,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InkWell(
                          onTap: () => _showLeaveShopConfirmation(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.error.withAlpha(30)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 20),
                                SizedBox(width: Spacing.sm),
                                Text('Dükkandan Ayrıl', style: TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: context.ct.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: context.ct.surfaceBorder.withAlpha(80)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.ct.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(value ?? '-', style: TextStyle(color: context.ct.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveShopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.ct.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: context.ct.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: Spacing.md),
            Text('Dükkandan Ayrıl', style: TextStyle(color: context.ct.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Bu dükkandan ayrılmak istediğine emin misin? Tüm bağlantıların kesilecektir.',
          style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(Spacing.xxl, 0, Spacing.xxl, Spacing.xl),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.ct.textSecondary,
                    side: BorderSide(color: context.ct.surfaceBorder),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    final user = userProvider.user;

                    if (user == null || user.jwtToken == null) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      return;
                    }

                    final userService = UserService();
                    final updatedUserFromApi = await userService.leaveShop(user.jwtToken!);

                    if (updatedUserFromApi == null) {
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        showAppSnackBar(context, 'Dükkandan ayrılırken bir sorun oluştu. Lütfen tekrar deneyin.', isError: true);
                      }
                      return;
                    }

                    userProvider.setUser(updatedUserFromApi);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('selectedShop');

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/barberHome');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Ayrıl', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
