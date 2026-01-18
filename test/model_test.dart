import 'package:flutter_test/flutter_test.dart';
import 'package:kuafor_randevu/models/user_model.dart';
import 'package:kuafor_randevu/models/shop_model.dart';

void main() {
  group('Model Tests', () {
    test('UserModel.fromJson should parse correctly', () {
      final json = {
        '_id': '123',
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'Customer',
        'shopId': 'shop123',
        'jwtToken': 'token123'
      };

      final user = UserModel.fromJson(json);

      expect(user.id, '123');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.role, 'Customer');
      expect(user.shopId, 'shop123');
      expect(user.jwtToken, 'token123');
    });

    test('ShopModel.fromJson should parse correctly', () {
      final json = {
        '_id': 'shop123',
        'name': 'Test Shop',
        'fullAddress': 'Address 123',
        'neighborhood': 'Neighbour',
        'city': 'City',
        'openingHour': '09:00',
        'closingHour': '18:00',
        'workingDays': ['Monday', 'Tuesday'],
        'ownerId': 'owner123',
        'staffEmails': ['staff@example.com']
      };

      final shop = ShopModel.fromJson(json);

      expect(shop.id, 'shop123');
      expect(shop.name, 'Test Shop');
      expect(shop.openingHour, '09:00');
      expect(shop.workingDays, contains('Monday'));
      expect(shop.staffEmails, contains('staff@example.com'));
    });
   group('UserModel JSON handling', () {
    test('UserModel.toJson should work correctly', () {
      final user = UserModel(
        id: '1',
        name: 'John',
        email: 'john@doe.com',
        role: 'Barber',
        shopId: 's1'
      );
      final json = user.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'John');
    });
  });
  });
}
