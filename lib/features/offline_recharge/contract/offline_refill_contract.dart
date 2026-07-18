import '../model/offline_refill_model.dart';
import 'package:keep_sims/core/result.dart';

abstract interface class OfflineRefillContract {
  Future<Result<OfflineRefillSettings>> getSettings();
  Future<Result<OfflineRefillSettings>> saveSettings(
    OfflineRefillSettings settings,
  );
  Future<Result<List<CarrierUssdSuggestion>>> getUssdSuggestions(
    String carrierId,
  );

  /// Reads the local queue of offline refills, reconciled against
  /// `topup_executions` when online (each pending → confirmed/failed/timed_out).
  Future<Result<List<PendingOfflineRefill>>> getPendingRefills();

  /// Persists a pending refill locally BEFORE the external app is launched.
  Future<Result<PendingOfflineRefill>> queuePendingRefill(
    PendingOfflineRefill request,
  );

  /// Replaces a queued refill by id (e.g. to mark it sent or launch-failed).
  Future<Result<void>> updatePendingRefill(PendingOfflineRefill request);
}
