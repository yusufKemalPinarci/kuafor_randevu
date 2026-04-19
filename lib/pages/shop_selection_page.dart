import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shop_model.dart';
import '../providers/user_provider.dart';
import '../services/shop_service.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';

class ShopSelectionPage extends StatefulWidget {
  final bool redirectToSuccessPage;

  const ShopSelectionPage({super.key, this.redirectToSuccessPage = true});

  @override
  State<ShopSelectionPage> createState() => _ShopSelectionPageState();
}

class _ShopSelectionPageState extends State<ShopSelectionPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinShopWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, 'Lütfen dükkan davet kodunu giriniz.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user == null || user.jwtToken == null) {
        throw Exception("Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapın.");
      }

      final shopService = ShopService();
      final responseMap = await shopService.joinShop(code, user.jwtToken!);

      final shopJson = responseMap["shop"];
      final userJson = responseMap["user"];

      if (shopJson == null || userJson == null) {
        throw Exception("Dükkana katılırken bir sorun oluştu. Lütfen tekrar deneyin.");
      }

      final joinedShop = ShopModel.fromJson(shopJson);

      final updatedUser = user.copyWith(
        selectedShop: joinedShop,
        shopId: joinedShop.id,
      );
      userProvider.setUser(updatedUser);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedShop', jsonEncode(joinedShop.toJson()));
      await prefs.setString('user', jsonEncode(updatedUser.toJson()));

      if (!mounted) return;
      if (widget.redirectToSuccessPage) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegistrationSuccessPage()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      showAppSnackBar(context, msg.isNotEmpty ? msg : 'Bir sorun oluştu. Lütfen tekrar deneyin.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: 'Dükkana Katıl'),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Icon ──
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(Spacing.xxxl),
                          border: Border.all(color: AppColors.primary.withAlpha(30)),
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: Spacing.xxl),

                      Text(
                        'Dükkan Davet Kodunuzu Girin',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'Dükkan sahibinin size verdiği 6 haneli davet kodunu girerek dükkana katılabilirsiniz.',
                        style: TextStyle(color: context.ct.textSecondary, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.huge),

                      // ── Code Input ──
                      TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.ct.textPrimary,
                          fontSize: 24,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w800,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'ÖRN: A8B2X9',
                          hintStyle: TextStyle(
                            color: context.ct.textHint,
                            letterSpacing: 0,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
                        ),
                      ),
                      const SizedBox(height: Spacing.xxxl),

                      AppLoadingButton(
                        label: 'Katıl',
                        icon: Icons.login_rounded,
                        isLoading: _isLoading,
                        onPressed: _joinShopWithCode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: context.ct.successSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success.withAlpha(30)),
                  ),
                  child: const Icon(Icons.check_rounded, size: 52, color: AppColors.success),
                ),
                const SizedBox(height: Spacing.xxl),
                Text(
                  'Her şey hazır!',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Kayıt işlemi başarılı.',
                  style: TextStyle(color: context.ct.textSecondary, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.huge),
                AppLoadingButton(
                  label: 'Giriş Sayfasına Git',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
