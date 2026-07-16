import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/model/topup_execution_model.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_activity_log_model.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/failure.dart';

part 'sim_line_detail_controller.g.dart';

class SimLineDetailState {
  final SimLine simLine;
  final ScheduledTopup? scheduledTopup;
  final ScheduledTopup? notifySchedule;
  final ScheduledTopup? miniRefillSchedule;
  final ScheduledTopup? customRefillSchedule;
  final List<TopupExecution> executions;
  final List<LineActivityLog> activityLogs;

  const SimLineDetailState({
    required this.simLine,
    this.scheduledTopup,
    this.notifySchedule,
    this.miniRefillSchedule,
    this.customRefillSchedule,
    required this.executions,
    required this.activityLogs,
  });
}

@riverpod
class SimLineDetailController extends _$SimLineDetailController {
  @override
  FutureOr<SimLineDetailState> build(String id) async {
    // 1. Fetch SIM Line from current list
    final simLines = await ref.watch(simLinesControllerProvider.future);

    final simLine = simLines.firstWhere(
      (l) => l.id == id,
      orElse: () => throw Exception('SIM Line not found: $id'),
    );

    // 2. Fetch ScheduledTopups if any
    final notifySchedule = ref.watch(scheduledNotifyForLineProvider(id));
    final miniRefillSchedule = ref.watch(
      scheduledMiniRefillForLineProvider(id),
    );
    final customRefillSchedule = ref.watch(
      scheduledCustomRefillForLineProvider(id),
    );
    final scheduledTopup =
        customRefillSchedule ?? miniRefillSchedule ?? notifySchedule;

    // 3. Fetch Executions
    final executions = await ref.watch(
      topupExecutionsForLineProvider(id).future,
    );

    // 4. Fetch Activity Logs
    final activityLogs = await ref.watch(
      simLineActivityLogsProvider(id).future,
    );

    return SimLineDetailState(
      simLine: simLine,
      scheduledTopup: scheduledTopup,
      notifySchedule: notifySchedule,
      miniRefillSchedule: miniRefillSchedule,
      customRefillSchedule: customRefillSchedule,
      executions: executions,
      activityLogs: activityLogs,
    );
  }

  /// Triggers a mock refill execution
  Future<Result<void>> triggerRefill() async {
    final detailState = state.value;
    final refillSchedule =
        detailState?.customRefillSchedule ?? detailState?.miniRefillSchedule;
    if (detailState == null || refillSchedule == null) {
      return const Failure(
        AppFailure.validation(
          message: 'No active Auto-Refill configuration found for this line.',
        ),
      );
    }

    return ref
        .read(scheduledTopupControllerProvider.notifier)
        .executeMockTopup(refillSchedule.id);
  }

  /// Retries a failed execution
  Future<Result<void>> retryFailedTopup(String executionId) async {
    return ref
        .read(scheduledTopupControllerProvider.notifier)
        .retryFailedExecution(executionId, id);
  }

  /// Deletes a specific activity log
  Future<void> deleteActivityLog(String logId) async {
    await ref
        .read(simLinesControllerProvider.notifier)
        .deleteActivityLog(logId, id);
  }

  /// Deletes a specific execution record
  Future<void> deleteExecution(String executionId) async {
    await ref
        .read(scheduledTopupControllerProvider.notifier)
        .removeExecution(executionId, id);
  }

  /// Cleans all mock logs (activity logs and execution records) for this line
  Future<void> cleanMockLogs() async {
    await ref.read(simLinesControllerProvider.notifier).cleanMockLogs(id);
  }

  /// Clears all activity logs for this line
  Future<void> clearAllActivityLogs() async {
    await ref
        .read(simLinesControllerProvider.notifier)
        .clearAllActivityLogs(id);
  }
}
