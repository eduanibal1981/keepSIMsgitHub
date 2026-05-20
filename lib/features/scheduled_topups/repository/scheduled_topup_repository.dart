/// SIM Shield — Scheduled Top-Up Repository
///
/// Implements [ScheduledTopupContract] using Supabase.
library;

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/result.dart';
import '../contract/scheduled_topup_contract.dart';
import '../model/scheduled_topup_model.dart';
import '../model/topup_execution_model.dart';

class ScheduledTopupRepository implements ScheduledTopupContract {
  final SupabaseClient _client;

  ScheduledTopupRepository(this._client);

  @override
  Future<Result<List<ScheduledTopup>>> getSchedules() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('scheduled_topups')
          .select()
          .eq('user_id', userId);

      final schedules = (response as List)
          .map((json) => ScheduledTopup.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(schedules);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup?>> getScheduleForLine(String simLineId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('scheduled_topups')
          .select()
          .eq('sim_line_id', simLineId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return const Success(null);
      }

      return Success(ScheduledTopup.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup>> createSchedule(ScheduledTopup schedule) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final data = schedule.toJson();
      if (schedule.id.isEmpty) {
        data.remove('id');
      }
      if (schedule.userId.isEmpty) {
        data.remove('user_id');
      }
      data['user_id'] = userId;

      final response = await _client
          .from('scheduled_topups')
          .insert(data)
          .select()
          .single();

      return Success(ScheduledTopup.fromJson(response));
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<ScheduledTopup>> updateSchedule(ScheduledTopup schedule) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final data = schedule.toJson();
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('scheduled_topups')
          .update(data)
          .eq('id', schedule.id)
          .eq('user_id', userId)
          .select()
          .single();

      return Success(ScheduledTopup.fromJson(response));
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

      final response = await _client
          .from('scheduled_topups')
          .update({
            'is_active': isActive,
            'status': isActive ? 'active' : 'paused',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

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

      await _client
          .from('scheduled_topups')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> simulateExecution(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // 1. Fetch Schedule Info
      final scheduleRes = await _client
          .from('scheduled_topups')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .single();
      final schedule = ScheduledTopup.fromJson(scheduleRes);

      // 2. Fetch Wallet Info
      final walletRes = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .single();
      final walletId = walletRes['id'] as String;
      final currentBalance = (walletRes['balance'] as num).toDouble();

      // 3. Check Balance
      if (currentBalance < schedule.amount) {
        // Record failed execution in db
        await _client.from('topup_executions').insert({
          'scheduled_topup_id': schedule.id,
          'sim_line_id': schedule.simLineId,
          'user_id': userId,
          'amount': schedule.amount,
          'currency': schedule.currency,
          'status': 'failed',
          'failure_reason': 'Insufficient wallet balance',
          'executed_at': DateTime.now().toIso8601String(),
          'completed_at': DateTime.now().toIso8601String(),
        });

        // Increment retry count
        final newRetryCount = schedule.retryCount + 1;
        final failedPermanently = newRetryCount >= schedule.maxRetries;
        await _client.from('scheduled_topups').update({
          'retry_count': newRetryCount,
          'status': failedPermanently ? 'failed_permanently' : 'active',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', schedule.id);

        // Fetch current SIM Line to update health
        final simRes = await _client
            .from('sim_lines')
            .select()
            .eq('id', schedule.simLineId)
            .single();
        final currentHealth = simRes['health_score'] as int;
        final newHealth = max(0, currentHealth - 25);
        final newStatus = newHealth == 0 ? 'grace_period' : (simRes['status'] as String);

        await _client.from('sim_lines').update({
          'health_score': newHealth,
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', schedule.simLineId);

        // Log failed activity
        await _client.from('line_activity_log').insert({
          'sim_line_id': schedule.simLineId,
          'user_id': userId,
          'event_type': 'topup_failed',
          'description': 'Auto-Refill failed: Insufficient wallet balance.',
          'metadata': {
            'amount': schedule.amount,
            'retry_count': newRetryCount,
            'max_retries': schedule.maxRetries,
            'health_score_after': newHealth,
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        return const Failure(
          AppFailure.server(
            message:
                'Insufficient wallet balance for this auto refill. Please top up your wallet.',
          ),
        );
      }

      final newBalance = currentBalance - schedule.amount;

      // 4. Update Wallet Balance
      await _client
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      // 5. Insert Wallet Transaction (debit)
      await _client.from('wallet_transactions').insert({
        'user_id': userId,
        'wallet_id': walletId,
        'amount': schedule.amount,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'type': 'topup_debit',
        'status': 'completed',
        'description': 'Simulated Auto-Refill',
        'sim_line_id': schedule.simLineId,
      });

      // 6. Log Execution
      final mockTxId = 'TX_${100000 + Random().nextInt(900000)}';
      await _client.from('topup_executions').insert({
        'scheduled_topup_id': schedule.id,
        'sim_line_id': schedule.simLineId,
        'user_id': userId,
        'amount': schedule.amount,
        'currency': schedule.currency,
        'status': 'success',
        'reloadly_transaction_id': mockTxId,
        'executed_at': DateTime.now().toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
        'validity_days_added': schedule.frequencyDays,
      });

      // 7. Update Schedule Dates
      final nextExec = DateTime.now().add(
        Duration(days: schedule.frequencyDays),
      );
      await _client
          .from('scheduled_topups')
          .update({
            'last_execution_at': DateTime.now().toIso8601String(),
            'next_execution_at': nextExec.toIso8601String(),
            'retry_count': 0,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', schedule.id);

      // 8. Update SIM Line validity + reset Health Score
      final nextDue = DateTime.now().add(
        Duration(days: schedule.frequencyDays),
      );
      final validityExpires = nextDue.add(
        const Duration(days: 7),
      ); // grace buffer
      await _client
          .from('sim_lines')
          .update({
            'last_topup_at': DateTime.now().toIso8601String(),
            'next_topup_due': nextDue.toIso8601String(),
            'validity_expires_at': validityExpires.toIso8601String(),
            'health_score': 100,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', schedule.simLineId);

      // 9. Log Success Activity
      await _client.from('line_activity_log').insert({
        'sim_line_id': schedule.simLineId,
        'user_id': userId,
        'event_type': 'topup_success',
        'description': 'Auto-Refill successful. Next top-up due in ${schedule.frequencyDays} days.',
        'metadata': {
          'amount': schedule.amount,
          'reloadly_transaction_id': mockTxId,
          'validity_days_added': schedule.frequencyDays,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<List<TopupExecution>>> getExecutionsForLine(String simLineId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      final response = await _client
          .from('topup_executions')
          .select()
          .eq('sim_line_id', simLineId)
          .eq('user_id', userId)
          .order('executed_at', ascending: false);

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
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      // 1. Fetch Execution details
      final execRes = await _client
          .from('topup_executions')
          .select()
          .eq('id', executionId)
          .eq('user_id', userId)
          .single();
      final failedExec = TopupExecution.fromJson(execRes);

      if (failedExec.status != 'failed') {
        return const Failure(
          AppFailure.server(message: 'This execution is not in a failed state.'),
        );
      }

      // 2. Fetch Schedule
      if (failedExec.scheduledTopupId == null) {
        return const Failure(
          AppFailure.server(message: 'No active schedule linked to this execution.'),
        );
      }
      final scheduleRes = await _client
          .from('scheduled_topups')
          .select()
          .eq('id', failedExec.scheduledTopupId!)
          .single();
      final schedule = ScheduledTopup.fromJson(scheduleRes);

      // 3. Fetch Wallet
      final walletRes = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .single();
      final walletId = walletRes['id'] as String;
      final currentBalance = (walletRes['balance'] as num).toDouble();

      // 4. Check Balance
      if (currentBalance < failedExec.amount) {
        // Record retry attempt failed
        final newRetryCount = schedule.retryCount + 1;
        final failedPermanently = newRetryCount >= schedule.maxRetries;

        await _client.from('scheduled_topups').update({
          'retry_count': newRetryCount,
          'status': failedPermanently ? 'failed_permanently' : 'active',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', schedule.id);

        await _client.from('topup_executions').insert({
          'scheduled_topup_id': schedule.id,
          'sim_line_id': failedExec.simLineId,
          'user_id': userId,
          'amount': failedExec.amount,
          'currency': failedExec.currency,
          'status': 'failed',
          'failure_reason': 'Retry failed: Insufficient wallet balance',
          'retry_of': executionId,
          'executed_at': DateTime.now().toIso8601String(),
          'completed_at': DateTime.now().toIso8601String(),
        });

        // Log failed retry activity
        await _client.from('line_activity_log').insert({
          'sim_line_id': failedExec.simLineId,
          'user_id': userId,
          'event_type': 'topup_failed',
          'description': 'Manual retry failed: Insufficient wallet balance.',
          'metadata': {
            'amount': failedExec.amount,
            'retry_count': newRetryCount,
            'max_retries': schedule.maxRetries,
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        return const Failure(
          AppFailure.server(
            message: 'Insufficient balance to retry. Please top up your wallet.',
          ),
        );
      }

      // 5. Deduct Wallet Balance
      final newBalance = currentBalance - failedExec.amount;
      await _client
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      // 6. Wallet Transaction (debit)
      await _client.from('wallet_transactions').insert({
        'user_id': userId,
        'wallet_id': walletId,
        'amount': failedExec.amount,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'type': 'topup_debit',
        'status': 'completed',
        'description': 'Simulated Top-Up Retry',
        'sim_line_id': failedExec.simLineId,
      });

      // 7. Update original execution status or link new successful retry
      final mockTxId = 'TX_RETRY_${100000 + Random().nextInt(900000)}';
      await _client.from('topup_executions').insert({
        'scheduled_topup_id': schedule.id,
        'sim_line_id': failedExec.simLineId,
        'user_id': userId,
        'amount': failedExec.amount,
        'currency': failedExec.currency,
        'status': 'success',
        'reloadly_transaction_id': mockTxId,
        'retry_of': executionId,
        'executed_at': DateTime.now().toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
        'validity_days_added': schedule.frequencyDays,
      });

      // Update failed execution status so it doesn't show as unresolved
      await _client
          .from('topup_executions')
          .update({'status': 'refunded', 'failure_reason': 'Resolved by successful retry'})
          .eq('id', executionId);

      // 8. Update Schedule Dates and reset retry count
      final nextExec = DateTime.now().add(
        Duration(days: schedule.frequencyDays),
      );
      await _client
          .from('scheduled_topups')
          .update({
            'last_execution_at': DateTime.now().toIso8601String(),
            'next_execution_at': nextExec.toIso8601String(),
            'retry_count': 0,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', schedule.id);

      // 9. Update SIM Line
      final nextDue = DateTime.now().add(
        Duration(days: schedule.frequencyDays),
      );
      final validityExpires = nextDue.add(
        const Duration(days: 7),
      );
      await _client
          .from('sim_lines')
          .update({
            'last_topup_at': DateTime.now().toIso8601String(),
            'next_topup_due': nextDue.toIso8601String(),
            'validity_expires_at': validityExpires.toIso8601String(),
            'health_score': 100,
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', failedExec.simLineId);

      // 10. Log Success Activity
      await _client.from('line_activity_log').insert({
        'sim_line_id': failedExec.simLineId,
        'user_id': userId,
        'event_type': 'topup_success',
        'description': 'Retry successful: Auto-refill resolved.',
        'metadata': {
          'amount': failedExec.amount,
          'reloadly_transaction_id': mockTxId,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteExecution(String executionId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const Failure(
          AppFailure.auth(message: 'No authenticated user.'),
        );
      }

      await _client
          .from('topup_executions')
          .delete()
          .eq('id', executionId)
          .eq('user_id', userId);

      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(AppFailure.server(message: e.message));
    } catch (e) {
      return Failure(AppFailure.unknown(message: e.toString()));
    }
  }
}
