/// SIM Shield — auto-rescue policy providers (G7)
///
/// Read is a plain RLS-guarded SELECT (`user_id = auth.uid()`). Write is only
/// ever `set_line_rescue_policy()`: the table has no client INSERT or UPDATE
/// policy, so a direct write comes back `42501` — deliberately, because arming
/// an unattended spender is not something a column grant should be able to
/// authorise by accident.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/sim_lines/data/models/line_rescue_policy.dart';

part 'rescue_policy_provider.g.dart';

/// The policy for one line, or null when the owner has never touched it.
@riverpod
Future<LineRescuePolicy?> rescuePolicyForLine(Ref ref, String simLineId) async {
  final row = await Supabase.instance.client
      .from('sim_line_rescue_policy')
      .select()
      .eq('sim_line_id', simLineId)
      .maybeSingle();

  if (row == null) return null;
  return LineRescuePolicy.fromJson(row);
}

/// Outcome of `set_line_rescue_policy`. The server returns an envelope rather
/// than raising, so every refusal arrives as a sentence worth showing.
class RescuePolicyResult {
  const RescuePolicyResult({required this.success, this.code, this.message});

  final bool success;
  final String? code;
  final String? message;

  factory RescuePolicyResult.fromJson(Map<String, dynamic> json) =>
      RescuePolicyResult(
        success: json['success'] == true,
        code: json['code'] as String?,
        message: json['error'] as String?,
      );
}

@riverpod
class RescuePolicyController extends _$RescuePolicyController {
  @override
  FutureOr<void> build() {}

  /// Pass 0 for [maxUsd] to switch SIM insurance off. There is no separate
  /// disable call — the limit is the switch.
  Future<RescuePolicyResult> save({
    required String simLineId,
    required double maxUsd,
    int leadDays = 2,
    int warnLeadDays = 3,
  }) async {
    state = const AsyncLoading();

    try {
      final res = await Supabase.instance.client.rpc(
        'set_line_rescue_policy',
        params: {
          'p_sim_line_id': simLineId,
          'p_max_usd': maxUsd,
          'p_lead_days': leadDays,
          'p_warn_lead_days': warnLeadDays,
        },
      );

      final result =
          RescuePolicyResult.fromJson(Map<String, dynamic>.from(res as Map));

      if (result.success) {
        ref.invalidate(rescuePolicyForLineProvider(simLineId));
        await ref.read(rescuePolicyForLineProvider(simLineId).future);
      }

      state = const AsyncData(null);
      return result;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return RescuePolicyResult(
        success: false,
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }
}
