/// SIM Shield — Scheduled Top-Up Controller
///
/// Manages the state of all auto top-up schedules for the active user.
/// Extends [AsyncNotifier] and provides action handlers.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
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

  /// Retries a failed execution record by queueing a fresh one through the
  /// real worker pipeline (C3b-2); progress streams in via
  /// topupExecutionsLiveProvider.
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

  /// Cancels a queued execution by ID.
  Future<Result<void>> removeExecution(
    String executionId,
    String simLineId,
  ) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.cancelExecution(executionId);

    if (result is Success<void>) {
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
    }
    return result;
  }

  /// Approves a refill execution currently in 'awaiting_approval' status.
  Future<Result<void>> approveRefillExecution({
    required String executionId,
    required String simLineId,
    required String quoteId,
    required double newMaxAuthorizedUsd,
  }) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.approveExecution(
      executionId: executionId,
      quoteId: quoteId,
      newMaxAuthorizedUsd: newMaxAuthorizedUsd,
    );

    if (result is Success<void>) {
      await refresh();
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
      ref.invalidate(simLinesControllerProvider);
    }
    return result;
  }

  /// Reschedules the mini refill date
  Future<Result<void>> rescheduleMiniRefill(
    String simLineId,
    DateTime newDate,
  ) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.rescheduleMiniRefill(
      simLineId: simLineId,
      newDate: newDate,
    );
    if (result is Success<void>) {
      await refresh();
      ref.invalidate(simLinesControllerProvider);
    }
    return result;
  }

  /// Resets the mini refill date to default
  Future<Result<DateTime>> resetMiniRefillToDefault(String simLineId) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.resetMiniRefillToDefault(simLineId);
    if (result is Success<DateTime>) {
      await refresh();
      ref.invalidate(simLinesControllerProvider);
    }
    return result;
  }

  /// Saves updated mini refill execution dates
  Future<Result<void>> updateMiniRefillDates(
    String simLineId,
    Map<String, DateTime> executionDates,
  ) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.updateMiniRefillDates(
      simLineId: simLineId,
      executionDates: executionDates,
    );
    if (result is Success<void>) {
      await refresh();
      ref.invalidate(simLinesControllerProvider);
      ref.invalidate(topupExecutionsForLineProvider(simLineId));
    }
    return result;
  }
}

/// Helper provider to get schedule for a specific SIM line.
@riverpod
ScheduledTopup? scheduledTopupForLine(Ref ref, String simLineId) {
  final schedulesAsync = ref.watch(scheduledTopupControllerProvider);
  final list = schedulesAsync.value;
  if (list == null) return null;
  for (final s in list) {
    if (s.simLineId == simLineId) return s;
  }
  return null;
}

/// Helper provider to get Notify schedule for a specific SIM line.
@riverpod
ScheduledTopup? scheduledNotifyForLine(Ref ref, String simLineId) {
  final schedulesAsync = ref.watch(scheduledTopupControllerProvider);
  final list = schedulesAsync.value;
  if (list == null) return null;
  for (final s in list) {
    if (s.simLineId == simLineId && s.scheduleType == 'notify') return s;
  }
  return null;
}

/// Helper provider to get Custom Refill schedule for a specific SIM line.
@riverpod
ScheduledTopup? scheduledCustomRefillForLine(Ref ref, String simLineId) {
  final schedulesAsync = ref.watch(scheduledTopupControllerProvider);
  final list = schedulesAsync.value;
  if (list == null) return null;
  for (final s in list) {
    if (s.simLineId == simLineId && s.scheduleType == 'refill_custom') return s;
  }
  return null;
}

/// Helper provider to get Mini Refill schedule for a specific SIM line.
@riverpod
ScheduledTopup? scheduledMiniRefillForLine(Ref ref, String simLineId) {
  final schedulesAsync = ref.watch(scheduledTopupControllerProvider);
  final list = schedulesAsync.value;
  if (list == null) return null;
  for (final s in list) {
    if (s.simLineId == simLineId && s.scheduleType == 'refill_mini') return s;
  }
  return null;
}

/// Family provider to watch execution history for a SIM Line.
@riverpod
FutureOr<List<TopupExecution>> topupExecutionsForLine(
  Ref ref,
  String simLineId,
) async {
  final repo = ref.watch(scheduledTopupRepositoryProvider);
  final result = await repo.getExecutionsForLine(simLineId);
  return switch (result) {
    Success(data: final list) => list,
    Failure(error: final failure) => throw Exception(failure.message),
  };
}

/// Live execution status for a SIM line (C3).
///
/// An instant refill is handed to worker_instant_refill, whose round trip has
/// no fixed duration — it debits the wallet, calls the provider, and may refund.
/// The UI used to guess with a 3-second timer, which refreshed the balance
/// either before the worker had finished or long after. Streaming the row means
/// the status and the wallet update exactly when the worker actually moves them.
@riverpod
Stream<List<TopupExecution>> topupExecutionsLive(Ref ref, String simLineId) {
  return Supabase.instance.client
      .from('topup_executions')
      .stream(primaryKey: ['id'])
      .eq('sim_line_id', simLineId)
      .order('created_at')
      .map((rows) => rows.map(TopupExecution.fromJson).toList());
}

/// Paginated execution history provider.
@riverpod
class SimLineExecutionsHistory extends _$SimLineExecutionsHistory {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  FutureOr<List<TopupExecution>> build(String simLineId) async {
    _currentPage = 1;
    _isLoadingMore = false;
    final initialList = await _fetchPage(1);
    _hasMore = initialList.length >= 15;
    return initialList;
  }

  Future<List<TopupExecution>> _fetchPage(int page) async {
    final repo = ref.read(scheduledTopupRepositoryProvider);
    final result = await repo.getExecutionsForLinePaginated(
      simLineId: simLineId,
      page: page,
      pageSize: 15,
    );
    return switch (result) {
      Success(data: final list) => list,
      Failure(error: final failure) => throw Exception(failure.message),
    };
  }

  Future<void> loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    final currentList = state.value ?? [];

    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPage(nextPage);

      if (result.isEmpty || result.length < 15) {
        _hasMore = false;
      }

      _currentPage = nextPage;
      state = AsyncValue.data([...currentList, ...result]);
    } catch (e) {
      // Keep previous list
    } finally {
      _isLoadingMore = false;
    }
  }
}
