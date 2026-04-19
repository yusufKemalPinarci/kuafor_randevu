import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

/// Arka plan mesaj handler'ı — top-level function olmalı
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda gelen mesajlar Android'de otomatik bildirim gösterir
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiClient _client = ApiClient();

  /// Bildirime tıklandığında çağrılacak callback
  void Function(String? appointmentId)? onNotificationTap;

  /// Android bildirim kanalı
  static const _androidChannel = AndroidNotificationChannel(
    'kuaflex_appointments',
    'Randevu Bildirimleri',
    description: 'Randevu hatırlatmaları ve durum güncellemeleri',
    importance: Importance.high,
    playSound: true,
  );

  /// Servisi başlat — main() veya splash'ta bir kere çağrılmalı
  Future<void> initialize() async {
    // 1. İzin iste
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) debugPrint('Bildirim izni: ${settings.authorizationStatus}');

    // 2. Android bildirim kanalını oluştur
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // 3. Local notifications başlat
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    // 4. Foreground mesajları dinle
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 5. Bildirime tıklanarak uygulamanın açılması
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data['appointmentId']);
    });

    // 6. Uygulama kapalıyken bildirime tıklanıp açıldıysa
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data['appointmentId']);
    }
  }

  /// FCM token'ını alır
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Token değişikliğini dinler
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// FCM token'ını backend'e gönderir
  Future<void> sendTokenToServer(String fcmToken, String jwtToken) async {
    try {
      await _client.post(
        '/api/user/fcm-token',
        body: {'fcmToken': fcmToken},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token gönderilemedi: $e');
    }
  }

  /// Çıkışta FCM token'ını backend'den siler
  Future<void> removeTokenFromServer(String jwtToken) async {
    try {
      final fcmToken = await getToken();
      if (fcmToken == null) return;

      await _client.delete(
        '/api/user/fcm-token',
        body: {'fcmToken': fcmToken},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM token silinemedi: $e');
    }
  }

  /// Foreground'da gelen mesajı local notification olarak göster
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final appointmentId = message.data['appointmentId'] as String?;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: appointmentId,
    );
  }

  void _handleNotificationTap(String? appointmentId) {
    if (appointmentId != null && onNotificationTap != null) {
      onNotificationTap!(appointmentId);
    }
  }
}
