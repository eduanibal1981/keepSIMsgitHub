import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppService {
  /// Sends a WhatsApp message via the send-whatsapp-alert Edge Function.
  /// Does not expose any API secrets or VPS server URLs in the mobile client.
  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint('[WhatsAppService] Dispatching WhatsApp alert to $phone via Edge Function');

      final response = await supabase.functions.invoke(
        'send-whatsapp-alert',
        body: {
          'phone': phone,
          'message': message,
        },
      );

      debugPrint('[WhatsAppService] Response status: ${response.status}');
      debugPrint('[WhatsAppService] Response data: ${response.data}');

      if (response.status == 200) {
        final data = response.data;
        final success = data is Map ? (data['success'] == true) : false;
        debugPrint('[WhatsAppService] Parsed success: $success');
        return success;
      }
      return false;
    } catch (e) {
      debugPrint('[WhatsAppService] ERROR: $e');
      return false;
    }
  }
}
