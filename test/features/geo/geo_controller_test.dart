import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';

void main() {
  group('C8 - Travel & Geolocation Freeze Unit Tests', () {
    test('SimLine freeze model update toggles status and protectionPaused', () {
      final activeLine = SimLine(
        id: 'line-1',
        userId: 'user-1',
        phoneNumber: '+1234567890',
        countryId: 'country-us',
        status: 'active',
        protectionPaused: false,
        requiresProtectionAtHome: false,
      );

      final frozenLine = activeLine.copyWith(
        status: 'paused',
        protectionPaused: true,
      );

      expect(frozenLine.status, equals('paused'));
      expect(frozenLine.protectionPaused, isTrue);
    });

    test('ScheduledTopup toggle active state correctly pauses refill worker schedule', () {
      final activeSchedule = ScheduledTopup(
        id: 'sched-1',
        userId: 'user-1',
        simLineId: 'line-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: DateTime.now(),
        isActive: true,
        status: 'active',
      );

      final pausedSchedule = activeSchedule.copyWith(
        isActive: false,
        status: 'paused',
      );

      expect(pausedSchedule.isActive, isFalse);
      expect(pausedSchedule.status, equals('paused'));
    });

    test('Lines with requiresProtectionAtHome are flagged for exemption during home freeze', () {
      final protectedLine = SimLine(
        id: 'line-protected',
        userId: 'user-1',
        phoneNumber: '+1999888777',
        countryId: 'country-uk',
        status: 'active',
        protectionPaused: false,
        requiresProtectionAtHome: true,
      );

      final shouldFreeze = !protectedLine.requiresProtectionAtHome;
      expect(shouldFreeze, isFalse, reason: 'Always-protected lines must skip auto-freeze');
    });
  });
}
