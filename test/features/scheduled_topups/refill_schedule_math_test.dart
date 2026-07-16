import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/scheduled_topups/domain/refill_schedule_math.dart';

void main() {
  final now = DateTime.utc(2026, 7, 15, 12);

  group('safetyAdjustedDelayDays', () {
    test('shaves a safety margin off the standard carrier windows', () {
      expect(RefillScheduleMath.safetyAdjustedDelayDays(90), 85);
      expect(RefillScheduleMath.safetyAdjustedDelayDays(30), 28);
      expect(RefillScheduleMath.safetyAdjustedDelayDays(14), 13);
    });

    test('passes non-standard windows through unchanged', () {
      expect(RefillScheduleMath.safetyAdjustedDelayDays(60), 60);
      expect(RefillScheduleMath.safetyAdjustedDelayDays(7), 7);
      expect(RefillScheduleMath.safetyAdjustedDelayDays(1), 1);
    });
  });

  group('nextExecutionAt', () {
    test('runs before the carrier deadline for standard windows', () {
      expect(
        RefillScheduleMath.nextExecutionAt(now, 90),
        now.add(const Duration(days: 85)),
      );
      expect(
        RefillScheduleMath.nextExecutionAt(now, 30),
        now.add(const Duration(days: 28)),
      );
    });

    test('frequency 0 means one hour (test mode)', () {
      expect(
        RefillScheduleMath.nextExecutionAt(now, 0),
        now.add(const Duration(hours: 1)),
      );
    });

    test('always executes on or before the line is due', () {
      for (final freq in [1, 7, 14, 30, 60, 90]) {
        final exec = RefillScheduleMath.nextExecutionAt(now, freq);
        final due = RefillScheduleMath.nextTopupDue(now, freq);
        expect(
          exec.isAfter(due),
          isFalse,
          reason: 'frequency $freq would execute after the due date',
        );
      }
    });
  });

  group('nextTopupDue', () {
    test('uses the full carrier window', () {
      expect(
        RefillScheduleMath.nextTopupDue(now, 90),
        now.add(const Duration(days: 90)),
      );
    });

    test('frequency 0 means one hour (test mode)', () {
      expect(
        RefillScheduleMath.nextTopupDue(now, 0),
        now.add(const Duration(hours: 1)),
      );
    });
  });

  group('validityExpiresAt', () {
    test('adds a 7-day grace buffer after the due date', () {
      final due = RefillScheduleMath.nextTopupDue(now, 90);
      expect(
        RefillScheduleMath.validityExpiresAt(due, 90),
        due.add(const Duration(days: 7)),
      );
    });

    test('frequency 0 adds one hour', () {
      final due = RefillScheduleMath.nextTopupDue(now, 0);
      expect(
        RefillScheduleMath.validityExpiresAt(due, 0),
        due.add(const Duration(hours: 1)),
      );
    });
  });
}
