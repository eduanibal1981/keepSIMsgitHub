import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/providers.dart';
import '../model/offline_refill_model.dart';

part 'offline_refill_controller.g.dart';

@riverpod
class OfflineRefillController extends _$OfflineRefillController {
  @override
  FutureOr<OfflineRefillSettings> build() async {
    final repo = ref.watch(offlineRefillRepositoryProvider);
    final result = await repo.getSettings();

    return switch (result) {
      Success(data: final settings) => settings,
      Failure(error: final e) => throw Exception(e.message),
    };
  }

  Future<bool> saveSettings(OfflineRefillSettings settings) async {
    state = const AsyncLoading<OfflineRefillSettings>().copyWithPrevious(state);

    final repo = ref.read(offlineRefillRepositoryProvider);
    final result = await repo.saveSettings(settings);

    switch (result) {
      case Success(data: final updated):
        state = AsyncData(updated);
        ref.invalidateSelf();
        return true;
      case Failure(error: final f):
        state = AsyncValue.error(f.message, StackTrace.current);
        return false;
    }
  }
}

@riverpod
Future<List<CarrierUssdSuggestion>> carrierUssdSuggestions(
  Ref ref,
  String carrierId,
) async {
  final repo = ref.watch(offlineRefillRepositoryProvider);
  final result = await repo.getUssdSuggestions(carrierId);

  return switch (result) {
    Success(data: final list) => list,
    Failure(error: final e) => throw Exception(e.message),
  };
}

/// The locally-queued offline refills, reconciled against the server on build
/// (C4). Drives the per-channel status chips: a refill is queued locally the
/// moment the user launches WhatsApp / SMS / the dialer, then resolves to
/// confirmed / failed / timed-out as the channel's webhook creates (or never
/// creates) the matching `topup_executions` row.
@riverpod
class PendingOfflineRefillsController extends _$PendingOfflineRefillsController {
  @override
  FutureOr<List<PendingOfflineRefill>> build() async {
    final repo = ref.watch(offlineRefillRepositoryProvider);
    final result = await repo.getPendingRefills();
    return switch (result) {
      Success(data: final list) => list,
      Failure(error: final e) => throw Exception(e.message),
    };
  }

  /// Persists a pending refill BEFORE the UI launches the external app, so the
  /// request survives the app being killed mid-flow. Returns it so the UI can
  /// mark it failed if the launch itself fails.
  Future<PendingOfflineRefill> enqueue({
    required String channel,
    required String simLineId,
    required String phoneNumber,
    required double amount,
  }) async {
    final repo = ref.read(offlineRefillRepositoryProvider);
    final request = PendingOfflineRefill(
      id: 'ofr_${DateTime.now().microsecondsSinceEpoch}',
      channel: channel,
      simLineId: simLineId,
      phoneNumber: phoneNumber,
      amount: amount,
      launchedAt: DateTime.now(),
    );
    final result = await repo.queuePendingRefill(request);
    ref.invalidateSelf();
    return switch (result) {
      Success(data: final r) => r,
      Failure(error: final e) => throw Exception(e.message),
    };
  }

  /// Marks a queued refill failed — e.g. the external app could not be opened.
  Future<void> markFailed(PendingOfflineRefill request, String reason) async {
    final repo = ref.read(offlineRefillRepositoryProvider);
    await repo.updatePendingRefill(
      request.copyWith(
        status: PendingRefillStatus.failed,
        failureReason: reason,
      ),
    );
    ref.invalidateSelf();
  }

  /// Re-reconciles the queue against the server (call on resume / reconnect).
  void refresh() => ref.invalidateSelf();
}
