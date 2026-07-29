import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

/// G1 — depletion forecasting. These cover the edges where the client is
/// allowed to reinterpret what the nightly job wrote.
void main() {
  Map<String, dynamic> row({
    String method = 'carrier_rule',
    String confidence = 'medium',
    int? suggestedFrequencyDays,
    int? daysRemaining,
    int alertLeadDays = 7,
  }) => {
    'id': 'f-1',
    'user_id': 'u-1',
    'sim_line_id': 'l-1',
    'esim_id': null,
    'subject_kind': 'sim_line',
    'method': method,
    'confidence': confidence,
    'samples_count': 4,
    'observed_interval_days': 28.0,
    'mb_per_day': null,
    'effective_validity_days': 28,
    'predicted_depletion_at': '2026-08-15T00:00:00Z',
    'days_remaining': daysRemaining,
    'suggested_frequency_days': suggestedFrequencyDays,
    'suggested_amount_usd': 4.0,
    'suggested_offer_id': 'ZONG_PK_OPEN',
    'alert_lead_days': alertLeadDays,
    'last_alert_at': null,
    'computed_at': '2026-07-29T02:20:00Z',
  };

  group('UsageForecast deserialization', () {
    test('maps the snake_case row the table actually returns', () {
      final f = UsageForecast.fromJson(
        row(method: 'topup_history', suggestedFrequencyDays: 30),
      );

      expect(f.simLineId, equals('l-1'));
      expect(f.subjectKind, equals('sim_line'));
      expect(f.method, equals('topup_history'));
      expect(f.samplesCount, equals(4));
      expect(f.observedIntervalDays, equals(28.0));
      expect(f.suggestedAmountUsd, equals(4.0));
      expect(f.suggestedOfferId, equals('ZONG_PK_OPEN'));
      expect(f.predictedDepletionAt, isNotNull);
    });

    test('a null suggestion stays null rather than defaulting', () {
      final f = UsageForecast.fromJson(row());
      expect(f.suggestedFrequencyDays, isNull);
      expect(f.suggestedChipFor(isPremium: false), isNull);
      expect(f.suggestedChipFor(isPremium: true), isNull);
    });
  });

  group('suggestedChipFor — tier translation', () {
    // The server stores 90 for the quarterly slot. Premium accounts are shown
    // an 85-day chip for that same slot, so a stored 90 must land on 85 or the
    // sheet highlights a chip that isn't in its own list.
    test('quarterly maps to 85 for premium, 90 otherwise', () {
      final f = UsageForecast.fromJson(row(suggestedFrequencyDays: 90));
      expect(f.suggestedChipFor(isPremium: true), equals(85));
      expect(f.suggestedChipFor(isPremium: false), equals(90));
    });

    test('every other frequency is identical for both tiers', () {
      for (final freq in [7, 14, 30]) {
        final f = UsageForecast.fromJson(row(suggestedFrequencyDays: freq));
        expect(f.suggestedChipFor(isPremium: true), equals(freq));
        expect(f.suggestedChipFor(isPremium: false), equals(freq));
      }
    });
  });

  group('isMeasured — honesty about where the number came from', () {
    test('fitted methods are measured', () {
      expect(UsageForecast.fromJson(row(method: 'topup_history')).isMeasured,
          isTrue);
      expect(
          UsageForecast.fromJson(row(method: 'esim_usage')).isMeasured, isTrue);
    });

    test('fallback methods are not measured', () {
      expect(UsageForecast.fromJson(row(method: 'carrier_rule')).isMeasured,
          isFalse);
      expect(UsageForecast.fromJson(row(method: 'default')).isMeasured, isFalse);
    });
  });

  group('isUrgent — mirrors the server alert window', () {
    test('inside the lead window, including the boundary day', () {
      expect(
          UsageForecast.fromJson(row(daysRemaining: 7, alertLeadDays: 7))
              .isUrgent,
          isTrue);
      expect(
          UsageForecast.fromJson(row(daysRemaining: 0, alertLeadDays: 7))
              .isUrgent,
          isTrue);
    });

    test('outside the window, and when the server sent no estimate', () {
      expect(
          UsageForecast.fromJson(row(daysRemaining: 8, alertLeadDays: 7))
              .isUrgent,
          isFalse);
      expect(UsageForecast.fromJson(row(daysRemaining: null)).isUrgent, isFalse);
    });

    test('respects a lead window widened in system_configs', () {
      expect(
          UsageForecast.fromJson(row(daysRemaining: 15, alertLeadDays: 20))
              .isUrgent,
          isTrue);
    });
  });
}
