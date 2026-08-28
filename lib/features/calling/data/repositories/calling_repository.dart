/// KeepSIMs — Calling Repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';

final callingRepositoryProvider = Provider<CallingRepository>((ref) {
  return CallingRepository(supabase);
});

class CallingRepository {
  final SupabaseClient _supabase;

  CallingRepository(this._supabase);

  /// Fetch all active call rates
  Future<List<CallRate>> getActiveCallRates() async {
    final res = await _supabase
        .from('call_rates')
        .select()
        .eq('is_active', true)
        .order('country_name', ascending: true);

    final list = res as List<dynamic>;
    return list.map((e) => CallRate.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Resolve rate for a specific phone number
  Future<CallRate?> getRateForNumber(String phoneNumber) async {
    try {
      final res = await _supabase.rpc(
        'get_call_rate_for_number',
        params: {'p_phone_number': phoneNumber},
      );
      if (res is List && res.isNotEmpty) {
        return CallRate.fromJson(res.first as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch user's call history
  Future<List<CallRecord>> getUserCallHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await _supabase
        .from('call_records')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    final list = res as List<dynamic>;
    return list.map((e) => CallRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Stream of user's active/recent calls
  Stream<List<CallRecord>> watchUserCallHistory() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('call_records')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30)
        .map((rows) => rows.map((e) => CallRecord.fromJson(e)).toList());
  }

  /// Initiate a call via make-call Supabase Edge Function
  Future<Map<String, dynamic>> initiateCall({
    required String destinationNumber,
    required String userCallbackNumber,
    String? simLineId,
  }) async {
    final response = await _supabase.functions.invoke(
      'make-call',
      body: {
        'destinationNumber': destinationNumber,
        'userCallbackNumber': userCallbackNumber,
        'simLineId': simLineId,
      },
    );

    if (response.status != 200) {
      final err = response.data?['errorMessage'] ?? 'Failed to initiate call (${response.status})';
      throw Exception(err);
    }

    return response.data as Map<String, dynamic>;
  }
}
