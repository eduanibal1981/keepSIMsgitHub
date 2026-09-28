/// KeepSIMs — Calling Repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/models/available_virtual_number_model.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/models/carrier_divert_model.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/data/models/voicemail_model.dart';

final callingRepositoryProvider = Provider<CallingRepository>((ref) {
  return CallingRepository(supabase);
});

class CallerIdRequestResult {
  final bool isAlreadyVerified;
  final String message;
  final String phoneNumber;

  const CallerIdRequestResult({
    required this.isAlreadyVerified,
    required this.message,
    required this.phoneNumber,
  });
}

class CallerIdListResult {
  final List<CallerIdModel> callerIds;
  final String defaultGatewayNumber;
  final bool isGatewayActive;
  final String activeCallerId;

  const CallerIdListResult({
    required this.callerIds,
    required this.defaultGatewayNumber,
    this.isGatewayActive = true,
    this.activeCallerId = '+17543180369',
  });
}

class CallPreviewResult {
  final bool eligible;
  final String policyCode;
  final String policyReason;
  final String? suggestedAction;
  final String requestedCallerId;
  final String effectiveCallerId;
  final String callerIdType;
  final CallRate? rate;
  final double walletBalance;
  final double availableBalance;
  final String gatewayNumber;
  final double connectionFee;
  final int billingIncrementSeconds;

  const CallPreviewResult({
    required this.eligible,
    required this.policyCode,
    required this.policyReason,
    this.suggestedAction,
    required this.requestedCallerId,
    required this.effectiveCallerId,
    required this.callerIdType,
    this.rate,
    required this.walletBalance,
    double? availableBalance,
    required this.gatewayNumber,
    this.connectionFee = 0.0,
    this.billingIncrementSeconds = 1,
  }) : availableBalance = availableBalance ?? walletBalance;
}

class CallingRepository {
  final SupabaseClient _supabase;

  CallingRepository(this._supabase);

