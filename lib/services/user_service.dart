import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _client = ApiClient();


  Future<UserModel?> selectShop({
    required String jwtToken,
    required String shopId,
  }) async {
    final response = await _client.post(
      '/api/user/select-shop',
      body: {'shopId': shopId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson({
        ...data['user'],
        'jwtToken': jwtToken,
      });
    } else {
      if (kDebugMode) debugPrint('API Error: ${response.body}');
      return null;
    }
  }

  Future<UserModel?> updateShopId(String jwtToken, String shopId) async {
    final response = await _client.put(
      '/api/user/shop',
      body: {'shopId': shopId},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson({
        ...data['user'],
        'jwtToken': jwtToken,
      });
    } else {
      if (kDebugMode) debugPrint('Update shop error: ${response.body}');
      return null;
    }
  }


  Future<UserModel?> leaveShop(String jwtToken) async {
    final response = await _client.post('/api/user/leave-shop');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson({
        ...data['user'],
        'jwtToken': jwtToken,
      });
    } else {
      if (kDebugMode) debugPrint('Leave shop error: ${response.body}');
      return null;
    }
  }

  /// Hesabı ve tüm ilişkili verileri kalıcı olarak siler.
  Future<({bool success, String message})> deleteAccount(String jwtToken) async {
    final response = await _client.delete('/api/user/account');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (success: true, message: (data['message'] as String?) ?? 'Hesap silindi.');
    } else {
      return (success: false, message: (data['error'] as String?) ?? 'Hesap silinemedi.');
    }
  }

  /// Bildirim tercihlerini ve aktif abonelik katmanını getirir.
  Future<({NotificationPreferences preferences, String? activeTier})?> getNotificationPreferences() async {
    final response = await _client.get('/api/user/notification-preferences');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (
        preferences: NotificationPreferences.fromJson(data['preferences'] ?? {}),
        activeTier: data['activeTier'] as String?,
      );
    } else {
      if (kDebugMode) debugPrint('Get notification prefs error: ${response.body}');
      return null;
    }
  }

  /// Bildirim tercihlerini günceller.
  Future<NotificationPreferences?> updateNotificationPreferences(
      NotificationPreferences prefs) async {
    final response = await _client.put(
      '/api/user/notification-preferences',
      body: prefs.toJson(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return NotificationPreferences.fromJson(data['preferences'] ?? {});
    } else {
      if (kDebugMode) debugPrint('Update notification prefs error: ${response.body}');
      return null;
    }
  }
}
