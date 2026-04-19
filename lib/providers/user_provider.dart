import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';

const _kJwtKey = 'jwt_token';
const _kRefreshKey = 'refresh_token';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('user');
      if (jsonString != null) {
        final userData = jsonDecode(jsonString);
        // JWT ve refresh token'ı güvenli depolamadan oku
        final token = await _secureStorage.read(key: _kJwtKey);
        final refreshToken = await _secureStorage.read(key: _kRefreshKey);
        if (token != null) userData['jwtToken'] = token;
        if (refreshToken != null) userData['refreshToken'] = refreshToken;
        _user = UserModel.fromJson(userData);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ loadUserFromLocal error: $e');
      // Storage okuma hatası — temiz başlangıç yap
      _user = null;
      notifyListeners();
    }
  }

  // Kullanıcı bilgisini local storage'a kaydet
  Future<void> saveUserToLocal(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final json = user.toJson();
    // JWT ve refresh token'ı güvenli depolamaya al, SharedPreferences'ta tutma
    final token = json.remove('jwtToken') as String?;
    final refreshToken = json.remove('refreshToken') as String?;
    if (token != null && token.isNotEmpty) {
      await _secureStorage.write(key: _kJwtKey, value: token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _kRefreshKey, value: refreshToken);
    }
    await prefs.setString('user', jsonEncode(json));
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
    final json = user.toJson();
    final token = json.remove('jwtToken') as String?;
    final refreshToken = json.remove('refreshToken') as String?;
    if (token != null && token.isNotEmpty) {
      await _secureStorage.write(key: _kJwtKey, value: token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _kRefreshKey, value: refreshToken);
    }
    await prefs.setString('user', jsonEncode(json));
  }
  // hem locale hem de providara kaydeden.
  Future<void> saveUserToLocalAndProvider(UserModel user) async {
    _user = user;
    notifyListeners();
    await saveUserToLocalOnly(user); // üstteki fonksiyonu çağırır
  }

  // Oturumu kapat
  Future<void> logout() async {
    // Backend'e logout isteği gönder (refresh tokenları iptal et)
    try {
      final jwt = _user?.jwtToken;
      final refreshToken = await _secureStorage.read(key: _kRefreshKey);
      if (jwt != null && jwt.isNotEmpty) {
        await http.post(
          Uri.parse('${AppConstants.baseUrl}/api/user/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({'refreshToken': refreshToken ?? ''}),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Backend logout hatası: $e');
      // Backend çağrısı başarısız olsa bile lokal temizlik yap
    }

    // Lokal temizlik
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await _secureStorage.delete(key: _kJwtKey);
      await _secureStorage.delete(key: _kRefreshKey);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Lokal temizlik hatası: $e');
    }

    _user = null;
    notifyListeners();

    // Firebase + Google Sign-In oturumlarını da kapat
    try {
      await FirebaseAuthService().signOut();
    } catch (_) {}
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
