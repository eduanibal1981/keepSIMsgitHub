import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppService {
  // Use your machine's local IP if testing on a real device
  static const String _baseUrl = 'http://192.168.100.79:3000';

  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'message': message}),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
