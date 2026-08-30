/// KeepSIMs — Calling Repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';

final callingRepositoryProvider = Provider<CallingRepository>((ref) {
  return CallingRepository(supabase);
});

class CallingRepository {
  final SupabaseClient _supabase;

  CallingRepository(this._supabase);

  /// Fetch all active destination call rates
  Future<List<CallRate>> getActiveCallRates() async {
    final res = await _supabase
        .from('call_rates')
        .select('*')
        .eq('is_active', true)
        .order('country_name');

    return (res as List).map((e) => CallRate.fromJson(e)).toList();
  }

  /// Initiate an international call via make-call edge function
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

    final data = response.data;
    if (response.status != 200 || data == null || data['success'] != true) {
      final msg = data?['errorMessage'] ?? 'Failed to initiate call (status ${response.status})';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(data);
  }

  /// Watch user's call history in real-time
  Stream<List<CallRecord>> watchUserCallHistory() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('call_records')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .limit(50)
        .map((list) => list.map((e) => CallRecord.fromJson(e)).toList());
  }

  /// List user's verified Caller IDs
  Future<List<CallerIdModel>> getUserCallerIds() async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {'action': 'list'},
    );
    if (res.status != 200 || res.data == null) return [];
    final list = res.data['callerIds'] as List? ?? [];
    return list.map((e) => CallerIdModel.fromJson(e)).toList();
  }

  /// Request SMS OTP to verify user's phone number
  Future<String> requestCallerIdVerification(String phoneNumber) async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'request_verification',
        'phoneNumber': phoneNumber,
      },
    );
    final data = res.data;
    if (res.status != 200 || data == null || data['success'] != true) {
      throw Exception(data?['errorMessage'] ?? 'Failed to send SMS code');
    }
    return data['message'] as String? ?? 'Code sent';
  }

  /// Submit OTP to verify and activate Caller ID
  Future<String> verifyCallerIdCode(String phoneNumber, String code) async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'verify_code',
        'phoneNumber': phoneNumber,
        'code': code,
      },
    );
    final data = res.data;
    if (res.status != 200 || data == null || data['success'] != true) {
      throw Exception(data?['errorMessage'] ?? 'Invalid or expired code');
    }
    return data['message'] as String? ?? 'Verified successfully!';
  }

  /// Set default caller ID
  Future<void> setDefaultCallerId(String phoneNumber) async {
    await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'set_default',
        'phoneNumber': phoneNumber,
      },
    );
  }
}