  /// Fetch all active destination call rates with account tier pricing (Halo Effect)
  Future<List<CallRate>> getActiveCallRates() async {
    try {
      final res = await _supabase.rpc('get_user_calling_rates');
      if (res is List && res.isNotEmpty) {
        return res
            .map((e) => CallRate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback to call_rates table if RPC fails
    }

    final res = await _supabase
        .from('call_rates')
        .select('*')
        .eq('is_active', true)
        .order('country_name');

    return (res as List).map((e) => CallRate.fromJson(e)).toList();
  }

  /// Single-record fetch for active call status polling
  Future<CallRecord?> getCallRecord(String callId) async {
    final res = await _supabase
        .from('call_records')
        .select('*')
        .eq('id', callId)
        .maybeSingle();

    return res != null ? CallRecord.fromJson(res) : null;
  }

  /// Pre-call policy evaluation without placing a call
  Future<CallPreviewResult> previewCall({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway = false,
    String? simLineId,
  }) async {
    final response = await _supabase.functions.invoke(
      'make-call',
      body: {
        'action': 'preview',
        'destinationNumber': destinationNumber,
        'callerIdId': callerIdId,
        'explicitGateway': explicitGateway,
        'simLineId': simLineId,
      },
    );

    final data = response.data;
    if (response.status != 200 || data == null || data['success'] != true) {
      final msg =
          data?['errorMessage'] ??
          'Failed to check call policy (status ${response.status})';
      throw Exception(msg);
    }

    final destData = data['destination'] as Map<String, dynamic>?;
    CallRate? rate;
    if (destData != null && destData['ratePerMinute'] != null) {
      rate = CallRate(
        id: destData['rateId'] as String? ?? 'preview',
        countryCode: destData['countryCode'] as String? ?? 'GLOBAL',
        countryName: destData['countryName'] as String? ?? 'International Destination',
        phonePrefix: '+',
        costPerMinute: 0.0,
        ratePerMinute: (destData['ratePerMinute'] as num).toDouble(),
        connectionFee: (destData['connectionFee'] as num?)?.toDouble() ?? 0.0,
        billingIncrementSeconds: destData['billingIncrementSeconds'] as int? ?? 1,
        accountTier: destData['accountTier'] as String?,
      );
    }

    final double postedBal = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final double availBal =
        (data['availableBalance'] as num?)?.toDouble() ?? postedBal;

    return CallPreviewResult(
      eligible: data['eligible'] == true,
      policyCode: data['policyCode'] as String? ?? 'approved',
      policyReason: data['policyReason'] as String? ?? '',
      suggestedAction: data['suggestedAction'] as String?,
      requestedCallerId: data['requestedCallerId'] as String? ?? '',
      effectiveCallerId: data['effectiveCallerId'] as String? ?? '',
      callerIdType: data['callerIdType'] as String? ?? 'gateway',
      rate: rate,
      walletBalance: postedBal,
      availableBalance: availBal,
      gatewayNumber: data['gatewayNumber'] as String? ?? '+17543180369',
      connectionFee: (destData?['connectionFee'] as num?)?.toDouble() ?? 0.0,
      billingIncrementSeconds: destData?['billingIncrementSeconds'] as int? ?? 1,
    );
  }

  /// Initiate an international call via make-call edge function
  Future<Map<String, dynamic>> prepareCallAudio() async {
    final response = await _supabase.functions.invoke(
      'make-call',
      body: {'action': 'prepare_media'},
    );
    if (response.data?['success'] != true) {
      throw Exception(
        response.data?['errorMessage'] ?? 'Call audio is unavailable.',
      );
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> confirmCallAudio(String callId) async {
    final response = await _supabase.functions.invoke(
      'make-call',
      body: {'action': 'media_ready', 'callId': callId},
    );
    if (response.data?['success'] != true) {
      throw Exception('Unable to connect call audio.');
    }
  }

  Future<Map<String, dynamic>> initiateCall({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway = false,
    String? userCallbackNumber,
    String? simLineId,
    String? idempotencyKey,
    String? mediaSessionId,
  }) async {
    final response = await _supabase.functions.invoke(
      'make-call',
      body: {
        'action': 'dial',
        'destinationNumber': destinationNumber,
        'callerIdId': callerIdId,
        'explicitGateway': explicitGateway,
        'userCallbackNumber': ?userCallbackNumber,
        'simLineId': simLineId,
        'idempotencyKey': idempotencyKey,
        'mediaSessionId': mediaSessionId,
      },
    );

    final data = response.data;
    if (response.status != 200 || data == null || data['success'] != true) {
      final msg =
          data?['errorMessage'] ??
          'Failed to initiate call (status ${response.status})';
      throw Exception(msg);
    }

    return Map<String, dynamic>.from(data);
  }

  /// Hangup / terminate active call
  Future<void> endCall(String callId) async {
    await _supabase.functions.invoke(
      'make-call',
      body: {'action': 'hangup', 'callId': callId},
    );
  }

  /// Watch active call record status in real-time
  Stream<CallRecord?> watchActiveCall(String callId) {
    return _supabase
        .from('call_records')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map(
          (list) => list.isNotEmpty ? CallRecord.fromJson(list.first) : null,
        );
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
    final res = await getCallerIdList();
    return res.callerIds;
  }

  /// List user's verified Caller IDs and active preference
  Future<CallerIdListResult> getCallerIdList() async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {'action': 'list'},
    );
    if (res.status != 200 || res.data == null) {
      return const CallerIdListResult(
        callerIds: [],
        defaultGatewayNumber: '+17543180369',
      );
    }
    final list = res.data['callerIds'] as List? ?? [];
    final gateway =
        res.data['defaultGatewayNumber'] as String? ?? '+17543180369';
    final isGatewayActive = res.data['isGatewayActive'] as bool? ?? true;
    final activeCallerId = res.data['activeCallerId'] as String? ?? gateway;

    return CallerIdListResult(
      callerIds: list.map((e) => CallerIdModel.fromJson(e)).toList(),
      defaultGatewayNumber: gateway,
      isGatewayActive: isGatewayActive,
      activeCallerId: activeCallerId,
    );
  }

  /// Request SMS or Voice Call OTP to verify user's phone number
  Future<CallerIdRequestResult> requestCallerIdVerification(
    String phoneNumber, {
    String method = 'sms',
  }) async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'request_verification',
        'phoneNumber': phoneNumber,
        'method': method,
      },
    );
    final data = res.data;
    if (res.status != 200 || data == null || data['success'] != true) {
      throw Exception(
        data?['errorMessage'] ?? 'Failed to send verification code',
      );
    }
    return CallerIdRequestResult(
      isAlreadyVerified: data['isAlreadyVerified'] as bool? ?? false,
      message: data['message'] as String? ?? 'Code sent',
      phoneNumber: data['phoneNumber'] as String? ?? phoneNumber,
    );
  }

  /// Submit OTP to verify and activate Caller ID
  Future<String> verifyCallerIdCode(String phoneNumber, String code) async {
    final res = await _supabase.functions.invoke(
      'manage-caller-id',
      body: {'action': 'verify_code', 'phoneNumber': phoneNumber, 'code': code},
    );
    final data = res.data;
    if (res.status != 200 || data == null || data['success'] != true) {
      throw Exception(data?['errorMessage'] ?? 'Invalid or expired code');
    }
    return data['message'] as String? ?? 'Verified successfully!';
  }

  /// Switch default caller ID (to a verified number or 'gateway')
  Future<void> setDefaultCallerId({
    String? callerIdId,
    String? phoneNumber,
  }) async {
    await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'set_default',
        'callerIdId': ?callerIdId,
        'phoneNumber': ?phoneNumber,
      },
    );
  }

  /// Delete a verified caller ID
  Future<void> deleteCallerId({String? callerIdId, String? phoneNumber}) async {
    await _supabase.functions.invoke(
      'manage-caller-id',
      body: {
        'action': 'delete',
        'callerIdId': ?callerIdId,
        'phoneNumber': ?phoneNumber,
      },
    );
  }

  /// Fetch user's active virtual DID numbers
  Future<List<VirtualDidNumber>> getVirtualDids() async {
    try {
      final res = await _supabase.rpc('get_user_dids');
      if (res is List) {
        return res
            .map((e) => VirtualDidNumber.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    // Fallback via Edge Function or direct table
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return [];
      final rows = await _supabase
          .from('virtual_did_numbers')
          .select()
          .eq('user_id', uid)
          .eq('status', 'active')
          .order('created_at', ascending: true);
      return (rows as List)
          .map((e) => VirtualDidNumber.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Update call forwarding mode on a virtual DID number
  Future<void> updateDidForwarding({
    required String didId,
    required String forwardMode,
    String? forwardDestination,
  }) async {
    try {
      await _supabase.rpc('update_did_forwarding', params: {
        'p_did_id': didId,
        'p_forward_mode': forwardMode,
        'p_forward_destination': forwardDestination,
      });
    } catch (_) {
      await _supabase.functions.invoke('manage-dids', body: {
        'action': 'update_forwarding',
        'did_id': didId,
        'forward_mode': forwardMode,
        'forward_destination': forwardDestination,
      });
    }
  }

  /// Retrieve GSM call forwarding MMI codes for setting up home SIM forwarding
  Future<Map<String, dynamic>> getForwardingCodes(String didId) async {
    final res = await _supabase.functions.invoke('manage-dids', body: {
      'action': 'get_forwarding_codes',
      'did_id': didId,
    });
    if (res.data != null && res.data['instructions'] != null) {
      return Map<String, dynamic>.from(res.data['instructions'] as Map);
    }
    return {};
  }

  /// Fetch user's visual voicemail messages
  Future<List<VoicemailMessage>> getVoicemails({int limit = 50}) async {
    try {
      final res = await _supabase.rpc('get_user_voicemails', params: {'p_limit': limit});
      if (res is List) {
        return res
            .map((e) => VoicemailMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    // Fallback direct query
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return [];
      final rows = await _supabase
          .from('voicemail_messages')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((e) => VoicemailMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark a voicemail message as read
  Future<void> markVoicemailRead(String voicemailId) async {
    try {
      await _supabase.rpc('mark_voicemail_read', params: {'p_voicemail_id': voicemailId});
    } catch (_) {
      await _supabase
          .from('voicemail_messages')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', voicemailId);
    }
  }

  /// Search available virtual numbers from Telnyx with intelcallfee breakdown
  Future<List<AvailableVirtualNumber>> searchAvailableNumbers({
    required String countryCode,
    int limit = 15,
    String? areaCode,
  }) async {
    final response = await _supabase.functions.invoke(
      'manage-dids',
      body: {
        'action': 'search_available_numbers',
        'country_code': countryCode,
        'limit': limit,
        if (areaCode != null && areaCode.isNotEmpty) 'area_code': areaCode,
      },
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      final msg = data?['error'] ?? 'Failed to search available numbers';
      throw Exception(msg);
    }

    final list = data['numbers'] as List? ?? [];
    return list
        .map((e) => AvailableVirtualNumber.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Purchase and instantly provision a virtual DID number
  Future<VirtualDidNumber> purchaseVirtualNumber({
    required String phoneNumber,
    required String countryCode,
    required String countryName,
  }) async {
    final response = await _supabase.functions.invoke(
      'manage-dids',
      body: {
        'action': 'purchase_number',
        'phone_number': phoneNumber,
        'country_code': countryCode,
        'country_name': countryName,
      },
    );

    final data = response.data;
    if (data == null || data['success'] != true) {
      if (data?['code'] == 'insufficient_funds') {
        throw Exception(
          data['message'] ?? 'Insufficient wallet balance to purchase this number.',
        );
      }
      final msg = data?['error'] ?? 'Failed to complete number purchase';
      throw Exception(msg);
    }

    final didJson = data['did'] as Map<String, dynamic>? ?? {};
    return VirtualDidNumber.fromJson(didJson);
  }

  /// Fetch real carrier supplementary service MMI divert rules for supported countries
  Future<List<CarrierDivertRule>> getCarrierDivertRules() async {
    try {
      final res = await _supabase.rpc('get_supported_carriers_divert');
      if (res is List) {
        return res
            .map((e) => CarrierDivertRule.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    // Fallback direct query
    try {
      final rows = await _supabase
          .from('carrier_call_forwarding_rules')
          .select('*, carriers!inner(name), countries!inner(name, iso_code, flag_emoji, dialing_code)');
      return (rows as List).map((r) {
        final carrierName = r['carriers']?['name'] as String? ?? 'Carrier';
        final countryName = r['countries']?['name'] as String? ?? '';
        final flag = r['countries']?['flag_emoji'] as String?;
        final dial = r['countries']?['dialing_code'] as String?;
        final map = Map<String, dynamic>.from(r);
        map['carrier_name'] = carrierName;
        map['country_name'] = countryName;
        map['flag_emoji'] = flag;
        map['dialing_code'] = dial;
        return CarrierDivertRule.fromJson(map);
      }).toList();
    } catch (_) {}

    return [];
  }
}
