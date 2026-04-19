import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Anti-reverse-engineering: HMAC request signing ve string obfuscation.
class CryptoUtils {
  CryptoUtils._();

  /// Karakter kodları listesinden string oluşturur.
  /// APK'dan `strings` komutuyla çıkarılamaz.
  static String _s(List<int> c) => String.fromCharCodes(c);

  /// HMAC-SHA256 imzası üretir.
  static String hmacSha256(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(data)).toString();
  }

  /// SHA-256 hash.
  static String sha256Hash(String data) =>
      sha256.convert(utf8.encode(data)).toString();

  /// Kriptografik rastgele nonce üretir (hex).
  static String generateNonce([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Obfuscated HMAC secret — char codes olarak saklanır.
  // Sunucu tarafında aynı değer .env dosyasına eklenmeli:
  //   HMAC_SECRET=a3f8c2e91b7d054f6a2e8c3b9d1f7042
  static String get _k => _s(const [
    97, 51, 102, 56, 99, 50, 101, 57, 49, 98, 55, 100, 48, 53, 52, 102,
    54, 97, 50, 101, 56, 99, 51, 98, 57, 100, 49, 102, 55, 48, 52, 50,
  ]);

  /// API isteği için HMAC imza header'ları üretir.
  /// Server tarafında aynı algoritma ile doğrulanır.
  static Map<String, String> signRequest({
    required String method,
    required String path,
    String body = '',
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = generateNonce();
    final bodyHash = sha256Hash(body);
    final data = '$timestamp:$nonce:$method:$path:$bodyHash';
    final signature = hmacSha256(_k, data);

    return {
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
    };
  }
}
