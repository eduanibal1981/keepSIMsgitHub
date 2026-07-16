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

  // The worker claims executions with `execution_time <= NOW()` on absolute
  // UTC instants, so the schedule math must be pure duration arithmetic —
  // no calendar-recurrence rules that could skip or double-fire around
  // month ends, year ends, leap days, or DST transitions (B1 audit item 4).
  group('calendar boundaries (claim-window safety)', () {
    test('crosses a month end without clamping or skipping', () {
      final endOfJan = DateTime.utc(2026, 1, 31, 23, 30);
      expect(
        RefillScheduleMath.nextTopupDue(endOfJan, 30),
        DateTime.utc(2026, 3, 2, 23, 30),
      );
    });

    test('crosses a year end exactly', () {
      final decEnd = DateTime.utc(2026, 12, 20, 8);
      expect(
        RefillScheduleMath.nextExecutionAt(decEnd, 14), // 13-day safety window
        DateTime.utc(2027, 1, 2, 8),
      );
    });

    test('counts a leap day as a real day', () {
      final beforeLeap = DateTime.utc(2028, 2, 28, 6);
      expect(
        RefillScheduleMath.nextTopupDue(beforeLeap, 2),
        DateTime.utc(2028, 3, 1, 6),
      );
    });

    test('90-day window is exactly 90×24h in UTC (no DST drift)', () {
      final beforeUsDstChange = DateTime.utc(2026, 3, 1, 12);
      final due = RefillScheduleMath.nextTopupDue(beforeUsDstChange, 90);
      expect(due.difference(beforeUsDstChange).inHours, 90 * 24);
    });

    test('execution instant keeps the wall-clock time of day in UTC', () {
      final scheduled = DateTime.utc(2026, 7, 15, 21, 45);
      final exec = RefillScheduleMath.nextExecutionAt(scheduled, 90);
      expect(exec.hour, 21);
      expect(exec.minute, 45);
      expect(exec.isUtc, isTrue);
    });
  });
}
