import 'package:flutter_test/flutter_test.dart';
import 'package:kuafor_randevu/models/user_model.dart';
import 'package:kuafor_randevu/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProvider Tests', () {
    late UserProvider userProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      userProvider = UserProvider();
    });

    test('setUser should update the user', () {
      final user = UserModel(id: '1', name: 'Test', email: 't@t.com', role: 'Customer');
      userProvider.setUser(user);
      expect(userProvider.user, user);
    });

    test('logout should clear the user', () async {
      final user = UserModel(id: '1', name: 'Test', email: 't@t.com', role: 'Customer');
      userProvider.setUser(user);
      await userProvider.logout();
      expect(userProvider.user, isNull);
    });
  });
}
