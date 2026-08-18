import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/biometric_lock_controller.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/supabase_client.dart';

import '../data/voucher_vault.dart';
import '../model/offline_voucher_model.dart';
import '../repository/offline_voucher_repository.dart';

part 'offline_voucher_controller.g.dart';

@Riverpod(keepAlive: true)
VoucherVault voucherVault(Ref ref) =>
    VoucherVault(ref.watch(secureStorageProvider));

@Riverpod(keepAlive: true)
OfflineVoucherRepository offlineVoucherRepository(Ref ref) {
  return OfflineVoucherRepository(
    supabase,
    ref.watch(voucherVaultProvider),
    ref.watch(localCacheServiceProvider),
    ref.watch(connectivityServiceProvider.notifier),
    ref.watch(deviceIdentityServiceProvider),
  );
}

/// The server's voucher picture. Kept separate from the on-device vault so a
/// screen can render "you owe $2.50" from the cache with no signal while the
/// PIN itself never leaves the keystore.
@riverpod
class OfflineVoucherStateController extends _$OfflineVoucherStateController {
  @override
  FutureOr<OfflineVoucherState> build() async {
    final repo = ref.watch(offlineVoucherRepositoryProvider);

    // Flush any reveal the handset is still carrying before reporting state,
    // or the screen shows "sealed" over a PIN the user already spent.
    unawaited(repo.syncReveals());

    final result = await repo.getState();
    return switch (result) {
      Success(data: final s) => s,
      Failure(error: final e) => throw Exception(e.message),
    };
  }

  Future<void> refresh() async {
    final repo = ref.read(offlineVoucherRepositoryProvider);
    await repo.syncReveals();
    ref.invalidateSelf();
  }

  /// Collects a PIN while online. Returns the outcome so the caller can tell
  /// "you owe for the last one" from "we have not stocked your carrier yet".
  Future<VoucherProvisionResult> provision(String simLineId) async {
    final repo = ref.read(offlineVoucherRepositoryProvider);
    final result = await repo.provision(simLineId);
    ref.invalidateSelf();
    return switch (result) {
      Success(data: final r) => r,
      Failure(error: final e) => VoucherProvisionResult(
          code: VoucherProvisionCode.error,
          message: e.message,
        ),
    };
  }

  Future<Map<String, dynamic>> settle(String grantId) async {
    final repo = ref.read(offlineVoucherRepositoryProvider);
    final result = await repo.settle(grantId);
    ref.invalidateSelf();
    ref.invalidate(storedVouchersProvider);
    return switch (result) {
      Success(data: final m) => m,
      Failure(error: final e) => {'success': false, 'error': e.message},
    };
  }
}

/// Everything in the keystore. Reads fine with no network — this is what the
/// emergency card renders from when there is no signal at all.
@riverpod
Future<List<StoredVoucher>> storedVouchers(Ref ref) async {
  final repo = ref.watch(offlineVoucherRepositoryProvider);
  return repo.allStored();
}

/// The voucher held for one line, or null.
@riverpod
Future<StoredVoucher?> storedVoucher(Ref ref, String simLineId) async {
  final all = await ref.watch(storedVouchersProvider.future);
  for (final v in all) {
    if (v.simLineId == simLineId) return v;
  }
  return null;
}

/// Reveals a PIN. Local-only and deliberately not part of the state
/// controller: it is the one action that must work with the radio off, so it
/// touches no provider that can await the network.
@riverpod
class VoucherRevealController extends _$VoucherRevealController {
  @override
  FutureOr<void> build() {}

  Future<StoredVoucher?> reveal(String simLineId) async {
    final repo = ref.read(offlineVoucherRepositoryProvider);
    final revealed = await repo.reveal(simLineId);
    ref.invalidate(storedVouchersProvider);
    // Best-effort: if there IS signal, tell the server now. If not, the next
    // resume does it — the reveal is already durable in the keystore.
    unawaited(repo.syncReveals());
    return revealed;
  }
}
