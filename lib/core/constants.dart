import 'package:flutter/foundation.dart';

class AppConstants {
  // ─── API Ortamı ────────────────────────────────────────────────────────────
  // Varsayılan davranış:
  //   debug build   → development (yerel sunucu)
  //   release build → production  (hosting sunucusu)
  //
  // Ortamı manuel geçersiz kılmak için:
  //   flutter run                                  → development (local)
  //   flutter run --dart-define=API_ENV=production → production  (hosting)
  //   flutter build apk                            → production  (otomatik)
  //
  // IMPORTANT: Release build şu şekilde yapılmalı (obfuscation + split debug):
  //   flutter build apk --release --obfuscate --split-debug-info=build/debug-info
  // ───────────────────────────────────────────────────────────────────────────

  static const String _apiEnv = String.fromEnvironment(
    'API_ENV',
    defaultValue: '',           // boşsa build moduna göre karar verilir
  );

  // Doğrudan URL override (özel staging/test adresleri için)
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
  static const String _urlOverride = String.fromEnvironment('API_BASE_URL');

  // Obfuscated production URL — `strings` komutuyla APK'dan çıkarılamaz.
  // --obfuscate ile birlikte getter adı da anlamsızlaşır.
  static String get _prodUrl => String.fromCharCodes(const [
    104, 116, 116, 112, 115, 58, 47, 47, 116, 114, 97, 118, 101, 108,
    119, 105, 116, 104, 115, 116, 117, 100, 101, 110, 116, 115, 46,
    120, 121, 122, 47, 107, 117, 97, 102, 108, 101, 120,
  ]);

  // Dev URL — release build'de kullanılmaz
  static String get _devUrl => kReleaseMode
      ? ''
      : String.fromCharCodes(const [
          104, 116, 116, 112, 58, 47, 47, 49, 48, 46, 48, 46, 50,
          46, 50, 58, 51, 48, 48, 48,
        ]);

  static String get baseUrl {
    if (_urlOverride.isNotEmpty) return _urlOverride;           // explicit URL
    if (_apiEnv == 'production')  return _prodUrl;              // --dart-define=API_ENV=production
    if (_apiEnv == 'development') return _devUrl;               // --dart-define=API_ENV=development
    return kReleaseMode ? _prodUrl : _devUrl;                   // akıllı varsayılan
  }

  static bool get isProduction =>
      _urlOverride.isEmpty && (_apiEnv == 'production' || (_apiEnv.isEmpty && kReleaseMode));
}
