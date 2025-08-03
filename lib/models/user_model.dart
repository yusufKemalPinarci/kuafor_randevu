import 'package:kuafor_randevu/models/shop_model.dart';

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

  /*bool get isTokenValid {
    if (tokenExpiry == null) return false;
    return tokenExpiry!.isAfter(DateTime.now());
  }*/


}
