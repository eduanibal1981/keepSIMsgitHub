import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/offline_recharge/model/recovery_state_model.dart';
import 'package:keep_sims/features/offline_recharge/service/recovery_reachability_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final recoveryRepositoryProvider = Provider<RecoveryRepository>((ref) {
  return RecoveryRepository(ref: ref);
});

class RecoveryResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const RecoveryResult.success(this.data)
      : isSuccess = true,
        error = null;

  const RecoveryResult.failure(this.error)
      : isSuccess = false,
        data = null;
}

class RecoveryRepository {
  final Ref _ref;
  final SupabaseClient _supabase;

  RecoveryRepository({required Ref ref, SupabaseClient? supabase})
      : _ref = ref,
        _supabase = supabase ?? Supabase.instance.client;

  /// Syncs latest recovery profile and entitlement status from the backend.
  Future<RecoveryResult<Map<String, dynamic>>> syncLatestStatus() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return const RecoveryResult.failure('No active authenticated session');
      }

      final response = await _supabase.functions.invoke(
        'recovery-service',
        body: {'action': 'status'},
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : (response.data is String
                ? jsonDecode(response.data as String) as Map<String, dynamic>
                : <String, dynamic>{});

        final profile = data['profile'] as Map<String, dynamic>?;
        final entitlementStr = data['entitlement'] as String?;
        final allowance = data['allowance'] as Map<String, dynamic>?;

        final entitlement = RecoveryEntitlement.values.firstWhere(
          (e) => e.name == entitlementStr,
          orElse: () => RecoveryEntitlement.none,
        );

        _ref.read(recoveryReachabilityServiceProvider.notifier).updateFromRemote(
              profileReference: profile?['profile_reference'] as String?,
              esimReference: profile?['esim_reference'] as String?,
              iccid: profile?['iccid'] as String?,
              activationCode: profile?['activation_code'] as String?,
              smdpAddress: profile?['smdp_address'] as String?,
              matchingId: profile?['matching_id'] as String?,
              entitlement: entitlement,
              remainingMb: (allowance?['remaining_mb'] as num?)?.toInt() ?? 0,
              totalMb: (allowance?['total_mb'] as num?)?.toInt() ?? 0,
              isMock: data['mode'] != 'live',
            );

        return RecoveryResult.success(data);
      } else {
        return RecoveryResult.failure(
            'Server returned status ${response.status}');
      }
    } catch (e) {
      debugPrint('syncLatestStatus error: $e');
      return RecoveryResult.failure(e.toString());
    }
  }

  /// Requests the backend to provision a backup recovery profile in sandbox mode.
  Future<RecoveryResult<Map<String, dynamic>>> prepareRecoveryProfile() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return const RecoveryResult.failure('Please sign in to prepare a backup profile');
      }

      final response = await _supabase.functions.invoke(
        'recovery-service',
        body: {
          'action': 'prepare_profile',
          'idempotency_key':
              'prep_${session.user.id}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : (response.data is String
                ? jsonDecode(response.data as String) as Map<String, dynamic>
                : <String, dynamic>{});

        final profile = data['profile'] as Map<String, dynamic>?;

        _ref.read(recoveryReachabilityServiceProvider.notifier).updateFromRemote(
              profileReference: profile?['profile_reference'] as String?,
              esimReference: profile?['esim_reference'] as String?,
              iccid: profile?['iccid'] as String?,
              activationCode: profile?['activation_code'] as String?,
              smdpAddress: profile?['smdp_address'] as String?,
              matchingId: profile?['matching_id'] as String?,
              provisioningState: RecoveryProvisioningState.pendingInstallation,
              isMock: data['mode'] != 'live',
            );

        return RecoveryResult.success(data);
      } else {
        return RecoveryResult.failure(
            'Failed to prepare profile: ${response.data}');
      }
    } catch (e) {
      debugPrint('prepareRecoveryProfile error: $e');
      return RecoveryResult.failure(e.toString());
    }
  }

  /// Requests a sponsored general data allowance package in sandbox mode.
  Future<RecoveryResult<Map<String, dynamic>>> requestRecoveryAllowance() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        return const RecoveryResult.failure('Authentication required');
      }

      final response = await _supabase.functions.invoke(
        'recovery-service',
        body: {
          'action': 'request_allowance',
          'idempotency_key':
              'allowance_${session.user.id}_${DateTime.now().millisecondsSinceEpoch ~/ 300000}',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : (response.data is String
                ? jsonDecode(response.data as String) as Map<String, dynamic>
                : <String, dynamic>{});

        final allowance = data['allowance'] as Map<String, dynamic>?;

        _ref.read(recoveryReachabilityServiceProvider.notifier).updateFromRemote(
              entitlement: RecoveryEntitlement.generalDataAllowance,
              remainingMb: (allowance?['remaining_mb'] as num?)?.toInt() ?? 1024,
              totalMb: (allowance?['total_mb'] as num?)?.toInt() ?? 1024,
              isMock: data['mode'] != 'live',
            );

        return RecoveryResult.success(data);
      } else {
        return RecoveryResult.failure(
            'Failed to request allowance: ${response.data}');
      }
    } catch (e) {
      debugPrint('requestRecoveryAllowance error: $e');
      return RecoveryResult.failure(e.toString());
    }
  }
}
