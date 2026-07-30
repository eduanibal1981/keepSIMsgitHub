/// SIM Shield — Household spend-limit providers (G6)
///
/// Three RPCs, no table reads. `household_members` is readable by the owner,
/// but the spend numbers are derived from the owner's `wallet_transactions`
/// and from `topup_executions` the member may not see in full — so the summary
/// has to come from a `SECURITY DEFINER` function scoped to `auth.uid()`
/// rather than from a client-side join.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/household/data/models/household_spend_model.dart';

part 'household_spend_provider.g.dart';

/// The owner's consolidated view: every member, cap, and month-to-date spend.
@riverpod
Future<List<HouseholdSpendRow>> householdSpendSummary(Ref ref) async {
  final rows = await Supabase.instance.client.rpc('household_spend_summary');
  final List<dynamic> list = rows is List ? rows : <dynamic>[];
  return list
      .map<HouseholdSpendRow>(
        (r) => HouseholdSpendRow.fromJson(Map<String, dynamic>.from(r as Map)),
      )
      .toList(growable: false);
}

/// The member's side: which households have funded them, and the headroom left.
@riverpod
Future<List<HouseholdAllowance>> myHouseholdAllowances(Ref ref) async {
  final rows = await Supabase.instance.client.rpc('my_household_allowances');
  final List<dynamic> list = rows is List ? rows : <dynamic>[];
  return list
      .map<HouseholdAllowance>(
        (r) => HouseholdAllowance.fromJson(Map<String, dynamic>.from(r as Map)),
      )
      .toList(growable: false);
}

/// Outcome of `set_household_member_cap`. The server returns an envelope rather
/// than raising, so every refusal arrives as a sentence the UI can show.
class CapUpdateResult {
  const CapUpdateResult({required this.success, this.code, this.message});

  final bool success;
  final String? code;
  final String? message;

  factory CapUpdateResult.fromJson(Map<String, dynamic> json) =>
      CapUpdateResult(
        success: json['success'] == true,
        code: json['code'] as String?,
        message: json['error'] as String?,
      );
}

@riverpod
class HouseholdCapController extends _$HouseholdCapController {
  @override
  FutureOr<void> build() {}

  /// Pass 0 for [monthlyCapUsd] to switch a member's spending off. There is no
  /// separate "revoke" call, because the cap is the permission.
  Future<CapUpdateResult> setCap({
    required String memberRowId,
    required double monthlyCapUsd,
    double? perTxnCapUsd,
  }) async {
    state = const AsyncLoading();

    try {
      final res = await Supabase.instance.client.rpc(
        'set_household_member_cap',
        params: {
          'p_member_row_id': memberRowId,
          'p_monthly_cap_usd': monthlyCapUsd,
          'p_per_txn_cap_usd': perTxnCapUsd,
        },
      );

      final result =
          CapUpdateResult.fromJson(Map<String, dynamic>.from(res as Map));

      if (result.success) {
        ref.invalidate(householdSpendSummaryProvider);
        await ref.read(householdSpendSummaryProvider.future);
      }

      state = const AsyncData(null);
      return result;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return CapUpdateResult(
        success: false,
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }
}
