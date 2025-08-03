class Address {
  final String city;
  final String district;
  final String neighborhood;

  Address({
    required this.city,
    required this.district,
    required this.neighborhood,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'district': district,
      'neighborhood': neighborhood,
    };
  }

  Address copyWith({
    String? city,
    String? district,
    String? neighborhood,
  }) {
    return Address(
      city: city ?? this.city,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
    );
  }
}
