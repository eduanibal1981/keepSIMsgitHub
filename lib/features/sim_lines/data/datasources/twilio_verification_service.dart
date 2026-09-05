import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TwilioCallStatus {
  queued,
  ringing,
  inProgress,
  completed,
  busy,
  noAnswer,
  failed,
  canceled,
  unknown,
}

class TwilioVerificationService {
  /// Triggers a phone call to the recipient and rejects it immediately on ring via Edge Function.
  /// Returns the call SID on success, or null on failure.
  static Future<String?> triggerMissedCall(String toPhoneNumber) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'twilio_trigger_call',
          'phoneNumber': toPhoneNumber,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return data['sid'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[TwilioVerificationService] triggerMissedCall error: $e');
      return null;
    }
  }

  /// Fetches the status of a call by its SID via Edge Function.
  static Future<TwilioCallStatus> fetchCallStatus(String callSid) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'twilio_fetch_status',
          'callSid': callSid,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        final statusStr = ((data is Map ? data['status'] : null) as String? ?? '').toLowerCase();

        switch (statusStr) {
          case 'queued':
            return TwilioCallStatus.queued;
          case 'ringing':
            return TwilioCallStatus.ringing;
          case 'in-progress':
            return TwilioCallStatus.inProgress;
          case 'completed':
            return TwilioCallStatus.completed;
          case 'busy':
            return TwilioCallStatus.busy;
          case 'no-answer':
            return TwilioCallStatus.noAnswer;
          case 'failed':
            return TwilioCallStatus.failed;
          case 'canceled':
            return TwilioCallStatus.canceled;
          default:
            return TwilioCallStatus.unknown;
        }
      }
      return TwilioCallStatus.unknown;
    } catch (e) {
      debugPrint('[TwilioVerificationService] fetchCallStatus error: $e');
      return TwilioCallStatus.unknown;
    }
  }

  /// Cancels an ongoing call via Edge Function to stop it from ringing.
  static Future<bool> cancelCall(String callSid) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'liveness-verification',
        body: {
          'action': 'twilio_cancel_call',
          'callSid': callSid,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        return data is Map && data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[TwilioVerificationService] cancelCall error: $e');
      return false;
    }
  }
}
