class ShopModel {
  final String id;
  final String name;
  final String fullAddress;
  final String neighborhood;
  final String city; // province name olacak
  final String? phone;
  final String? adress; // eski alan korunuyor ama fullAddress ile aynı olabilir
  final String? district;      // district name
  final String openingHour;
  final String closingHour;
  final List<String> workingDays;
  final String ownerId;
  final String? shopCode;
  final bool autoConfirmAppointments;

  ShopModel({
    required this.id,
    required this.name,
    required this.fullAddress,
    required this.neighborhood,
    required this.city,
    this.phone,
    this.adress,
    this.district,
    required this.openingHour,
    required this.closingHour,
    required this.workingDays,
    required this.ownerId,
    this.shopCode,
    this.autoConfirmAppointments = false,
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
      district: json['district'],
      openingHour: json['openingHour'] ?? '',
      closingHour: json['closingHour'] ?? '',
      workingDays: List<String>.from(json['workingDays'] ?? []),
      ownerId: json['ownerId'] ?? '',
      shopCode: json['shopCode'] ?? '',
      autoConfirmAppointments: json['autoConfirmAppointments'] ?? false,
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
      'district': district,
      'openingHour': openingHour,
      'closingHour': closingHour,
      'workingDays': workingDays,
      'ownerId': ownerId,
      'shopCode': shopCode,
      'autoConfirmAppointments': autoConfirmAppointments,
    };
  }
}
