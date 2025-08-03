class ShopModel {
  final String id;
  final String name;
  final String fullAddress;
  final String neighborhood;
  final String city;
  final String? phone;
  final String? adress;
  final String openingHour;
  final String closingHour;
  final List<String> workingDays;
  final String ownerId;             // Dükkan sahibinin kullanıcı ID’si
  final List<String> staffEmails;   // Çalışanların mail adresleri

  ShopModel({
    required this.id,
    required this.name,
    required this.fullAddress,
    required this.neighborhood,
    required this.city,
    this.phone,
    this.adress,
    required this.openingHour,
    required this.closingHour,
    required this.workingDays,
    required this.ownerId,
    required this.staffEmails,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      fullAddress: json['fullAddress'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone'],
      adress: json['adress'],
      openingHour: json['openingHour'] ?? '',
      closingHour: json['closingHour'] ?? '',
      workingDays: List<String>.from(json['workingDays'] ?? []),
      ownerId: json['ownerId'] ?? '',
      staffEmails: List<String>.from(json['staffEmails'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fullAddress': fullAddress,
      'neighborhood': neighborhood,
      'city': city,
      'phone': phone,
      'adress': adress,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'workingDays': workingDays,
      'ownerId': ownerId,
      'staffEmails': staffEmails,
    };
  }
}
