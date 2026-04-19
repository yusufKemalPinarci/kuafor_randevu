import 'dart:convert';
import '../core/constants.dart';
import 'api_client.dart';

class ShopService {
  final String baseUrl = "${AppConstants.baseUrl}/api/shop";
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> createShop(Map<String, dynamic> data, {String? token}) async {
    final response = await _client.post('/api/shop', body: data);

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Dükkan oluşturulamadı. Lütfen bilgileri kontrol edip tekrar deneyin.");
    }
  }

  Future<Map<String, dynamic>> joinShop(String shopCode, String token) async {
    final response = await _client.post(
      '/api/shop/join',
      body: {"shopCode": shopCode},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? "Dükkana katılma başarısız oldu. Davet kodunu kontrol edin.");
    }
  }
}
