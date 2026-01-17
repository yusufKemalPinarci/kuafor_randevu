import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';



class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  bool get isLoggedIn => _user != null && _user!.isTokenValid;




  // Kullanıcıyı provider içine set et
  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  // Kullanıcıyı güncelle (örn: shopId veya doğrulama durumları değiştiğinde)
  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  // Local'den kullanıcı bilgisini yükle
  Future<void> loadUserFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user');
    if (jsonString != null) {
      final userData = jsonDecode(jsonString);
      _user = UserModel.fromJson(userData);
      notifyListeners();
    }
  }

  // Kullanıcı bilgisini local storage'a kaydet
  Future<void> saveUserToLocal(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toJson());
    await prefs.setString('user', jsonString);
    _user = user;
    notifyListeners();
  }


  // sadece providera kaydeden
  void setUserInMemory(UserModel user) {
    _user = user;
    notifyListeners();
  }
 // sadece locale kaydeden
  Future<void> saveUserToLocalOnly(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(user.toJson());
    await prefs.setString('user', jsonString);
  }
  // hem locale hem de providara kaydeden.
  Future<void> saveUserToLocalAndProvider(UserModel user) async {
    _user = user;
    notifyListeners();
    await saveUserToLocalOnly(user); // üstteki fonksiyonu çağırır
  }

  // Oturumu kapat
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    _user = null;
    notifyListeners();
  }

  // Örnek: Telefon doğrulama durumu güncelle
  void setPhoneVerified(bool isVerified) {
    if (_user != null) {
      _user = _user!.copyWith(isPhoneVerified: isVerified);
      saveUserToLocal(_user!); // Değişikliği localde de sakla
      notifyListeners();
    }
  }

  // Örnek: Seçilen dükkanı güncelle (shopId)
  void setSelectedShopId(String? shopId) {
    if (_user != null) {
      _user = _user!.copyWith(shopId: shopId);
      saveUserToLocal(_user!);
      notifyListeners();
    }
  }
}
