import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Release modda HTTP güvenliği: badCertificateCallback daima false.
/// Android network_security_config.xml ile certificate pinning sağlanır.
class SecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Geçersiz sertifikaları hiçbir zaman kabul etme (MITM önlemi)
    client.badCertificateCallback = (_, __, ___) => false;
    return client;
  }
}

/// Merkezi güvenlik servisi — root, debugger, hooking, tamper kontrolleri.
/// Native Android tarafıyla MethodChannel üzerinden iletişim kurar.
class SecurityService {
  static final SecurityService _instance = SecurityService._();
  factory SecurityService() => _instance;
  SecurityService._();

  static const _channel = MethodChannel('com.kuaflex.app/security');

  String? _expectedCertHash;
  bool _initialized = false;

  /// Uygulama başlangıcında çağır.
  /// [expectedCertHash]: Release APK'nın SHA-256 imza hash'i.
  /// İlk build'den sonra `getSecurityStatus()` ile hash'i alıp buraya yazın.
  Future<void> initialize({String? expectedCertHash}) async {
    if (_initialized) return;
    _initialized = true;
    _expectedCertHash = expectedCertHash;

    if (kReleaseMode) {
      await _runSecurityChecks();
    }
  }

  /// Tüm güvenlik durumunu native taraftan alır.
  Future<Map<String, dynamic>> getSecurityStatus() async {
    if (!Platform.isAndroid) return {'supported': false};
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getSecurityStatus');
      return result ?? {};
    } on PlatformException {
      return {};
    }
  }

  Future<void> _runSecurityChecks() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await getSecurityStatus();

      // Frida / Xposed tespiti → uygulama kapansın
      if (status['isHooked'] == true) {
        _terminate();
        return;
      }

      // Debugger bağlı → uygulama kapansın
      if (status['isDebuggerAttached'] == true) {
        _terminate();
        return;
      }

      // APK imza doğrulaması (yeniden imzalanmış APK tespiti)
      if (_expectedCertHash != null && _expectedCertHash!.isNotEmpty) {
        final currentHash = status['signingCertHash'] as String?;
        if (currentHash != null &&
            currentHash.isNotEmpty &&
            currentHash != _expectedCertHash) {
          _terminate();
          return;
        }
      }
    } catch (_) {
      // Kontrol hatası → kullanıcıyı kilitleme, sessizce devam et
    }
  }

  /// Periyodik güvenlik kontrolü — Timer ile çağrılır (5 dk arayla).
  Future<void> periodicCheck() async {
    if (!kReleaseMode || !Platform.isAndroid) return;
    try {
      final status = await getSecurityStatus();
      if (status['isHooked'] == true || status['isDebuggerAttached'] == true) {
        _terminate();
      }
    } catch (_) {}
  }

  void _terminate() {
    Future.delayed(const Duration(milliseconds: 100), () => exit(0));
  }
}
