import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

/// Mutually exclusive quick filters for the Protected SIMs list.
enum SimLinesListFilter { all, active, alertSoon, autoRefill }

/// Pure presentation helper to filter a list of [SimLine]s by search query
/// and [SimLinesListFilter].
///
/// Does not mutate provider/controller state or reorder elements.
List<SimLine> filterSimLines({
  required List<SimLine> lines,
  required List<ScheduledTopup> schedules,
  required String query,
  required SimLinesListFilter filter,
  DateTime? now,
}) {
  final trimmedQuery = query.trim().toLowerCase();
  final queryDigits = trimmedQuery.replaceAll(RegExp(r'\D'), '');

  final effectiveNow = now ?? DateTime.now();
  final alertSoonThreshold = effectiveNow.add(const Duration(days: 30));

  return lines.where((line) {
    // 1. Local search match (nickname or phone number)
    if (trimmedQuery.isNotEmpty) {
      final nicknameMatch =
          line.nickname != null &&
          line.nickname!.toLowerCase().contains(trimmedQuery);

      final rawPhone = line.phoneNumber.toLowerCase();
      final digitsPhone = line.phoneNumber.replaceAll(RegExp(r'\D'), '');

      final phoneMatch =
          rawPhone.contains(trimmedQuery) ||
          (queryDigits.isNotEmpty && digitsPhone.contains(queryDigits));

      if (!nicknameMatch && !phoneMatch) {
        return false;
      }
    }

    // 2. Quick filter predicate
    switch (filter) {
      case SimLinesListFilter.all:
        return true;

      case SimLinesListFilter.active:
        return line.status.toLowerCase() == 'active' && !line.protectionPaused;

      case SimLinesListFilter.alertSoon:
        return schedules.any(
          (s) =>
              s.simLineId == line.id &&
              s.isActive &&
              s.scheduleType == 'notify' &&
              !s.nextExecutionAt.isAfter(alertSoonThreshold),
        );

      case SimLinesListFilter.autoRefill:
        return schedules.any(
          (s) =>
              s.simLineId == line.id &&
              s.isActive &&
              (s.scheduleType == 'refill_mini' ||
                  s.scheduleType == 'refill_custom'),
        );
    }
  }).toList();
}
