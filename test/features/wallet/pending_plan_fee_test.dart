import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/wallet/model/pending_plan_fee.dart';

/// The plan fee is debited before the SIM line row exists, and the two are
/// separate round-trips. A duplicate phone number, an offline queue, an RLS
/// refusal or the app being killed while backgrounded for PayPal all leave the
/// user charged with nothing to show — and, before this, billed again on the
/// next attempt.
///
/// Persisting the reference id makes the retry replay it, and
/// `pay_plan_fee_from_wallet` answers a replayed reference with
/// `already_paid: true` and no second debit.
void main() {
  PendingPlanFee fee({DateTime? chargedAt}) => PendingPlanFee(
    referenceId: 'planfee_1785889298521467',
    amount: 2.50,
    chargedAt: chargedAt ?? DateTime.now(),
  );

  group('PendingPlanFee', () {
    test('round-trips through the cache', () {
      final restored = PendingPlanFee.fromJson(fee().toJson());

      expect(restored, isNotNull);
      expect(restored!.referenceId, 'planfee_1785889298521467');
      expect(restored.amount, 2.50);
    });

    test('a fresh fee is still spendable', () {
      expect(fee().isExpired, isFalse);
      expect(
        fee(
          chargedAt: DateTime.now().subtract(const Duration(hours: 23)),
        ).isExpired,
        isFalse,
      );
    });

    test('a fee older than a day is dropped rather than replayed', () {
      // Dropping one costs a single re-charge; replaying a stale reference
      // would hand out a free line against a fee bought weeks ago.
      final stale = fee(
        chargedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(stale.isExpired, isTrue);
      expect(PendingPlanFee.fromJson(stale.toJson()), isNull);
    });

    test('nothing cached means nothing owed', () {
      expect(PendingPlanFee.fromJson(null), isNull);
    });

    test('an unreadable entry is discarded, never guessed at', () {
      for (final bad in <Object?>[
        'planfee_123', // not a map
        42,
        <String, dynamic>{}, // no reference
        {'reference_id': '', 'charged_at': DateTime.now().toIso8601String()},
        {'reference_id': 'planfee_1', 'charged_at': 'not-a-date'},
        {'reference_id': 'planfee_1'}, // no timestamp at all
        {'charged_at': DateTime.now().toIso8601String()},
        {'reference_id': 123, 'charged_at': DateTime.now().toIso8601String()},
      ]) {
        expect(PendingPlanFee.fromJson(bad), isNull, reason: 'entry: $bad');
      }
    });

    test('a missing amount still yields a usable reference', () {
      // The amount is only for display; the server prices the fee. Losing it
      // must not throw away a reference the user has already paid for.
      final restored = PendingPlanFee.fromJson({
        'reference_id': 'planfee_1785889298521467',
        'charged_at': DateTime.now().toIso8601String(),
      });

      expect(restored, isNotNull);
      expect(restored!.referenceId, 'planfee_1785889298521467');
      expect(restored.amount, 0);
    });

    test('an amount stored as a string survives', () {
      final restored = PendingPlanFee.fromJson({
        'reference_id': 'planfee_1785889298521467',
        'amount': '2.50',
        'charged_at': DateTime.now().toIso8601String(),
      });

      expect(restored?.amount, 2.50);
    });
  });
}
