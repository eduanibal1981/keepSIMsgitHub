import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import '../contract/offline_refill_contract.dart';
import '../model/offline_refill_model.dart';

class OfflineRefillRepository implements OfflineRefillContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;

  OfflineRefillRepository(this._client, this._cache, this._connectivity);

  @override
  Future<Result<OfflineRefillSettings>> getSettings() async {
    const cacheKey = 'cached_offline_refill_settings';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return Success(
          OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
        );
      }
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final mockSettings = OfflineRefillSettings(
          userId: userId,
          isEnabled: true,
          defaultRefillAmount: 10.00,
        );
        return Success(mockSettings);
      }
      return const Failure(
        AppFailure.auth(message: 'No internet connection and not logged in.'),
      );
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      try {
        final response = await _client
            .from('offline_refill_settings')
            .select()
            .eq('user_id', userId)
            .single();

        await _cache.writeJson(cacheKey, response);
        return Success(OfflineRefillSettings.fromJson(response));
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          // Seed initial settings if none exist. default_refill_amount is
          // deliberately omitted so the DB column default applies — changing
          // it is a schema-side ALTER, not an app update (C3c).
          final newSettings = {
            'user_id': userId,
            'is_enabled': true,
          };
          // Insert into Supabase
          final inserted = await _client
              .from('offline_refill_settings')
              .insert(newSettings)
              .select()
              .single();
          await _cache.writeJson(cacheKey, inserted);
          return Success(OfflineRefillSettings.fromJson(inserted));
        }
        final cached = _cache.readJson(cacheKey);
        if (cached != null) {
          return Success(
            OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
          );
        }
        return Failure(AppFailure.server(message: e.message));
      }
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached != null) {
        return Success(
          OfflineRefillSettings.fromJson(cached as Map<String, dynamic>),
        );
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }

  @override
  Future<Result<OfflineRefillSettings>> saveSettings(
    OfflineRefillSettings settings,
  ) async {
    const cacheKey = 'cached_offline_refill_settings';
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final data = settings
          .copyWith(userId: userId, updatedAt: DateTime.now())
          .toJson();

      if (_connectivity.isOffline) {
        await _cache.writeJson(cacheKey, data);
        return Success(settings);
      }

      // Upsert
      final response = await _client
          .from('offline_refill_settings')
          .upsert(data)
          .select()
          .single();

      await _cache.writeJson(cacheKey, response);
      return Success(OfflineRefillSettings.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }

  @override
  Future<Result<List<CarrierUssdSuggestion>>> getUssdSuggestions(
    String carrierId,
  ) async {
    final cacheKey = 'cached_ussd_suggestions_$carrierId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      return const Success([]);
    }

    try {
      final response = await _client
          .from('carrier_ussd_suggestions')
          .select()
          .eq('carrier_id', carrierId);

      final list = (response as List)
          .map(
            (json) =>
                CarrierUssdSuggestion.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      await _cache.writeJson(cacheKey, response);
      return Success(list);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => CarrierUssdSuggestion.fromJson(
                  json as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      }
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        return const Failure(AppFailure.network());
      }
      return Failure(AppFailure.unknown(message: errStr));
    }
  }

  // ── Pending offline refills (persist-before-launch + reconcile, C4) ────────
  static const _pendingKey = 'pending_offline_refills';

  List<PendingOfflineRefill> _readPending() {
    final cached = _cache.readJson(_pendingKey);
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map(
            (j) => PendingOfflineRefill.fromJson(
              Map<String, dynamic>.from(j),
            ),
          )
          .toList();
    }
    return [];
  }

  Future<void> _writePending(List<PendingOfflineRefill> list) async {
    await _cache.writeJson(_pendingKey, list.map((e) => e.toJson()).toList());
  }

  /// Drops terminal entries older than 6h so a resolved card doesn't linger
  /// forever; keeps everything still reconciling.
  List<PendingOfflineRefill> _prune(List<PendingOfflineRefill> list) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    return list
        .where(
          (p) =>
              !PendingRefillStatus.isTerminal(p.status) ||
              p.launchedAt.isAfter(cutoff),
        )
        .toList();
  }

  @override
  Future<Result<PendingOfflineRefill>> queuePendingRefill(
    PendingOfflineRefill request,
  ) async {
    try {
      final list = _readPending()..insert(0, request);
      // Only recent requests matter for reconciliation — cap the queue.
      await _writePending(list.take(20).toList());
      return Success(request);
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> updatePendingRefill(PendingOfflineRefill request) async {
    try {
      final list = _readPending();
      final idx = list.indexWhere((e) => e.id == request.id);
      if (idx >= 0) {
        list[idx] = request;
      } else {
        list.insert(0, request);
      }
      await _writePending(list.take(20).toList());
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<List<PendingOfflineRefill>>> getPendingRefills() async {
    final stored = _readPending();
    if (_connectivity.isOffline) {
      return Success(_prune(stored));
    }
    try {
      final reconciled = _prune(await _reconcile(stored));
      await _writePending(reconciled);
      return Success(reconciled);
    } catch (_) {
      // Reconciliation is best-effort — never hide the queue behind an error.
      return Success(_prune(stored));
    }
  }

  /// Matches each non-terminal pending against the server-created
  /// `topup_executions` row the channel's webhook queued (same line, same
  /// `refill_channel`, on/after launch). No match within 15 min ⇒ the message
  /// or call never reached us ⇒ timed out.
  Future<List<PendingOfflineRefill>> _reconcile(
    List<PendingOfflineRefill> list,
  ) async {
    final out = <PendingOfflineRefill>[];
    for (final p in list) {
      if (PendingRefillStatus.isTerminal(p.status)) {
        out.add(p);
        continue;
      }
      try {
        final rows = await _client
            .from('topup_executions')
            .select('id,status,created_at')
            .eq('sim_line_id', p.simLineId)
            .eq('refill_channel', p.channel)
            .gte(
              'created_at',
              p.launchedAt
                  .subtract(const Duration(minutes: 2))
                  .toIso8601String(),
            )
            .order('created_at', ascending: false)
            .limit(1);

        if (rows.isNotEmpty) {
          final row = rows.first;
          out.add(
            p.copyWith(
              executionId: row['id'] as String?,
              status: _mapExecStatus((row['status'] as String?) ?? ''),
            ),
          );
        } else if (p.launchedAt.isBefore(
          DateTime.now().subtract(const Duration(minutes: 15)),
        )) {
          out.add(p.copyWith(status: PendingRefillStatus.timedOut));
        } else {
          out.add(p);
        }
      } catch (_) {
        out.add(p);
      }
    }
    return out;
  }

  String _mapExecStatus(String execStatus) {
    switch (execStatus) {
      case 'success':
        return PendingRefillStatus.confirmed;
      case 'failed':
      case 'refunded':
      case 'cancelled':
        return PendingRefillStatus.failed;
      default:
        return PendingRefillStatus.processing;
    }
  }
}
