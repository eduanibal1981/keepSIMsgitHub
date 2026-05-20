import 'dart:convert';
import 'package:http/http.dart' as http;

enum TwilioCallStatus {
  queued,
  ringing,
  inProgress,
  completed,
  busy,
  noAnswer,
  failed,
  canceled,
  unknown
}

class TwilioVerificationService {
  static const String _accountSid = 'ACb6df4af349214929b8fc9796c3b6490e';
  static const String _authToken = '0bf6edf400be1b8fef90eb0898dd5a97';
  static const String _fromNumber = '+18676755999';

  /// Triggers a phone call to the recipient and rejects it immediately on ring.
  /// Returns the call SID on success, or null on failure.
  static Future<String?> triggerMissedCall(String toPhoneNumber) async {
    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Calls.json',
    );

    final basicAuth = 'Basic ' +
        base64Encode(utf8.encode('$_accountSid:$_authToken'));

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': toPhoneNumber,
          'From': _fromNumber,
          'Twiml': '<Response><Reject/></Response>',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sid'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the status of a call by its SID.
  static Future<TwilioCallStatus> fetchCallStatus(String callSid) async {
    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Calls/$callSid.json',
    );

    final basicAuth = 'Basic ' +
        base64Encode(utf8.encode('$_accountSid:$_authToken'));

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final statusStr = (data['status'] as String? ?? '').toLowerCase();
        
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
      return TwilioCallStatus.unknown;
    }
  }

  /// Cancels an ongoing call to stop it from ringing.
  static Future<bool> cancelCall(String callSid) async {
    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Calls/$callSid.json',
    );

    final basicAuth = 'Basic ' +
        base64Encode(utf8.encode('$_accountSid:$_authToken'));

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'Status': 'canceled',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
