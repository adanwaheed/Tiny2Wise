import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator: 10.0.2.2
  // Real device: use your PC IP like 192.168.x.x
  static const String baseUrl = "http://10.0.2.2:3000";

  static Future<void> signup({
    required String role, // "parent" or "teacher"
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "role": role,
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body);
  }
}
