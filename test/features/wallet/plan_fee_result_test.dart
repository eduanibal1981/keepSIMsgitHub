import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/wallet/model/plan_fee_result.dart';

/// `pay_plan_fee_from_wallet` refuses in two different ways: an insufficient
/// balance RAISEs (arriving as a PostgrestException), while UNAUTHORIZED, a
/// suspended account and a DEVICE_BLOCKED verdict return HTTP 200 with
/// `success: false` and no debit.
///
/// The client used to `await` the RPC and discard the body, so every refusal in
/// the second group read as a paid fee — which is how a Standard SIM line was
/// created without its $2.50 ever leaving the wallet. These cover the envelope
/// itself; [PlanFeeResult.isPaid] is the single question the callers that
/// create a paid line ask.
void main() {
  group('PlanFeeResult', () {
    test('a real debit is paid', () {
      final r = PlanFeeResult.fromRpc({
        'success': true,
        'amount': 2.50,
        'reference_id': 'planfee_8a07a25b_1785886702683653',
      });

      expect(r.isPaid, isTrue);
      expect(r.amount, 2.50);
      expect(r.referenceId, 'planfee_8a07a25b_1785886702683653');
      expect(r.isDeviceBlocked, isFalse);
    });

    test('a replayed reference id counts as paid, not as a reason to bill again', () {
      final r = PlanFeeResult.fromRpc({
        'success': true,
        'already_paid': true,
        'transaction_id': '6f1c9e3a-0000-4000-8000-000000000001',
        'amount': 2.50,
      });

      expect(r.isPaid, isTrue);
      expect(r.alreadyPaid, isTrue);
    });

    test('DEVICE_BLOCKED is not paid and keeps the server sentence', () {
      final r = PlanFeeResult.fromRpc({
        'success': false,
        'code': 'DEVICE_BLOCKED',
        'reason': 'velocity',
        'error':
            'This payment was stopped by a security check on this device. '
            'Contact support if this is a mistake.',
      });

      expect(r.isPaid, isFalse);
      expect(r.isDeviceBlocked, isTrue);
      expect(r.message, contains('security check'));
      // The threshold that was crossed stays out of the user-facing sentence.
      expect(r.message, isNot(contains('velocity')));
    });

    test('UNAUTHORIZED is not paid', () {
      final r = PlanFeeResult.fromRpc({
        'success': false,
        'error': 'UNAUTHORIZED',
      });

      expect(r.isPaid, isFalse);
      expect(r.message, 'UNAUTHORIZED');
    });

    test('a suspended account is not paid', () {
      final r = PlanFeeResult.fromRpc({
        'success': false,
        'error': 'Account is suspended.',
      });

      expect(r.isPaid, isFalse);
      expect(r.message, 'Account is suspended.');
    });

    test('falls back to reason when the refusal carried no error sentence', () {
      final r = PlanFeeResult.fromRpc({'success': false, 'reason': 'new_device'});

      expect(r.isPaid, isFalse);
      expect(r.message, 'new_device');
    });

    test('a refusal with no message at all still reads as unpaid', () {
      final r = PlanFeeResult.fromRpc({'success': false});

      expect(r.isPaid, isFalse);
      expect(r.message, isNotEmpty);
    });

    test('an unreadable body is a refusal, never an assumed debit', () {
      for (final body in <Object?>[null, 'OK', 42, <String>['success']]) {
        final r = PlanFeeResult.fromRpc(body);
        expect(r.isPaid, isFalse, reason: 'body: $body');
      }
    });

    test('a missing success key is not a success', () {
      // Absent is not true — the envelope always carries the key, so a body
      // without it did not come from a completed debit.
      expect(PlanFeeResult.fromRpc({'amount': 2.50}).isPaid, isFalse);
    });

    test('the string "true" is not a success', () {
      expect(PlanFeeResult.fromRpc({'success': 'true'}).isPaid, isFalse);
    });

    test('amount survives arriving as a numeric string', () {
      // jsonb numerics can deserialise as strings through PostgREST.
      expect(PlanFeeResult.fromRpc({'success': true, 'amount': '2.50'}).amount, 2.50);
    });
  });
}
