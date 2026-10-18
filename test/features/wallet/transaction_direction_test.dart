import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';

void main() {
  test('purchase reversals and positive adjustments display as credits', () {
    for (final type in [
      'refund',
      'esim_purchase_refund',
      'call_refund',
      'admin_adjustment',
      'gift_received',
      'referral_credit',
    ]) {
      final transaction = WalletTransaction.fromJson({
        'type': type,
        'amount': 2,
        'balance_before': 5,
        'balance_after': 7,
      });
      expect(transaction.isCredit, isTrue);
      expect(transaction.amountSign, '+');
      expect(transaction.signedAmount, 2);
    }
  });
  test(
    'payouts and negative adjustments retain their actual debit direction',
    () {
      for (final type in [
        'refund_payout',
        'admin_adjustment',
        'verification_debit',
        'call_debit',
      ]) {
        final transaction = WalletTransaction.fromJson({
          'type': type,
          'amount': 2,
          'balance_before': 5,
          'balance_after': 3,
        });
        expect(transaction.isCredit, isFalse);
        expect(transaction.amountSign, '-');
      }
    },
  );
  test(
    'missing or equal snapshots do not invent a signed balance mutation',
    () {
      const transaction = WalletTransaction(
        type: 'admin_adjustment',
        amount: 2,
      );
      expect(transaction.amountSign, '');
      expect(transaction.isCredit, isFalse);
    },
  );
}
