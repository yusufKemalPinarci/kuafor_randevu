import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import '../core/constants.dart';
import '../core/crypto_utils.dart';

/// Merkezi HTTP istemci — JWT auto-refresh ve 401 yönetimi.
///
/// Kullanım:
///   final client = ApiClient();
///   final response = await client.get('/api/appointment/my_berber');
///
/// Token'lar otomatik eklenir. 401 alınırsa refresh denenir,
/// başarısız olursa [onSessionExpired] callback çağrılır.
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const _kJwtKey = 'jwt_token';
  static const _kRefreshKey = 'refresh_token';

  /// Oturum süresi dolduğunda çağrılır (login sayfasına yönlendirme için).
  VoidCallback? onSessionExpired;

  // Aynı anda birden fazla refresh isteği önleme
  Completer<bool>? _refreshCompleter;

  // ─── Public HTTP Methods ───────────────────────────────────

  Future<http.Response> get(String path, {Map<String, String>? headers}) =>
      _request('GET', path, headers: headers);

  Future<http.Response> post(String path,
          {Map<String, String>? headers, Object? body}) =>
      _request('POST', path, headers: headers, body: body);

  Future<http.Response> put(String path,
          {Map<String, String>? headers, Object? body}) =>
      _request('PUT', path, headers: headers, body: body);

  Future<http.Response> delete(String path,
          {Map<String, String>? headers, Object? body}) =>
      _request('DELETE', path, headers: headers, body: body);

  // ─── Token Erişimi ─────────────────────────────────────────

  Future<String?> get currentToken async =>
      await _secureStorage.read(key: _kJwtKey);

  Future<String?> get currentRefreshToken async =>
      await _secureStorage.read(key: _kRefreshKey);

  // ─── Çekirdek İstek İşleyici ──────────────────────────────

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Token süresi dolmak üzereyse proaktif refresh dene
    await _ensureFreshToken();

    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    var response = await _sendRequest(method, uri, headers: headers, body: body);

    // 401 → refresh dene, tekrar istek at
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        response = await _sendRequest(method, uri, headers: headers, body: body);
      } else {
        _handleSessionExpired();
      }
    }

    return response;
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await _secureStorage.read(key: _kJwtKey);
    final bodyStr = body is String
        ? body
        : (body != null ? jsonEncode(body) : '');

    // Release modda HMAC imza header'ları ekle
    final hmacHeaders = kReleaseMode
        ? CryptoUtils.signRequest(
            method: method, path: uri.path, body: bodyStr)
        : <String, String>{};

    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...hmacHeaders,
      ...?headers,
    };

    final effectiveBody = bodyStr.isNotEmpty ? bodyStr : null;

    switch (method) {
      case 'GET':
        return http.get(uri, headers: mergedHeaders);
      case 'POST':
        return http.post(uri, headers: mergedHeaders, body: effectiveBody);
      case 'PUT':
        return http.put(uri, headers: mergedHeaders, body: effectiveBody);
      case 'DELETE':
        return http.delete(uri, headers: mergedHeaders, body: effectiveBody);
      default:
        throw UnsupportedError('HTTP method $method not supported');
    }
  }

  // ─── Token Refresh ─────────────────────────────────────────

  /// Token süresi 5 dakikadan az kaldıysa proaktif olarak yenile.
  Future<void> _ensureFreshToken() async {
    try {
      final token = await _secureStorage.read(key: _kJwtKey);
      if (token == null || token.isEmpty) return;

      final expirationDate = JwtDecoder.getExpirationDate(token);
      final remaining = expirationDate.difference(DateTime.now());

      if (remaining.inMinutes < 5) {
        await _tryRefreshToken();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Token freshness check error: $e');
    }
  }

  /// Refresh token ile yeni JWT al. Aynı anda tek istek gönderilir.
  Future<bool> _tryRefreshToken() async {
    // Halihazırda refresh yapılıyorsa bekle
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await _secureStorage.read(key: _kRefreshKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final bodyStr = jsonEncode({'refreshToken': refreshToken});
      final refreshUri =
          Uri.parse('${AppConstants.baseUrl}/api/user/refresh-token');

      // Refresh isteğinde de HMAC imzası ekle
      final hmacHeaders = kReleaseMode
          ? CryptoUtils.signRequest(
              method: 'POST', path: refreshUri.path, body: bodyStr)
          : <String, String>{};

      final response = await http.post(
        refreshUri,
        headers: {
          'Content-Type': 'application/json',
          ...hmacHeaders,
        },
        body: bodyStr,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;

        if (newToken != null) {
          await _secureStorage.write(key: _kJwtKey, value: newToken);
        }
        if (newRefreshToken != null) {
          await _secureStorage.write(key: _kRefreshKey, value: newRefreshToken);
        }

        if (kDebugMode) debugPrint('✅ Token refreshed successfully');
        _refreshCompleter!.complete(true);
        return true;
      } else {
        if (kDebugMode) debugPrint('⚠️ Token refresh failed: ${response.statusCode}');
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Token refresh error: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  void _handleSessionExpired() {
    if (kDebugMode) debugPrint('🔒 Session expired — redirecting to login');
    onSessionExpired?.call();
  }
}
