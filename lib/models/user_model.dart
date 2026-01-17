import 'package:kuafor_randevu/models/shop_model.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

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
  //final DateTime? tokenExpiry;
  final String? shopId;
  final ShopModel? selectedShop;

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
    //this.tokenExpiry,
    this.shopId,
    this.selectedShop,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? isEmailVerified,
    String? phone,
    bool? isPhoneVerified,
    String? avatarUrl,
    String? jwtToken,
    DateTime? tokenExpiry,
    String? shopId,
    ShopModel? selectedShop,
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
     // tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      shopId: shopId ?? this.shopId,
      selectedShop: selectedShop ?? this.selectedShop,
    );
  }



  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      phone: json['phone'] ?? '',
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      avatarUrl: json['avatarUrl'] ?? '',
      jwtToken: json['jwtToken'] ?? '',
     // tokenExpiry: json['tokenExpiry'] != null
       //   ? DateTime.tryParse(json['tokenExpiry'])
         // : null,
      shopId: json['shopId'] ?? '',
    );
  }



  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isEmailVerified': isEmailVerified,
      'phone': phone,
      'isPhoneVerified': isPhoneVerified,
      'avatarUrl': avatarUrl,
      'jwtToken': jwtToken,
      //'tokenExpiry': tokenExpiry?.toIso8601String(),
      'shopId': shopId,
    };
  }

  /// 🔐 Token geçerliliğini güvenli kontrol et
  bool get isTokenValid {
    if (jwtToken == null || jwtToken!.isEmpty) {
      print('⚠️ Token boş veya null');
      return false;
    }

    try {
      if (JwtDecoder.isExpired(jwtToken!)) {
        print('❌ Token süresi dolmuş');
        return false;
      } else {
        final expiry = JwtDecoder.getExpirationDate(jwtToken!);
        print('✅ Token geçerli. Bitiş tarihi: $expiry');
        return true;
      }
    } catch (e) {
      print('⚠️ Invalid token format: $e');
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
