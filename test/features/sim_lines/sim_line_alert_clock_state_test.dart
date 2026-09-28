import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_alert_clock_state.dart';

void main() {
  group('SimLineAlertClockState', () {
    test('parses eligible state with 48h urgency correctly', () {
      final json = {
        'sim_line_id': '1dd080ef-9432-4947-ae56-b4d960fc2db5',
        'user_id': '8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e',
        'carrier_id': '02ba945c-9479-48d4-9852-7cc5030ccede',
        'carrier_rule_id': 'dc43a7f4-324c-41fd-95d8-c5e46e84ad52',
        'carrier_name': 'FRiENDi Mobile Oman',
        'activity_requirement': 'recharge_ok',
        'inactivity_limit_days': 180,
        'qualifying_activity_type': 'confirmed_topup',
        'qualifying_activity_at': '2026-04-01T12:00:00Z',
        'qualifying_activity_amount': 5.0,
        'deactivation_cutoff_at': '2026-09-28T12:00:00Z',
        'precision': 'timestamp',
        'state': 'eligible',
        'ineligibility_reason': null,
        'hours_remaining': 42.5,
        'is_within_48h': true,
        'rule_source_url': 'https://www.friendimobile.om',
        'rule_last_verified_at': '2026-08-22T01:16:18Z',
        'alert_cycle_token': 'abc123token',
        'alert_emitted_at': '2026-09-26T18:00:00Z',
        'evaluated_at': '2026-09-26T18:00:00Z',
      };

      final state = SimLineAlertClockState.fromJson(json);

      expect(state.simLineId, '1dd080ef-9432-4947-ae56-b4d960fc2db5');
      expect(state.isEligible, isTrue);
      expect(state.isWithin48h, isTrue);
      expect(state.hoursRemaining, 42.5);
      expect(state.daysRemaining, 1);
      expect(state.carrierName, 'FRiENDi Mobile Oman');
      expect(state.activityRequirement, 'recharge_ok');
      expect(state.inactivityLimitDays, 180);
      expect(state.deactivationCutoffAt, DateTime.parse('2026-09-28T12:00:00Z'));
      expect(state.ruleSourceUrl, 'https://www.friendimobile.om');
    });

    test('parses needs_activity_date state when line has no recharge date', () {
      final json = {
        'sim_line_id': '00769142-2d72-4c48-98e5-e2d29bfbc28d',
        'user_id': '8a07a25b-a49b-4ec3-a56c-cfe7f7ea0c0e',
        'carrier_name': 'Omantel',
        'activity_requirement': 'recharge_ok',
        'inactivity_limit_days': 180,
        'state': 'needs_activity_date',
        'ineligibility_reason': 'No recharge date recorded. Self-report your last recharge date to activate the Alert Clock.',
        'hours_remaining': null,
        'is_within_48h': false,
        'deactivation_cutoff_at': null,
      };

      final state = SimLineAlertClockState.fromJson(json);

      expect(state.isEligible, isFalse);
      expect(state.isNeedsActivityDate, isTrue);
      expect(state.isWithin48h, isFalse);
      expect(state.hoursRemaining, isNull);
      expect(state.daysRemaining, isNull);
      expect(state.deactivationCutoffAt, isNull);
      expect(state.ineligibilityReason, contains('No recharge date recorded'));
    });

    test('parses needs_amount state for min_denomination requirements', () {
      final json = {
        'sim_line_id': 'line-min-denom',
        'user_id': 'user-1',
        'carrier_name': 'Carrier X',
        'activity_requirement': 'min_denomination',
        'inactivity_limit_days': 90,
        'state': 'needs_amount',
        'ineligibility_reason': 'Carrier requires top-up of at least \$10. Please confirm the amount of your recharge.',
        'is_within_48h': false,
      };

      final state = SimLineAlertClockState.fromJson(json);

      expect(state.isEligible, isFalse);
      expect(state.isNeedsAmount, isTrue);
      expect(state.activityRequirement, 'min_denomination');
    });

    test('parses needs_qualifying_usage for usage_required carriers', () {
      final json = {
        'sim_line_id': 'line-usage-req',
        'user_id': 'user-1',
        'carrier_name': 'Carrier Y',
        'activity_requirement': 'usage_required',
        'inactivity_limit_days': 60,
        'state': 'needs_qualifying_usage',
        'ineligibility_reason': 'Carrier requires active call, SMS, or data usage. Top-up alone does not extend validity.',
        'is_within_48h': false,
      };

      final state = SimLineAlertClockState.fromJson(json);

      expect(state.isEligible, isFalse);
      expect(state.isNeedsUsage, isTrue);
      expect(state.activityRequirement, 'usage_required');
    });

    test('toJson produces valid roundtrip map', () {
      const state = SimLineAlertClockState(
        simLineId: 'sim-1',
        userId: 'user-1',
        carrierName: 'Test Carrier',
        state: 'eligible',
        hoursRemaining: 120.0,
        isWithin48h: false,
      );

      final map = state.toJson();
      expect(map['sim_line_id'], 'sim-1');
      expect(map['state'], 'eligible');
      expect(map['hours_remaining'], 120.0);
      expect(map['is_within_48h'], isFalse);

      final roundtrip = SimLineAlertClockState.fromJson(map);
      expect(roundtrip.simLineId, state.simLineId);
      expect(roundtrip.state, state.state);
      expect(roundtrip.hoursRemaining, state.hoursRemaining);
    });
  });
}
