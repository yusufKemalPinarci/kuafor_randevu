import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/app_theme.dart';
import 'GuestBarberSelectionPage.dart';

class BookingLinkPage extends StatefulWidget {
  final String shopCode;
  const BookingLinkPage({super.key, required this.shopCode});

  @override
  State<BookingLinkPage> createState() => _BookingLinkPageState();
}

class _BookingLinkPageState extends State<BookingLinkPage> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAndNavigate();
  }

  Future<void> _fetchAndNavigate() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/shop/by-code/${widget.shopCode}'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final shop = jsonDecode(response.body);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GuestBarberSelectionPage(
              shopId: shop['_id'],
              shopName: shop['name'],
            ),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Dükkan bulunamadı. Lütfen bağlantının doğru olduğundan emin olun.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'İnternet bağlantınızı kontrol edip tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ct.bg,
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Dükkan bilgileri yükleniyor...',
                    style: TextStyle(color: context.ct.textSecondary, fontSize: 15),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Bir hata oluştu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.ct.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Geri Dön', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
