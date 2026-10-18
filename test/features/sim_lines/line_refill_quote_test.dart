import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/domain/line_refill_quote.dart';

void main() {
  test('uses the server total without applying a second markup', () {
    final quote = LineRefillQuote.fromJson({
      'offer_id': 'range',
      'offer_value': 777,
      'total_charge_usd': 8.31,
      'currency': 'USD',
      'pricing_tier': 'free',
      'wholesale_cost_usd': 7.77,
      'expected_margin_usd': .54,
    }, simLineId: 'owned-line');
    expect(quote.total, 8.31);
    expect(quote.offerValue, 777);
    expect(quote.breakdownText, 'Total: \$8.31 USD');
  });
  for (final total in [null, 0, -1, double.nan, double.infinity]) {
    test('rejects unavailable or invalid server total $total', () {
      expect(
        () => LineRefillQuote.fromJson({
          'total_charge_usd': total,
          'currency': 'USD',
        }),
        throwsFormatException,
      );
    });
  }
  test('rejects a different currency', () {
    expect(
      () =>
          LineRefillQuote.fromJson({'total_charge_usd': 2, 'currency': 'EUR'}),
      throwsFormatException,
    );
  });
}
