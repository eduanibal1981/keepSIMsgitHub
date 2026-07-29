import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/wallet/model/gift_transfer_model.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';

/// G3 — gift / send wallet credit. These cover the two places the client can
/// get this wrong on its own: misreading the jsonb envelope
/// `transfer_wallet_credit` returns, and computing a giftable balance that
/// disagrees with the server's.
void main() {
  WalletTransaction tx(
    String type,
    double amount, {
    Map<String, dynamic>? metadata,
  }) => WalletTransaction(
    id: 't-${type}_$amount',
    walletId: 'w-1',
    userId: 'u-1',
    type: type,
    amount: amount,
    metadata: metadata,
  );

  /// Mirrors what `jsonb_strip_nulls` produces: keys whose value would be null
  /// are absent from the object entirely, not present-and-null.
  Map<String, dynamic> giftMeta({
    required String direction,
    String? email = 'sara@example.com',
    String? name,
    String? note,
  }) {
    final gift = <String, dynamic>{
      'direction': direction,
      'counterparty_user_id': 'u-2',
    };
    if (email != null) gift['counterparty_email'] = email;
    if (name != null) gift['counterparty_name'] = name;
    if (note != null) gift['note'] = note;
    return {'gift': gift};
  }

  group('GiftTransferResult', () {
    test('parses the success envelope the RPC actually returns', () {
      final r = GiftTransferResult.fromJson({
        'success': true,
        'already_sent': false,
        'reference_id': 'gift_2346062b_1',
        'amount': 12.34,
        'transaction_id': 'e10616e7',
        'credit_transaction_id': '75aba272',
        'recipient_email': 'a1-wallet-test@example.com',
        'recipient_name': null,
        'balance_after': 72.86,
      });

      expect(r.success, isTrue);
      expect(r.alreadySent, isFalse);
      expect(r.amount, equals(12.34));
      expect(r.balanceAfter, equals(72.86));
      expect(r.recipientEmail, equals('a1-wallet-test@example.com'));
    });

    test('an idempotent replay reads as a success, not a retry', () {
      final r = GiftTransferResult.fromJson({
        'success': true,
        'already_sent': true,
        'reference_id': 'gift_2346062b_1',
        'amount': 12.34,
        'recipient_email': 'a1-wallet-test@example.com',
      });

      expect(r.success, isTrue);
      expect(r.alreadySent, isTrue);
    });

    test('carries the server sentence for every refusal', () {
      final r = GiftTransferResult.fromJson({
        'success': false,
        'code': 'RECIPIENT_NOT_FOUND',
        'error': 'No KeepSIMs account uses that email address yet.',
      });

      expect(r.success, isFalse);
      expect(r.code, equals(GiftErrorCode.recipientNotFound));
      expect(r.message, equals('No KeepSIMs account uses that email address yet.'));
    });

    test('NOT_GIFTABLE carries the amount that would have been allowed', () {
      final r = GiftTransferResult.fromJson({
        'success': false,
        'code': 'NOT_GIFTABLE',
        'error': 'Only credit you added yourself can be sent on. '
            'Available to send: \$43.20.',
        'giftable': 43.20,
        'balance': 45.20,
      });

      expect(r.code, equals(GiftErrorCode.notGiftable));
      expect(r.giftable, equals(43.20));
    });

    test('DAILY_LIMIT carries both numbers the message quotes', () {
      final r = GiftTransferResult.fromJson({
        'success': false,
        'code': 'DAILY_LIMIT',
        'error': 'That would pass your \$10.00 daily transfer limit. '
            'Sent in the last 24 hours: \$6.00.',
        'daily_max': 10.00,
        'sent_today': 6.00,
      });

      expect(r.dailyMax, equals(10.00));
      expect(r.sentToday, equals(6.00));
    });

    test('numeric fields survive arriving as strings', () {
      // Postgres numeric can serialise as a JSON string depending on the
      // driver; a silent null here would show the user "$0.00 sent".
      final r = GiftTransferResult.fromJson({
        'success': true,
        'amount': '12.34',
        'balance_after': '72.86',
      });

      expect(r.amount, equals(12.34));
      expect(r.balanceAfter, equals(72.86));
    });

    test('names the recipient, falling back to the address they typed', () {
      expect(
        GiftTransferResult.fromJson({
          'success': true,
          'recipient_name': 'Sara',
          'recipient_email': 'sara@example.com',
        }).recipientLabel,
        equals('Sara'),
      );

      // The live recipient fixture has no full_name, which is why this path
      // matters rather than being theoretical.
      expect(
        GiftTransferResult.fromJson({
          'success': true,
          'recipient_name': null,
          'recipient_email': 'sara@example.com',
        }).recipientLabel,
        equals('sara@example.com'),
      );
    });
  });

  group('WalletTransactionGift', () {
    test('reads the counterparty block off both halves', () {
      final sent = tx(
        'gift_sent',
        12.34,
        metadata: giftMeta(direction: 'sent', note: 'Happy birthday!'),
      );
      final received = tx(
        'gift_received',
        12.34,
        metadata: giftMeta(
          direction: 'received',
          email: 'abdalla@example.com',
          name: 'Speakhealth',
        ),
      );

      expect(sent.isGiftSent, isTrue);
      expect(sent.isGiftReceived, isFalse);
      expect(sent.isGift, isTrue);
      expect(sent.giftCounterpartyEmail, equals('sara@example.com'));
      expect(sent.giftNote, equals('Happy birthday!'));

      expect(received.isGiftReceived, isTrue);
      expect(received.giftCounterpartyName, equals('Speakhealth'));
      expect(received.giftCounterpartyLabel, equals('Speakhealth'));
    });

    test('falls back to the address when the counterparty has no name', () {
      // jsonb_strip_nulls omits counterparty_name entirely rather than writing
      // null, so the getter has to cope with an absent key.
      final sent = tx('gift_sent', 5, metadata: giftMeta(direction: 'sent'));

      expect(sent.giftCounterpartyName, isNull);
      expect(sent.giftCounterpartyLabel, equals('sara@example.com'));
    });

    test('a non-gift transaction reports no gift data', () {
      final deposit = tx('deposit', 20, metadata: {'gross': 20.0});

      expect(deposit.isGift, isFalse);
      expect(deposit.giftCounterpartyEmail, isNull);
      expect(deposit.giftNote, isNull);
    });

    test('survives a row with no metadata at all', () {
      final row = tx('gift_sent', 5);

      expect(row.isGiftSent, isTrue);
      expect(row.giftCounterpartyLabel, isNull);
    });
  });

  group('giftableBalance', () {
    test('deposits are transferable', () {
      expect(
        giftableBalance(balance: 50, transactions: [tx('deposit', 50)]),
        equals(50),
      );
    });

    test('promotional credit is not', () {
      // The live shape for six of eight users: a $43.20 deposit plus a $2.00
      // referral bonus. Only the deposit may be sent on.
      expect(
        giftableBalance(
          balance: 45.20,
          transactions: [tx('deposit', 43.20), tx('referral_credit', 2.00)],
        ),
        equals(43.20),
      );
    });

    test('a balance made only of promo credit sends nothing', () {
      expect(
        giftableBalance(
          balance: 2.00,
          transactions: [tx('referral_credit', 2.00)],
        ),
        equals(0.0),
      );
    });

    test('a received gift is re-giftable', () {
      // This is what makes the household case work: one person deposits and
      // the credit can then move on through the family.
      expect(
        giftableBalance(
          balance: 4.00,
          transactions: [tx('gift_received', 4.00)],
        ),
        equals(4.00),
      );
    });

    test('gifts already sent are subtracted', () {
      expect(
        giftableBalance(
          balance: 46.00,
          transactions: [tx('deposit', 50.00), tx('gift_sent', 4.00)],
        ),
        equals(46.00),
      );

      // ...and once the transferable part is spent, a promo-only remainder is
      // not sendable even though the balance is positive.
      expect(
        giftableBalance(
          balance: 2.00,
          transactions: [
            tx('deposit', 4.00),
            tx('referral_credit', 2.00),
            tx('gift_sent', 4.00),
          ],
        ),
        equals(0.0),
      );
    });

    test('never exceeds the balance actually held', () {
      // Deposited $100 and spent $90 on top-ups: $10 is left, so $10 is the
      // ceiling regardless of lifetime deposits.
      expect(
        giftableBalance(
          balance: 10.00,
          transactions: [tx('deposit', 100.00), tx('topup_debit', 90.00)],
        ),
        equals(10.00),
      );
    });

    test('an empty ledger sends nothing', () {
      expect(giftableBalance(balance: 25.00, transactions: []), equals(0.0));
    });
  });
}
