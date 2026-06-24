import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WhatsAppService {
  // Production VPS Server
  static const String _baseUrl = 'http://169.40.15.242:3000';

  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      debugPrint('[WhatsAppService] Sending to $phone via $_baseUrl/send');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'message': message}),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint('[WhatsAppService] Response status: ${response.statusCode}');
      debugPrint('[WhatsAppService] Response body: ${response.body}');
      final data = jsonDecode(response.body);
      final success = data['success'] == true;
      debugPrint('[WhatsAppService] Parsed success: $success');
      return success;
    } catch (e) {
      debugPrint('[WhatsAppService] ERROR: $e');
      return false;
    }
  }
}
