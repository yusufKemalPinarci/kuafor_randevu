import 'package:flutter/foundation.dart';
import 'package:kuaflex/models/shop_model.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class NotificationPreferences {
  final bool push;
  final bool email;
  final bool sms;

  // Push alt tercihleri
  final bool pushNewAppointment;
  final bool pushCancellation;
  final bool pushReminder;

  // Email alt tercihleri
  final bool emailDailySummary;
  final bool emailReminder;

  // SMS alt tercihleri
  final bool smsNewAppointment;
  final bool smsReminder;

  // Müşteri bildirim tercihleri
  final bool customerPushReminder;
  final bool customerPushStatusChange;
  final bool customerEmailReminder;
  final bool customerSmsReminder;

  NotificationPreferences({
    this.push = true,
    this.email = false,
    this.sms = false,
    this.pushNewAppointment = true,
    this.pushCancellation = true,
    this.pushReminder = true,
    this.emailDailySummary = true,
    this.emailReminder = true,
    this.smsNewAppointment = true,
    this.smsReminder = true,
    this.customerPushReminder = true,
    this.customerPushStatusChange = true,
    this.customerEmailReminder = true,
    this.customerSmsReminder = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      push: json['push'] ?? true,
      email: json['email'] ?? false,
      sms: json['sms'] ?? false,
      pushNewAppointment: json['pushNewAppointment'] ?? true,
      pushCancellation: json['pushCancellation'] ?? true,
      pushReminder: json['pushReminder'] ?? true,
      emailDailySummary: json['emailDailySummary'] ?? true,
      emailReminder: json['emailReminder'] ?? true,
      smsNewAppointment: json['smsNewAppointment'] ?? true,
      smsReminder: json['smsReminder'] ?? true,
      customerPushReminder: json['customerPushReminder'] ?? true,
      customerPushStatusChange: json['customerPushStatusChange'] ?? true,
      customerEmailReminder: json['customerEmailReminder'] ?? true,
      customerSmsReminder: json['customerSmsReminder'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'push': push,
    'email': email,
    'sms': sms,
    'pushNewAppointment': pushNewAppointment,
    'pushCancellation': pushCancellation,
    'pushReminder': pushReminder,
    'emailDailySummary': emailDailySummary,
    'emailReminder': emailReminder,
    'smsNewAppointment': smsNewAppointment,
    'smsReminder': smsReminder,
    'customerPushReminder': customerPushReminder,
    'customerPushStatusChange': customerPushStatusChange,
    'customerEmailReminder': customerEmailReminder,
    'customerSmsReminder': customerSmsReminder,
  };

  NotificationPreferences copyWith({
    bool? push,
    bool? email,
    bool? sms,
    bool? pushNewAppointment,
    bool? pushCancellation,
    bool? pushReminder,
    bool? emailDailySummary,
    bool? emailReminder,
    bool? smsNewAppointment,
    bool? smsReminder,
    bool? customerPushReminder,
    bool? customerPushStatusChange,
    bool? customerEmailReminder,
    bool? customerSmsReminder,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      pushNewAppointment: pushNewAppointment ?? this.pushNewAppointment,
      pushCancellation: pushCancellation ?? this.pushCancellation,
      pushReminder: pushReminder ?? this.pushReminder,
      emailDailySummary: emailDailySummary ?? this.emailDailySummary,
      emailReminder: emailReminder ?? this.emailReminder,
      smsNewAppointment: smsNewAppointment ?? this.smsNewAppointment,
      smsReminder: smsReminder ?? this.smsReminder,
      customerPushReminder: customerPushReminder ?? this.customerPushReminder,
      customerPushStatusChange: customerPushStatusChange ?? this.customerPushStatusChange,
      customerEmailReminder: customerEmailReminder ?? this.customerEmailReminder,
      customerSmsReminder: customerSmsReminder ?? this.customerSmsReminder,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool? isEmailVerified;
  final String? phone;
  final bool? isPhoneVerified;
  final String? avatarUrl;
  final String?  jwtToken;
  final String? refreshToken;
  //final DateTime? tokenExpiry;
  final String? shopId;
  final ShopModel? selectedShop;
  final NotificationPreferences? notificationPreferences;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isEmailVerified = false,
    this.phone = '',
    this.isPhoneVerified = false,
    this.avatarUrl,
    this.jwtToken,
    this.refreshToken,
    //this.tokenExpiry,
    this.shopId,
    this.selectedShop,
    this.notificationPreferences,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? isEmailVerified,
    String? phone,
    bool? isPhoneVerified,
    String? avatarUrl,
    String? jwtToken,
    String? refreshToken,
    DateTime? tokenExpiry,
    String? shopId,
    ShopModel? selectedShop,
    NotificationPreferences? notificationPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      phone: phone ?? this.phone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      jwtToken: jwtToken ?? this.jwtToken,
      refreshToken: refreshToken ?? this.refreshToken,
     // tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      shopId: shopId ?? this.shopId,
      selectedShop: selectedShop ?? this.selectedShop,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }



  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      phone: json['phone'] ?? '',
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      avatarUrl: json['avatarUrl'] ?? '',
      jwtToken: json['jwtToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      shopId: json['shopId'] ?? '',
      notificationPreferences: json['notificationPreferences'] != null
          ? NotificationPreferences.fromJson(json['notificationPreferences'])
          : null,
    );
  }



  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'isEmailVerified': isEmailVerified,
      'phone': phone,
      'isPhoneVerified': isPhoneVerified,
      'avatarUrl': avatarUrl,
      'jwtToken': jwtToken,
      'refreshToken': refreshToken,
      //'tokenExpiry': tokenExpiry?.toIso8601String(),
      'shopId': shopId,
      'notificationPreferences': notificationPreferences?.toJson(),
    };
  }

  /// 🔐 Token geçerliliğini güvenli kontrol et
  bool get isTokenValid {
    if (jwtToken == null || jwtToken!.isEmpty) {
      return false;
    }

    try {
      if (JwtDecoder.isExpired(jwtToken!)) {
        return false;
      } else {
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Invalid token format: $e');
      return false;
    }
  }

  bool isJwtValid(String token) {
    return !JwtDecoder.isExpired(token);
  }

  DateTime getExpiryDate(String token) {
    return JwtDecoder.getExpirationDate(token);
  }




}
