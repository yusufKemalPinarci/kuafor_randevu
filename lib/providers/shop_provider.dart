import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shop_model.dart';

class ShopProvider extends ChangeNotifier {
  ShopModel? _selectedShop;

  ShopModel? get selectedShop => _selectedShop;

  /// Local storage'dan shop'u yükler ve Provider'a aktarır
  Future<void> loadShopFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final shopJson = prefs.getString('selectedShop');
    if (shopJson != null) {
      try {
        final shopMap = jsonDecode(shopJson);
        _selectedShop = ShopModel.fromJson(shopMap);
        notifyListeners();
      } catch (e) {
        // JSON parse hatası varsa temizle
        await clearShop();
      }
    }
  }

  /// Seçili dükkanı Provider'a ve local storage'a kaydeder
  Future<void> saveShopToLocal(ShopModel shop, {bool persist = true}) async {
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedShop', jsonEncode(shop.toJson()));
    }
    _selectedShop = shop;
    notifyListeners();
  }

  /// Seçili dükkanı sıfırlar (hem local hem Provider'dan)
  Future<void> clearShop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedShop');
    _selectedShop = null;
    notifyListeners();
  }

  /// Sadece Provider içinde güncelleme yapmak istiyorsan bu kullanılabilir
  void updateSelectedShop(ShopModel shop) {
    _selectedShop = shop;
    notifyListeners();
  }
}
