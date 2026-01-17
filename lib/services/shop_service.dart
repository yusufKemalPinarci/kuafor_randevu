import 'dart:convert';
import '../core/constants.dart';
import 'package:http/http.dart' as http;

class ShopService {
  final String baseUrl = "${AppConstants.baseUrl}/api/shop";

  Future<Map<String, dynamic>> createShop(Map<String, dynamic> data, {String? token}) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      // Backend'in döndürdüğü cevabı Map olarak parse et
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Dükkan oluşturulamadı: ${response.body}");
    }
  }
}
