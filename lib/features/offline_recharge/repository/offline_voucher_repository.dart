import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';

import '../data/voucher_vault.dart';
import '../model/offline_voucher_model.dart';

/// The emergency-PIN rail.
///
/// Everything here splits along one line: **what must work with no network**,
/// and what does not. Only two operations are on the first side — reading a
/// stored voucher and revealing it — and both touch nothing but the keystore.
/// Provisioning, reporting and settling all require the server and all fail
/// loudly rather than pretending.
class OfflineVoucherRepository {
  OfflineVoucherRepository(
    this._client,
    this._vault,
    this._cache,
    this._connectivity,
    this._deviceIdentity,
  );

  final SupabaseClient _client;
  final VoucherVault _vault;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final DeviceIdentityService _deviceIdentity;

  static const _stateCacheKey = 'cached_offline_voucher_state';

  // ───────────────────────────────────────────────────────── server state ──

  /// The server's view: who is entitled, what is outstanding, what is stocked.
  ///
  /// Cached so the offline screen can still render the *context* around a PIN
  /// with no signal. The cached copy is explicitly not authoritative for money
  /// — settlement always re-reads.
  Future<Result<OfflineVoucherState>> getState() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson(_stateCacheKey);
      if (cached is Map) {
        return Success(
          OfflineVoucherState.fromJson(Map<String, dynamic>.from(cached)),
        );
      }
      return const Success(OfflineVoucherState());
    }

    try {
      final res = await _client.rpc('offline_voucher_state');
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) {
        return Failure(
          AppFailure.server(message: (map['code'] ?? 'unknown').toString()),
        );
      }
      await _cache.writeJson(_stateCacheKey, map);
      return Success(OfflineVoucherState.fromJson(map));
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(_stateCacheKey);
      if (cached is Map) {
        return Success(
          OfflineVoucherState.fromJson(Map<String, dynamic>.from(cached)),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final cached = _cache.readJson(_stateCacheKey);
      if (cached is Map) {
        return Success(
          OfflineVoucherState.fromJson(Map<String, dynamic>.from(cached)),
        );
      }
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  // ────────────────────────────────────────────────────────── provisioning ──

  /// Collects a PIN for [simLineId] and puts it in the keystore.
  ///
  /// Must be called while ONLINE — that is the whole point of doing it early.
  /// Re-calling for a line that already has a live voucher returns the same PIN
  /// (the server is idempotent), which is what makes a reinstall recoverable
  /// instead of stranding someone who is about to lose signal.
  Future<Result<VoucherProvisionResult>> provision(String simLineId) async {
    if (_connectivity.isOffline) {
      return const Success(
        VoucherProvisionResult(code: VoucherProvisionCode.offline),
      );
    }

    try {
      final deviceId = await _deviceIdentity.deviceId();
      final res = await _client.rpc(
        'provision_offline_voucher',
        params: {'p_sim_line_id': simLineId, 'p_device_id': deviceId},
      );
      final map = Map<String, dynamic>.from(res as Map);

      if (map['success'] != true) {
        return Success(
          VoucherProvisionResult(
            code: (map['code'] ?? 'UNKNOWN').toString(),
            grantId: map['grant_id']?.toString(),
            amountDueUsd: _num(map['amount_due_usd']),
            expectedBy: _date(map['expected_by']),
          ),
        );
      }

      final voucher = StoredVoucher(
        grantId: map['grant_id'].toString(),
        simLineId: simLineId,
        pin: map['pin'].toString(),
        serial: map['serial']?.toString(),
        faceValueUsd: _num(map['face_value_usd']) ?? 0,
        amountDueUsd: _num(map['amount_due_usd']) ?? 0,
        instructions: (map['instructions'] ?? '').toString(),
        redeemUssdTemplate: map['redeem_ussd_template']?.toString(),
        expiresAt: _date(map['expires_at']),
        storedAt: DateTime.now(),
      );

      // A re-issue of a voucher this device already revealed must not lose the
      // local reveal state — that would silently drop a debt we owe a report
      // on, and the subscriber would be handed a fresh-looking PIN they have
      // already spent.
      final existing = await _vault.read(simLineId);
      final merged = (existing != null &&
              existing.grantId == voucher.grantId &&
              existing.isRevealed)
          ? voucher.copyWith(
              revealedAt: existing.revealedAt,
              reported: existing.reported,
            )
          : voucher;

      await _vault.save(merged);
      return Success(
        VoucherProvisionResult(
          code: VoucherProvisionCode.ok,
          voucher: merged,
          grantId: merged.grantId,
          amountDueUsd: merged.amountDueUsd,
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('Failed host lookup')) {
        return const Success(
          VoucherProvisionResult(code: VoucherProvisionCode.offline),
        );
      }
      return Failure(AppFailure.unknown(message: s));
    }
  }

  // ───────────────────────────────────────────────────────────── the vault ──

  Future<StoredVoucher?> stored(String simLineId) => _vault.read(simLineId);

  Future<List<StoredVoucher>> allStored() => _vault.readAllVouchers();

  /// Reveals the PIN. **Local only, by design** — this runs when there is no
  /// network, so it cannot depend on one. The reveal is stamped in the keystore
  /// first so that a phone killed a second later still knows a debt was
  /// incurred, and [syncReveals] tells the server when it can.
  Future<StoredVoucher?> reveal(String simLineId) async {
    final v = await _vault.read(simLineId);
    if (v == null) return null;
    if (v.isRevealed) return v;
    return _vault.markRevealed(v);
  }

  Future<void> clearVault() => _vault.clear();

  // ──────────────────────────────────────────────────────────── reporting ──

  /// Tells the server about every reveal it has not heard about yet.
  ///
  /// Best-effort and idempotent: the RPC clamps the timestamp and refuses to
  /// re-price a grant it has already seen, so calling this on every resume is
  /// safe. Returns how many reports landed.
  Future<int> syncReveals() async {
    if (_connectivity.isOffline) return 0;

    var reported = 0;
    for (final v in await _vault.readAllVouchers()) {
      if (!v.needsReport) continue;
      try {
        final res = await _client.rpc(
          'report_offline_voucher_reveal',
          params: {
            'p_grant_id': v.grantId,
            'p_revealed_at': v.revealedAt!.toUtc().toIso8601String(),
          },
        );
        final map = Map<String, dynamic>.from(res as Map);
        if (map['success'] == true) {
          await _vault.markReported(
            v.copyWith(amountDueUsd: _num(map['amount_due_usd']) ?? v.amountDueUsd),
          );
          reported++;
        } else if (map['code'] == 'GRANT_NOT_FOUND') {
          // The grant is gone server-side (written off, or the line was
          // deleted). Keeping a local record of a debt nobody is owed would
          // block this line from ever getting another PIN.
          await _vault.remove(v.simLineId);
        }
      } catch (_) {
        // Leave it unreported; the next resume tries again. Never drop it.
      }
    }
    return reported;
  }

  // ─────────────────────────────────────────────────────────── settlement ──

  /// Pays for a revealed voucher out of the wallet. Explicit — nothing here is
  /// called automatically.
  Future<Result<Map<String, dynamic>>> settle(String grantId) async {
    if (_connectivity.isOffline) {
      return const Failure(AppFailure.network());
    }
    try {
      final res = await _client.rpc(
        'settle_offline_voucher',
        params: {'p_grant_id': grantId},
      );
      final map = Map<String, dynamic>.from(res as Map);

      if (map['success'] == true) {
        // The debt is closed, so the PIN's local copy has no further job. It is
        // already spent at the carrier; keeping it invites a second attempt to
        // redeem a dead code.
        for (final v in await _vault.readAllVouchers()) {
          if (v.grantId == grantId) await _vault.remove(v.simLineId);
        }
      }
      return Success(map);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  // ───────────────────────────────────────────────────────────── plumbing ──

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
