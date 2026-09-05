import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TelnyxSmsDeliveryStatus {
  queued,
  sending,
  sent,
  delivered,
  undelivered,
  failed,
  unknown,
}

class TelnyxSmsResult {
  final TelnyxSmsDeliveryStatus status;
  final String? carrierName;
  final String? errorMessage;

  const TelnyxSmsResult({
    required this.status,
    this.carrierName,
    this.errorMessage,
  });
}

class TelnyxVerificationService {
  /// Sends a lightweight verification ping SMS via Edge Function.
  /// Returns the Telnyx Message ID on success, or null on failure.
  static Future<String?> sendVerificationSms(String toPhoneNumber) async {
    final cleanPhone = toPhoneNumber.replaceAll(RegExp(r'\s+'), '');

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'telnyx_send_sms',
          'phoneNumber': cleanPhone,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return data['messageId'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[TelnyxVerificationService] sendVerificationSms error: $e');
      return null;
    }
  }

  /// Fetches the real-time Delivery Receipt (DLR) status of the sent SMS via Edge Function.
  static Future<TelnyxSmsResult> fetchMessageStatus(String messageId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'telnyx_fetch_status',
          'messageId': messageId,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          final rawStatus = (data['status'] as String? ?? '').toLowerCase();
          final carrier = data['carrier'] as String?;
          final errorMsg = data['errorMessage'] as String?;
          final sentAt = data['sentAt'] as String?;
          final completedAt = data['completedAt'] as String?;

          if (errorMsg != null && errorMsg.isNotEmpty) {
            return TelnyxSmsResult(
              status: TelnyxSmsDeliveryStatus.failed,
              carrierName: carrier,
              errorMessage: errorMsg,
            );
          }

          if (rawStatus == 'delivered' || completedAt != null) {
            return TelnyxSmsResult(
              status: TelnyxSmsDeliveryStatus.delivered,
              carrierName: carrier,
            );
          }

          if (rawStatus == 'sent' || sentAt != null || rawStatus == 'sending') {
            return TelnyxSmsResult(
              status: TelnyxSmsDeliveryStatus.sent,
              carrierName: carrier,
            );
          }

          if (rawStatus == 'undelivered') {
            return TelnyxSmsResult(
              status: TelnyxSmsDeliveryStatus.undelivered,
              carrierName: carrier,
            );
          }

          if (rawStatus == 'failed') {
            return TelnyxSmsResult(
              status: TelnyxSmsDeliveryStatus.failed,
              carrierName: carrier,
            );
          }

          return TelnyxSmsResult(
            status: TelnyxSmsDeliveryStatus.queued,
            carrierName: carrier,
          );
        }
      }
      return const TelnyxSmsResult(status: TelnyxSmsDeliveryStatus.unknown);
    } catch (e) {
      debugPrint('[TelnyxVerificationService] fetchMessageStatus error: $e');
      return const TelnyxSmsResult(status: TelnyxSmsDeliveryStatus.unknown);
    }
  }
}
