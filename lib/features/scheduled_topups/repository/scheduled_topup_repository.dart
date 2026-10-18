/// SIM Shield — Scheduled Top-Up Repository
///
/// Implements [ScheduledTopupContract] using Supabase.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import '../contract/scheduled_topup_contract.dart';
import '../model/scheduled_topup_model.dart';
import '../model/topup_execution_model.dart';
import '../model/refill_approval_quote.dart';
import '../model/schedule_mutation_request.dart';

class ScheduledTopupRepository implements ScheduledTopupContract {
  final SupabaseClient _client;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final SyncQueue _syncQueue;

  ScheduledTopupRepository(
    this._client,
    this._cache,
    this._connectivity,
    this._syncQueue,
  );

  String get _scheduleCacheKey =>
      'retail_schedules_v1_${_client.auth.currentUser?.id}';

  @override
  Future<Result<List<ScheduledTopup>>> getSchedules() async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson(_scheduleCacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => ScheduledTopup.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
        );
      }
      return const Success([]);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await AuthSessionManager.withAuthRecovery(
        _client,
        () => _client
            .from('customer_scheduled_topups')
            .select(
              'id,sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,last_execution_at,is_active,retry_count,max_retries,status,created_at,updated_at,whatsapp_sent_this_cycle,schedule_type,offer_id,offer_value,pricing_tier,fee_rule_version,target_local_value,target_local_currency,max_authorized_usd,preferred_provider,engine_version,intent_kind',
            )
            .eq('user_id', userId),
      );

      await _cache.writeJson(_scheduleCacheKey, response);

      final schedules = (response as List)
          .map((json) => ScheduledTopup.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(schedules);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(_scheduleCacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => ScheduledTopup.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup?>> getScheduleForLine(String simLineId) async {
    if (_connectivity.isOffline) {
      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final matches = cached.where(
        (e) => e is Map && e['sim_line_id'] == simLineId,
      );
      if (matches.isNotEmpty) {
        return Success(
          ScheduledTopup.fromJson(matches.first as Map<String, dynamic>),
        );
      }
      return const Success(null);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('customer_scheduled_topups')
          .select(
            'id,sim_line_id,user_id,amount,currency,frequency_days,next_execution_at,last_execution_at,is_active,retry_count,max_retries,status,created_at,updated_at,whatsapp_sent_this_cycle,schedule_type,offer_id,offer_value,pricing_tier,fee_rule_version,target_local_value,target_local_currency,max_authorized_usd,preferred_provider,engine_version,intent_kind',
          )
          .eq('sim_line_id', simLineId)
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return const Success(null);
      }

      return Success(ScheduledTopup.fromJson(response));
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final matches = cached.where(
        (e) => e is Map && e['sim_line_id'] == simLineId,
      );
      if (matches.isNotEmpty) {
        return Success(
          ScheduledTopup.fromJson(matches.first as Map<String, dynamic>),
        );
      }
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup>> createSchedule(ScheduledTopup schedule) async {
    if (_connectivity.isOffline) {
      if (schedule.scheduleType.startsWith('refill')) {
        return const Failure(
          AppFailure.server(
            message:
                'Auto-Refill settings require an active internet connection.',
          ),
        );
      }

      // Handle Notify Schedule Offline
      final userId = _client.auth.currentUser?.id ?? '';
      final localId = schedule.id.isEmpty
          ? 'offline_sched_${DateTime.now().microsecondsSinceEpoch}'
          : schedule.id;
      final updatedSchedule = schedule.copyWith(id: localId, userId: userId);
      final data = updatedSchedule.toJson();

      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final updatedCache = cached
          .where(
            (item) =>
                item is Map &&
                !(item['sim_line_id'] == schedule.simLineId &&
                    item['schedule_type'] == schedule.scheduleType),
          )
          .toList();
      updatedCache.add(data);
      await _cache.writeJson(_scheduleCacheKey, updatedCache);

      await _syncQueue.addToQueue('topup_schedule_save', data);
      return Success(updatedSchedule);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final updatedSchedule = schedule.copyWith(
        nextExecutionAt: schedule.nextExecutionAt.toUtc(),
        lastExecutionAt: schedule.lastExecutionAt?.toUtc(),
      );
      final data = updatedSchedule.toJson();
      if (updatedSchedule.id.isEmpty) {
        data.remove('id');
      }
      if (updatedSchedule.userId.isEmpty) {
        data.remove('user_id');
      }
      data['user_id'] = userId;

      final response = Map<String, dynamic>.from(
        await _client.rpc(
              'save_customer_schedule',
              params: ScheduleMutationRequest.fromJson(data),
            )
            as Map,
      );

      final created = ScheduledTopup.fromJson(response);

      // C3b-2: a refill_custom schedule's execution queue is managed by the
      // trg_sync_custom_refill_queue DB trigger; the insert here is gone.

      // Update local cache
      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final updatedCache = cached
          .where((item) => item is Map && item['id'] != created.id)
          .toList();
      updatedCache.add(response);
      await _cache.writeJson(_scheduleCacheKey, updatedCache);

      return Success(created);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup>> updateSchedule(ScheduledTopup schedule) async {
    if (_connectivity.isOffline) {
      if (schedule.scheduleType.startsWith('refill')) {
        return const Failure(
          AppFailure.server(
            message:
                'Auto-Refill settings require an active internet connection.',
          ),
        );
      }

      // Handle Notify Schedule Offline
      final data = schedule.toJson();
      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final updatedCache = cached.map((item) {
        if (item is Map && item['id'] == schedule.id) return data;
        return item;
      }).toList();
      await _cache.writeJson(_scheduleCacheKey, updatedCache);

      await _syncQueue.addToQueue('topup_schedule_save', data);
      return Success(schedule);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final updatedSchedule = schedule.copyWith(
        nextExecutionAt: schedule.nextExecutionAt.toUtc(),
        lastExecutionAt: schedule.lastExecutionAt?.toUtc(),
      );
      final data = updatedSchedule.toJson();
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      if (updatedSchedule.id.isEmpty) {
        data.remove('id');
      }
      if (updatedSchedule.userId.isEmpty) {
        data.remove('user_id');
      } else {
        data['user_id'] = userId;
      }

      final response = Map<String, dynamic>.from(
        await _client.rpc(
              'save_customer_schedule',
              params: ScheduleMutationRequest.fromJson(data),
            )
            as Map,
      );

      final updated = ScheduledTopup.fromJson(response);

      // C3b-2: requeueing after an amount/date change is done by the
      // trg_sync_custom_refill_queue DB trigger. (The delete that used to run
      // here was a silent no-op — topup_executions never had a DELETE policy.)

      // Update cache
      final cached = _cache.readJson(_scheduleCacheKey) as List? ?? [];
      final updatedCache = cached.map((item) {
        if (item is Map && item['id'] == updated.id) return response;
        return item;
      }).toList();
      await _cache.writeJson(_scheduleCacheKey, updatedCache);

      return Success(updated);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup>> toggleSchedule({
    required String id,
    required bool isActive,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = Map<String, dynamic>.from(
        await _client.rpc(
              'set_customer_schedule_active',
              params: {'p_schedule_id': id, 'p_is_active': isActive},
            )
            as Map,
      );

      return Success(ScheduledTopup.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteSchedule(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // C3b-2: deleting the schedule cancels its queued executions via the
      // trg_cancel_executions_on_schedule_delete DB trigger. (The client-side
      // delete that used to run here was a silent no-op that left orphans.)
      await _client.rpc(
        'delete_customer_schedule',
        params: {'p_schedule_id': id},
      );

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<List<TopupExecution>>> getExecutionsForLine(
    String simLineId,
  ) async {
    final cacheKey =
        'retail_executions_v1_${_client.auth.currentUser?.id}_$simLineId';

    if (_connectivity.isOffline) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => TopupExecution.fromJson(json as Map<String, dynamic>),
              )
              .toList(),
        );
      }
      return const Success([]);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('customer_topup_executions')
          .select()
          .eq('sim_line_id', simLineId)
          .eq('user_id', userId)
          .order('executed_at', ascending: false);

      final list = (response as List)
          .map((json) => TopupExecution.fromJson(json as Map<String, dynamic>))
          .toList();

      await _cache.writeJson(cacheKey, response);
      return Success(list);
    } on PostgrestException catch (e) {
      final cached = _cache.readJson(cacheKey);
      if (cached is List) {
        return Success(
          cached
              .map(
                (json) => TopupExecution.fromJson(json as Map<String, dynamic>),
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
                (json) => TopupExecution.fromJson(json as Map<String, dynamic>),
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

  @override
  Future<Result<List<TopupExecution>>> getExecutionsForLinePaginated({
    required String simLineId,
    required int page,
    required int pageSize,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final start = (page - 1) * pageSize;
      final end = page * pageSize - 1;

      final response = await _client
          .from('customer_topup_executions')
          .select()
          .eq('sim_line_id', simLineId)
          .eq('user_id', userId)
          .order('executed_at', ascending: false)
          .range(start, end);

      final list = (response as List)
          .map((json) => TopupExecution.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(list);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> retryExecution(String executionId) async {
    try {
      // C3b-2: a retry is a NEW queued execution created server-side
      // (retry_of = original) that runs through the real worker pipeline —
      // actual purchase, real debit/refund. The old client-side flow debited
      // the wallet, fabricated a mock 'success' row and marked the original
      // 'refunded' without ever buying a top-up.
      await _client.rpc(
        'retry_topup_execution',
        params: {'p_execution_id': executionId},
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> cancelExecution(String executionId) async {
    try {
      // C3b-2: the old client DELETE was a silent no-op (no DELETE policy) —
      // the row stayed pending and the worker still fired it. The RPC really
      // cancels queued work ('pending'/'pending_payment' → 'cancelled').
      await _client.rpc(
        'cancel_topup_execution',
        params: {'p_execution_id': executionId},
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> rescheduleMiniRefill({
    required String simLineId,
    required DateTime newDate,
  }) async {
    try {
      await _client.rpc(
        'reschedule_mini_refill',
        params: {
          'p_sim_line_id': simLineId,
          'p_new_date': newDate.toUtc().toIso8601String(),
        },
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<DateTime>> resetMiniRefillToDefault(String simLineId) async {
    try {
      final res = await _client.rpc(
        'reset_mini_refill_to_default',
        params: {'p_sim_line_id': simLineId},
      );
      return Success(DateTime.parse(res as String));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateMiniRefillDates({
    required String simLineId,
    required Map<String, DateTime> executionDates,
  }) async {
    try {
      // C3b-2: one RPC moves the line's own pending refill_mini rows and
      // re-syncs the schedule's next_execution_at server-side.
      await _client.rpc(
        'update_mini_refill_dates',
        params: {
          'p_sim_line_id': simLineId,
          'p_updates': {
            for (final entry in executionDates.entries)
              entry.key: entry.value.toUtc().toIso8601String(),
          },
        },
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<RefillApprovalQuote>> prepareExecutionApproval(
    String executionId,
  ) async {
    try {
      final quoteId = await _client.rpc(
        'request_refill_approval_quote',
        params: {'p_execution_id': executionId},
      );
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(deadline)) {
        final row = await _client
            .from('customer_refill_approval_quotes')
            .select('id,status,route,error_message,expires_at')
            .eq('id', quoteId as String)
            .single();
        if (row['status'] == 'failed') {
          return Failure(
            AppFailure.server(message: row['error_message'] as String),
          );
        }
        if (row['status'] == 'ready') {
          final quote = RefillApprovalQuote.fromJson(row);
          if (quote.expiresAt.isAfter(
            DateTime.now().add(const Duration(seconds: 10)),
          )) {
            return Success(quote);
          }
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      return const Failure(
        AppFailure.server(
          message:
              'The price check took too long. No refill was submitted. Please try again.',
        ),
      );
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return const Failure(
        AppFailure.network(
          message:
              'Could not check the current price. Please check your connection and try again.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> approveExecution({
    required String executionId,
    required String quoteId,
    required double newMaxAuthorizedUsd,
  }) async {
    try {
      final response = await _client.rpc(
        'approve_refill_execution_quote',
        params: {
          'p_quote_id': quoteId,
          'p_expected_amount': newMaxAuthorizedUsd,
        },
      );
      if (response is! Map ||
          response['success'] != true ||
          response['execution_id'] != executionId) {
        return const Failure(
          AppFailure.server(
            message: 'Approval was not confirmed. Refresh the refill status.',
          ),
        );
      }
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
