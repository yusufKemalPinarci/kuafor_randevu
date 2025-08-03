import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shop_model.dart';
import '../models/user_model.dart';

class UserService {
  final String baseUrl;

  UserService({required this.baseUrl});

  Future<UserModel?> selectShop({
    required String jwtToken,
    required String shopId,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/select-shop');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      },
      body: jsonEncode({'shopId': shopId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserModel.fromJson({
        ...data['user'],
        'jwtToken': jwtToken, // token değişmemişse aynı token
      });
    } else {
      print('API Error: ${response.body}');
      return null;
    }
  }
}
