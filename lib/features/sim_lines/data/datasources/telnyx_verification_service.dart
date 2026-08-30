import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static const String _apiKey =
      'KEY01A049E00656B79B4314CFFBC7969C10_k9JM7HV9u4sB2MadneUT1M';
  static const String _messagingProfileId =
      '4001a054-0cfd-45aa-aed2-dd83279e7777';
  static const String _fromSender = 'KeepSIMs';

  /// Sends a lightweight verification ping SMS via Telnyx.
  /// Returns the Telnyx Message ID on success, or null on failure.
  static Future<String?> sendVerificationSms(String toPhoneNumber) async {
    final cleanPhone = toPhoneNumber.replaceAll(RegExp(r'\s+'), '');
    final url = Uri.parse('https://api.telnyx.com/v2/messages');

    final payload = jsonEncode({
      'from': _fromSender,
      'to': cleanPhone,
      'text': 'KeepSIMs line verification handshake: SIM Line confirmed active.',
      'messaging_profile_id': _messagingProfileId,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data']?['id'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the real-time Delivery Receipt (DLR) status of the sent SMS.
  static Future<TelnyxSmsResult> fetchMessageStatus(String messageId) async {
    final url = Uri.parse('https://api.telnyx.com/v2/messages/$messageId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dataMap = data['data'] as Map<String, dynamic>? ?? {};
        final toObj = (dataMap['to'] as List?)?.firstOrNull as Map<String, dynamic>?;
        final rawStatus = (toObj?['status'] as String? ??
                dataMap['status'] as String? ??
                '')
            .toLowerCase();
        final carrier = toObj?['carrier'] as String?;
        final sentAt = dataMap['sent_at'] as String?;
        final completedAt = dataMap['completed_at'] as String?;
        final errors = dataMap['errors'] as List? ?? [];

        if (errors.isNotEmpty) {
          final errDetail = errors.first?['detail'] as String? ?? 'Carrier rejected message';
          return TelnyxSmsResult(
            status: TelnyxSmsDeliveryStatus.failed,
            carrierName: carrier,
            errorMessage: errDetail,
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
      return const TelnyxSmsResult(status: TelnyxSmsDeliveryStatus.unknown);
    } catch (e) {
      return const TelnyxSmsResult(status: TelnyxSmsDeliveryStatus.unknown);
    }
  }
}
