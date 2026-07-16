import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    'id': 'rule-1',
    'carrier_id': 'carrier-1',
    'rule_type': 'inactivity',
    'inactivity_limit_days': 90,
    'grace_period_days': 30,
    'minimum_topup_amount': '5.00',
    'topup_validity_days': 90,
    'inapp_pricing': '2.50',
    'inapp_pricing_currency': 'usd',
  };

  group('CarrierRule.fromJson money parsing', () {
    test('parses numeric strings from Postgres numeric columns', () {
      final rule = CarrierRule.fromJson(baseJson());
      expect(rule.minimumTopupAmount, 5.00);
      expect(rule.inappPricing, 2.50);
    });

    test('parses raw numbers', () {
      final json = baseJson()
        ..['minimum_topup_amount'] = 5
        ..['inapp_pricing'] = 2.5;
      final rule = CarrierRule.fromJson(json);
      expect(rule.minimumTopupAmount, 5.0);
      expect(rule.inappPricing, 2.5);
    });

    test('malformed money strings fall back to 0 rather than crashing', () {
      final json = baseJson()..['minimum_topup_amount'] = 'not-a-number';
      final rule = CarrierRule.fromJson(json);
      expect(rule.minimumTopupAmount, 0.0);
    });

    test('keeps expiry window fields intact', () {
      final rule = CarrierRule.fromJson(baseJson());
      expect(rule.inactivityLimitDays, 90);
      expect(rule.gracePeriodDays, 30);
      expect(rule.topupValidityDays, 90);
      expect(rule.offerId, isNull);
    });
  });
}
