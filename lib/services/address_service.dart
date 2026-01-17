import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressService {
  final String baseUrl = "https://turkiyeapi.dev/api/v1";

  Future<List<dynamic>> getProvinces() async {
    final res = await http.get(Uri.parse("$baseUrl/provinces"));
    return res.statusCode == 200
        ? jsonDecode(res.body)["data"]
        : throw Exception("İller alınamadı");
  }

  Future<List<dynamic>> getDistricts(int provinceId) async {
    final res = await http.get(Uri.parse("$baseUrl/districts?provinceId=$provinceId"));
    return res.statusCode == 200
        ? jsonDecode(res.body)["data"]
        : throw Exception("İlçeler alınamadı");
  }

  Future<List<dynamic>> getNeighborhoods(int districtId) async {
    final res = await http.get(Uri.parse("$baseUrl/neighborhoods?districtId=$districtId"));
    return res.statusCode == 200
        ? jsonDecode(res.body)["data"]
        : throw Exception("Mahalleler alınamadı");
  }
}
