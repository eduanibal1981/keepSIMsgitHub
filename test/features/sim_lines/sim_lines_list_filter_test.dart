import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/models/sim_lines_list_filter.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 14, 12, 0, 0);

  const line1 = SimLine(
    id: 'line-1',
    userId: 'user-1',
    phoneNumber: '+20 109 535 1020',
    nickname: 'Personal Egypt',
    status: 'active',
    protectionPaused: false,
  );

  const line2 = SimLine(
    id: 'line-2',
    userId: 'user-1',
    phoneNumber: '+44 7911 123456',
    nickname: 'UK Travel',
    status: 'active',
    protectionPaused: true,
  );

  const line3 = SimLine(
    id: 'line-3',
    userId: 'user-1',
    phoneNumber: '+1 (555) 234-5678',
    nickname: 'US Banking',
    status: 'inactive',
    protectionPaused: false,
  );

  const line4 = SimLine(
    id: 'line-4',
    userId: 'user-1',
    phoneNumber: '+971 50 987 6543',
    nickname: null,
    status: 'active',
    protectionPaused: false,
  );

  group('filterSimLines pure tests', () {
    test(
      '1. Empty query plus all returns the same lines in the same order',
      () {
        final lines = [line1, line2, line3, line4];
        final result = filterSimLines(
          lines: lines,
          schedules: [],
          query: '',
          filter: SimLinesListFilter.all,
          now: fixedNow,
        );

        expect(result, equals(lines));
      },
    );

    test('2. Nickname search is case-insensitive', () {
      final lines = [line1, line2, line3, line4];
      final result = filterSimLines(
        lines: lines,
        schedules: [],
        query: 'personal egypt',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );

      expect(result, [line1]);

      final resultUpper = filterSimLines(
        lines: lines,
        schedules: [],
        query: 'UK TRAVEL',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );

      expect(resultUpper, [line2]);
    });

    test('3. Phone search ignores spaces, +, hyphens, and parentheses', () {
      final lines = [line1, line2, line3, line4];

      // Query "109535" should match "+20 109 535 1020"
      final result1 = filterSimLines(
        lines: lines,
        schedules: [],
        query: '109535',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );
      expect(result1, [line1]);

      // Query "5552345678" should match "+1 (555) 234-5678"
      final result2 = filterSimLines(
        lines: lines,
        schedules: [],
        query: '5552345678',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );
      expect(result2, [line3]);

      // Query with punctuation matching phone without nickname
      final result3 = filterSimLines(
        lines: lines,
        schedules: [],
        query: '+971 50',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );
      expect(result3, [line4]);
    });

    test('4. Search and quick filter combine with AND', () {
      final lines = [line1, line2, line3, line4];
      // "Travel" matches line2, but line2 has protectionPaused: true (not active filter)
      final result = filterSimLines(
        lines: lines,
        schedules: [],
        query: 'Travel',
        filter: SimLinesListFilter.active,
        now: fixedNow,
      );
      expect(result, isEmpty);

      // "Egypt" matches line1, and line1 is active
      final resultActive = filterSimLines(
        lines: lines,
        schedules: [],
        query: 'Egypt',
        filter: SimLinesListFilter.active,
        now: fixedNow,
      );
      expect(resultActive, [line1]);
    });

    test(
      '5. Active includes only status == active and excludes protectionPaused',
      () {
        final lines = [line1, line2, line3, line4];
        final result = filterSimLines(
          lines: lines,
          schedules: [],
          query: '',
          filter: SimLinesListFilter.active,
          now: fixedNow,
        );

        // line1 (active, not paused) and line4 (active, not paused) match
        // line2 is paused, line3 is inactive
        expect(result, [line1, line4]);
      },
    );

    test('6. Alert soon includes an active notify schedule within 30 days', () {
      final schedule = ScheduledTopup(
        id: 's-1',
        simLineId: line1.id,
        userId: 'user-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.add(const Duration(days: 15)),
        scheduleType: 'notify',
        isActive: true,
      );

      final result = filterSimLines(
        lines: [line1, line2],
        schedules: [schedule],
        query: '',
        filter: SimLinesListFilter.alertSoon,
        now: fixedNow,
      );

      expect(result, [line1]);
    });

    test('7. Alert soon includes an overdue active notify schedule', () {
      final overdueSchedule = ScheduledTopup(
        id: 's-overdue',
        simLineId: line2.id,
        userId: 'user-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.subtract(const Duration(days: 5)),
        scheduleType: 'notify',
        isActive: true,
      );

      final result = filterSimLines(
        lines: [line1, line2],
        schedules: [overdueSchedule],
        query: '',
        filter: SimLinesListFilter.alertSoon,
        now: fixedNow,
      );

      expect(result, [line2]);
    });

    test(
      '8. Alert soon excludes a notify schedule after 30 days and an inactive schedule',
      () {
        final farFutureSchedule = ScheduledTopup(
          id: 's-far',
          simLineId: line1.id,
          userId: 'user-1',
          amount: 5.0,
          frequencyDays: 60,
          nextExecutionAt: fixedNow.add(const Duration(days: 35)),
          scheduleType: 'notify',
          isActive: true,
        );

        final inactiveSchedule = ScheduledTopup(
          id: 's-inactive',
          simLineId: line2.id,
          userId: 'user-1',
          amount: 5.0,
          frequencyDays: 30,
          nextExecutionAt: fixedNow.add(const Duration(days: 10)),
          scheduleType: 'notify',
          isActive: false,
        );

        final result = filterSimLines(
          lines: [line1, line2],
          schedules: [farFutureSchedule, inactiveSchedule],
          query: '',
          filter: SimLinesListFilter.alertSoon,
          now: fixedNow,
        );

        expect(result, isEmpty);
      },
    );

    test('9. Auto-refill includes active refill_mini and refill_custom', () {
      final miniSchedule = ScheduledTopup(
        id: 's-mini',
        simLineId: line1.id,
        userId: 'user-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.add(const Duration(days: 20)),
        scheduleType: 'refill_mini',
        isActive: true,
      );

      final customSchedule = ScheduledTopup(
        id: 's-custom',
        simLineId: line2.id,
        userId: 'user-1',
        amount: 15.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.add(const Duration(days: 10)),
        scheduleType: 'refill_custom',
        isActive: true,
      );

      final result = filterSimLines(
        lines: [line1, line2, line3],
        schedules: [miniSchedule, customSchedule],
        query: '',
        filter: SimLinesListFilter.autoRefill,
        now: fixedNow,
      );

      expect(result, [line1, line2]);
    });

    test('10. Auto-refill excludes notify and inactive refill schedules', () {
      final notifySchedule = ScheduledTopup(
        id: 's-notify',
        simLineId: line1.id,
        userId: 'user-1',
        amount: 5.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.add(const Duration(days: 10)),
        scheduleType: 'notify',
        isActive: true,
      );

      final inactiveRefill = ScheduledTopup(
        id: 's-inactive-refill',
        simLineId: line2.id,
        userId: 'user-1',
        amount: 10.0,
        frequencyDays: 30,
        nextExecutionAt: fixedNow.add(const Duration(days: 10)),
        scheduleType: 'refill_mini',
        isActive: false,
      );

      final result = filterSimLines(
        lines: [line1, line2],
        schedules: [notifySchedule, inactiveRefill],
        query: '',
        filter: SimLinesListFilter.autoRefill,
        now: fixedNow,
      );

      expect(result, isEmpty);
    });

    test('11. Filtering does not reorder the input list', () {
      final lines = [line3, line1, line4, line2];
      final result = filterSimLines(
        lines: lines,
        schedules: [],
        query: '',
        filter: SimLinesListFilter.all,
        now: fixedNow,
      );

      expect(result, equals(lines));
    });
  });
}
