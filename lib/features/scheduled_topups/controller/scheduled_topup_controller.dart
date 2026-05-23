/// SIM Shield — Scheduled Top-Up Controller
///
/// Manages the state of all auto top-up schedules for the active user.
/// Extends [AsyncNotifier] and provides action handlers.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import '../model/scheduled_topup_model.dart';
import '../model/topup_execution_model.dart';

part 'scheduled_topup_controller.g.dart';

@Riverpod(keepAlive: true)
class ScheduledTopupController extends _$ScheduledTopupController {
  @override
  FutureOr<List<ScheduledTopup>> build() async {
    final repo = ref.watch(scheduledTopupRepositoryProvider);
    final result = await repo.getSchedules();

    return switch (result) {
      Success(data: final schedules) => schedules,
      Failure(error: final failure) => throw Exception(failure.message),
    };
  }

  /// Refreshes/reloads schedules from database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(scheduledTopupRepositoryProvider);
      final result = await repo.getSchedules();
      return switch (result) {
        Success(data: final schedules) => schedules,
        Failure(error: final failure) => throw Exception(failure.message),
      };
    });
  }

  /// Configures (creates or updates) a top-up schedule for a SIM Line.
  Future<Result<ScheduledTopup>> saveSchedule(ScheduledTopup schedule) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);

    // Check if we are updating or creating
    final isNew = schedule.id.isEmpty;
    final Result<ScheduledTopup> result;

    if (isNew) {
      // Create new uuid for reference
      final newSchedule = schedule.copyWith(
        id: '', // Supabase will assign UUID
      );
      result = await repo.createSchedule(newSchedule);
    } else {
      result = await repo.updateSchedule(schedule);
    }

    if (result is Success<ScheduledTopup>) {
      await refresh();
    }
    return result;
  }

  /// Toggles the active state of a schedule.
  Future<Result<ScheduledTopup>> toggleActive(String id, bool isActive) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.toggleSchedule(id: id, isActive: isActive);

    if (result is Success<ScheduledTopup>) {
      // Update local state without full reload
      state = state.whenData((list) {
        return list.map((item) {
          if (item.id == id) {
            return result.data;
          }
          return item;
        }).toList();
      });
    }
    return result;
  }

  /// Deletes a top-up schedule configuration.
  Future<Result<void>> removeSchedule(String id) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.deleteSchedule(id);

    if (result is Success<void>) {
      // Update local state without full reload
      state = state.whenData((list) {
        return list.where((item) => item.id != id).toList();
      });
    }
    return result;
  }

  /// Triggers a simulated E2E execution of an auto refill.
  Future<Result<void>> executeMockTopup(String id) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.simulateExecution(id);

    if (result is Success<void>) {
      // Reload everything to get updated next execution time, last execution time, and new wallet balance!
      await refresh();

      // Invalidate the wallet and SIM line controllers so the UI reflects the deducted balance & restored status instantly!
      ref.invalidate(walletControllerProvider);
      ref.invalidate(simLinesControllerProvider);
    }
    return result;
  }

  /// Retries a failed execution record.
  Future<Result<void>> retryFailedExecution(
    String executionId,
    String simLineId,
  ) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.retryExecution(executionId);

    if (result is Success<void>) {
      await refresh();
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
      ref.invalidate(walletControllerProvider);
      ref.invalidate(simLinesControllerProvider);
    }
    return result;
  }

  /// Removes an execution record by ID.
  Future<Result<void>> removeExecution(
    String executionId,
    String simLineId,
  ) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.deleteExecution(executionId);

    if (result is Success<void>) {
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
    }
    return result;
  }
}

/// Helper provider to get schedule for a specific SIM line.
@riverpod
ScheduledTopup? scheduledTopupForLine(
  ScheduledTopupForLineRef ref,
  String simLineId,
) {
  final schedulesAsync = ref.watch(scheduledTopupControllerProvider);
  final list = schedulesAsync.valueOrNull;
  if (list == null) return null;
  for (final s in list) {
    if (s.simLineId == simLineId) return s;
  }
  return null;
}

/// Family provider to watch execution history for a SIM Line.
@riverpod
FutureOr<List<TopupExecution>> topupExecutionsForLine(
  TopupExecutionsForLineRef ref,
  String simLineId,
) async {
  final repo = ref.watch(scheduledTopupRepositoryProvider);
  final result = await repo.getExecutionsForLine(simLineId);
  return switch (result) {
    Success(data: final list) => list,
    Failure(error: final failure) => throw Exception(failure.message),
  };
}
