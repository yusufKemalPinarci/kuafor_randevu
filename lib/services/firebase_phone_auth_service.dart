import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebasePhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;

  /// Telefona doğrulama SMS'i gönderir.
  /// [onCodeSent] — SMS gönderildiğinde çağrılır.
  /// [onError] — hata durumunda çağrılır.
  /// [onAutoVerified] — Android auto-retrieve ile otomatik doğrulanırsa çağrılır.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Android otomatik doğrulama
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          // Gerçek hata kodunu debug modunda göster — production'da gizlenir
          if (kDebugMode) {
            debugPrint('[PhoneAuth] verificationFailed → code: ${e.code} | msg: ${e.message}');
          }

          String message;
          final msg = e.message ?? '';
          if (msg.contains('BILLING_NOT_ENABLED')) {
            message = 'Telefon doğrulama şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
          } else {
            switch (e.code) {
              case 'invalid-phone-number':
                message = 'Geçersiz telefon numarası.';
                break;
              case 'too-many-requests':
                message = 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
                break;
              case 'app-not-authorized':
              case 'app-not-verified':
                // Gerçek cihazda debug APK Play Integrity'yi geçemez.
                // Çözüm: Firebase Console → Authentication → Sign-in method →
                // Phone → "Phone numbers for testing" bölümüne test numarası ekle.
                message = kDebugMode
                    ? 'Test modunda SMS gönderilemedi. Firebase Console\'a test numarası ekleyin.'
                    : 'SMS gönderilemedi. Lütfen daha sonra tekrar deneyin.';
                break;
              case 'missing-client-identifier':
              case 'missing-app-credential':
                message = 'Uygulama doğrulaması başarısız. Lütfen tekrar deneyin.';
                break;
              case 'quota-exceeded':
                message = 'SMS kotası doldu. Lütfen daha sonra tekrar deneyin.';
                break;
              default:
                message = 'SMS gönderilemedi. Lütfen daha sonra tekrar deneyin.';
            }
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PhoneAuth] unexpected error: $e');
      onError('SMS gönderilemedi. Lütfen daha sonra tekrar deneyin.');
    }
  }

  /// Kullanıcının girdiği SMS kodunu doğrular.
  /// Başarılıysa [UserCredential] döner, hatalıysa exception fırlatır.
  Future<UserCredential> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      throw Exception('Lütfen önce telefon numaranıza SMS kodu gönderin.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Credential ile doğrulama (auto-verify durumu için).
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  /// Doğrulanmış kullanıcıyı çıkış yaptırır (guest flow - kalıcı session istemiyoruz).
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
