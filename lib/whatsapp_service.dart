import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppService {
  static const String _apiSecret = 'super_secret_alerts_key';

  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    String? baseUrl;
    try {
      final supabase = Supabase.instance.client;
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      
      // 1. Try country specific WhatsApp Server
      final response = await supabase
          .from('countries')
          .select('dialing_code, whatsapp_server_url');

      for (final row in response as List) {
        final code = (row['dialing_code'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (code.isNotEmpty && cleanPhone.startsWith(code)) {
          final customUrl = row['whatsapp_server_url'] as String?;
          if (customUrl != null && customUrl.isNotEmpty) {
            baseUrl = customUrl;
            break;
          }
        }
      }

      // 2. Fallback to default WhatsApp Server from system_configs
      if (baseUrl == null || baseUrl.isEmpty) {
        final configResponse = await supabase
            .from('system_configs')
            .select('config_value')
            .eq('config_key', 'DEFAULT_WHATSAPP_SERVER_URL')
            .maybeSingle();

        if (configResponse != null) {
          baseUrl = configResponse['config_value'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[WhatsAppService] Dynamic URL lookup failed: $e');
    }

    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('[WhatsAppService] No WhatsApp Server configured.');
      return false;
    }

    try {
      if (!baseUrl.endsWith('/send')) {
        baseUrl = baseUrl.endsWith('/') ? '${baseUrl}send' : '$baseUrl/send';
      }
      
      debugPrint('[WhatsAppService] Sending to $phone via $baseUrl');
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _apiSecret,
            },
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
