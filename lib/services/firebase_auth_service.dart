import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ────────────────────────────────────────────────────────────
  // Email / Password — Giriş
  // ────────────────────────────────────────────────────────────

  Future<({UserModel user, String? error})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 1) Firebase ile giriş
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // 2) Backend senkronizasyon
      return await _syncWithBackend(credential.user!);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('Firebase signIn error: ${e.code}');

      // Kullanıcı Firebase'de yok ama backend'de olabilir (eski kullanıcı)
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return await _legacyLogin(email: email.trim(), password: password);
      }
      return (user: _empty, error: _mapFirebaseError(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('signInWithEmail error: $e');
      return (user: _empty, error: _friendlyError(e));
    }
  }

  // ────────────────────────────────────────────────────────────
  // Email / Password — Kayıt
  // ────────────────────────────────────────────────────────────

  Future<({UserModel user, String? error})> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();
      return await _syncWithBackend(_auth.currentUser!, role: role);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('Firebase register error: ${e.code}');
      return (user: _empty, error: _mapFirebaseError(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('registerWithEmail error: $e');
      return (user: _empty, error: _friendlyError(e));
    }
  }

  // ────────────────────────────────────────────────────────────
  // Google Sign-In
  // ────────────────────────────────────────────────────────────

  Future<({UserModel user, String? error, bool needsRole})> signInWithGoogle({
    String? role,
  }) async {
    try {
      // 1) Google Sign-In
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return (user: _empty, error: null, needsRole: false);
      }

      // 2) Google auth token al
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3) Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(credential);

      // 4) Backend senkronizasyon
      final result = await _syncWithBackend(userCredential.user!, role: role);

      if (result.error == 'NEEDS_ROLE') {
        return (user: _empty, error: null, needsRole: true);
      }

      return (user: result.user, error: result.error, needsRole: false);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('Firebase Google auth error: ${e.code}');
      return (user: _empty, error: _mapFirebaseError(e.code), needsRole: false);
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('Google sign-in platform error: ${e.code}');
      final msg = _mapPlatformError(e.code);
      return (user: _empty, error: msg, needsRole: false);
    } catch (e) {
      if (kDebugMode) debugPrint('signInWithGoogle error: $e');
      return (user: _empty, error: _friendlyError(e), needsRole: false);
    }
  }

  // ────────────────────────────────────────────────────────────
  // Şifre İşlemleri
  // ────────────────────────────────────────────────────────────

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      if (kDebugMode) debugPrint('Password reset email sent to: ${email.trim()}');
      return null;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('sendPasswordResetEmail error: ${e.code} | ${e.message}');
      return _mapFirebaseError(e.code);
    } catch (e) {
      if (kDebugMode) debugPrint('sendPasswordResetEmail unexpected error: $e');
      return _friendlyError(e);
    }
  }

  Future<String?> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      }
      if (user.emailVerified) {
        return 'E-posta adresiniz zaten doğrulanmış.';
      }
      await user.sendEmailVerification();
      if (kDebugMode) debugPrint('Email verification sent to: ${user.email}');
      return null;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('sendEmailVerification error: ${e.code} | ${e.message}');
      if (e.code == 'too-many-requests') {
        return 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
      }
      return _mapFirebaseError(e.code);
    } catch (e) {
      if (kDebugMode) debugPrint('sendEmailVerification unexpected error: $e');
      return _friendlyError(e);
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      }

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Mevcut şifreniz yanlış.';
      }
      return _mapFirebaseError(e.code);
    } catch (e) {
      return 'Şifre değiştirme sırasında hata oluştu.';
    }
  }

  // ────────────────────────────────────────────────────────────
  // Çıkış
  // ────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────
  // Backend senkronizasyonu — Firebase ID Token ile
  // ────────────────────────────────────────────────────────────

  Future<({UserModel user, String? error})> _syncWithBackend(
    User firebaseUser, {
    String? role,
  }) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      if (kDebugMode) debugPrint('Backend sync: ${AppConstants.baseUrl}/api/user/firebase-auth');

      final body = <String, dynamic>{'firebaseIdToken': idToken};
      if (role != null) body['role'] = role;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/user/firebase-auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) debugPrint('Backend response: ${response.statusCode}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['token'] != null) {
        final user = UserModel.fromJson({
          ...data['user'] as Map<String, dynamic>,
          'jwtToken': data['token'],
          'refreshToken': data['refreshToken'] ?? '',
        });
        return (user: user, error: null);
      }

      if (data['needsRole'] == true) {
        return (user: _empty, error: 'NEEDS_ROLE');
      }

      return (
        user: _empty,
        error: data['error'] as String? ?? 'Giriş başarısız.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('Backend SocketException: $e');
      return (user: _empty, error: 'Sunucuya bağlanılamıyor. Backend çalışıyor mu?');
    } on http.ClientException catch (e) {
      if (kDebugMode) debugPrint('Backend ClientException: $e');
      return (user: _empty, error: 'Sunucuya bağlanılamıyor. Lütfen tekrar deneyin.');
    } catch (e) {
      if (kDebugMode) debugPrint('_syncWithBackend error: $e');
      return (user: _empty, error: 'Sunucu bağlantı hatası: ${e.runtimeType}');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Legacy Login — Eski backend API (Firebase'de olmayan kullanıcılar)
  // ────────────────────────────────────────────────────────────

  Future<({UserModel user, String? error})> _legacyLogin({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) debugPrint('Legacy login fallback: $email');
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/api/user/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['token'] != null) {
        // Eski kullanıcı giriş yaptı — arka planda Firebase hesabı oluştur
        _migrateToFirebase(email, password);

        final user = UserModel.fromJson({
          ...data['user'] as Map<String, dynamic>,
          'jwtToken': data['token'],
          'refreshToken': data['refreshToken'] ?? '',
        });
        return (user: user, error: null);
      }

      return (
        user: _empty,
        error: data['error'] as String? ?? 'E-posta veya şifre hatalı.',
      );
    } on SocketException {
      return (user: _empty, error: 'Sunucuya bağlanılamıyor. Backend çalışıyor mu?');
    } catch (e) {
      if (kDebugMode) debugPrint('legacyLogin error: $e');
      return (user: _empty, error: 'E-posta veya şifre hatalı.');
    }
  }

  /// Eski kullanıcıyı arka planda Firebase Auth'a geçirir.
  void _migrateToFirebase(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) debugPrint('Kullanıcı Firebase\'e migrate edildi: $email');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Zaten var, sorun yok
        try {
          await _auth.signInWithEmailAndPassword(email: email, password: password);
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────
  // Yardımcılar
  // ────────────────────────────────────────────────────────────

  static final _empty = UserModel(id: '', name: '', email: '', role: '');

  String _friendlyError(Object e) {
    if (e is SocketException) {
      return 'İnternet bağlantınızı kontrol edin.';
    }
    if (e is HttpException) {
      return 'Sunucuya bağlanılamadı. Lütfen daha sonra tekrar deneyin.';
    }
    if (e is FormatException) {
      return 'Sunucudan geçersiz yanıt geldi.';
    }
    if (kDebugMode) debugPrint('Unhandled error type: ${e.runtimeType}');
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  String _mapPlatformError(String code) {
    switch (code) {
      case 'sign_in_failed':
        return 'Google ile giriş başarısız oldu. Lütfen tekrar deneyin veya farklı bir yöntem kullanın.';
      case 'sign_in_canceled':
        return 'Google girişi iptal edildi.';
      case 'network_error':
        return 'İnternet bağlantınızı kontrol edin.';
      default:
        return 'Google ile giriş sırasında bir sorun oluştu. Lütfen tekrar deneyin.';
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalıdır.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi şu an kullanılamıyor.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta başka bir giriş yöntemiyle kayıtlı.';
      default:
        return 'Bir sorun oluştu. Lütfen tekrar deneyin.';
    }
  }
}
