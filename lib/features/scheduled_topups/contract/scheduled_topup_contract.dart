/// SIM Shield — Scheduled Top-Up Contract interface
library;

import '../model/scheduled_topup_model.dart';
import '../model/topup_execution_model.dart';
import '../../../core/result.dart';

abstract interface class ScheduledTopupContract {
  /// Fetches all scheduled top-ups for the active user.
  Future<Result<List<ScheduledTopup>>> getSchedules();

  /// Fetches the scheduled top-up configuration for a specific SIM line, if it exists.
  Future<Result<ScheduledTopup?>> getScheduleForLine(String simLineId);

  /// Creates a new scheduled top-up configuration.
  Future<Result<ScheduledTopup>> createSchedule(ScheduledTopup schedule);

  /// Updates an existing scheduled top-up configuration.
  Future<Result<ScheduledTopup>> updateSchedule(ScheduledTopup schedule);

  /// Pauses or resumes a top-up schedule.
  Future<Result<ScheduledTopup>> toggleSchedule({
    required String id,
    required bool isActive,
  });

  /// Deletes a scheduled top-up.
  Future<Result<void>> deleteSchedule(String id);

  /// Performs a high-fidelity simulated execution of the scheduled top-up.
  /// Deducts funds from the user wallet, creates a completed debit transaction,
  /// logs a success execution entry, updates the target SIM line parameters,
  /// and updates the scheduled top-up's next execution date.
  Future<Result<void>> simulateExecution(String id);

  /// Fetches execution history for a SIM line.
  Future<Result<List<TopupExecution>>> getExecutionsForLine(String simLineId);

  /// Fetches paginated execution history for a SIM line, excluding mock data.
  Future<Result<List<TopupExecution>>> getExecutionsForLinePaginated({
    required String simLineId,
    required int page,
    required int pageSize,
  });

  /// Retries a failed execution by ID.
  Future<Result<void>> retryExecution(String executionId);

  /// Deletes a specific execution record (e.g. for mock log deletion).
  Future<Result<void>> deleteExecution(String executionId);

  /// Reschedules the next execution date of a mini refill schedule and its earliest pending execution.
  Future<Result<void>> rescheduleMiniRefill({
    required String simLineId,
    required DateTime newDate,
  });

  /// Resets the next execution date of a mini refill schedule and its earliest pending execution back to default.
  Future<Result<DateTime>> resetMiniRefillToDefault(String simLineId);

  /// Updates execution dates for a set of pending executions and syncs the schedule's next execution date.
  Future<Result<void>> updateMiniRefillDates({
    required String simLineId,
    required Map<String, DateTime> executionDates,
  });
}
