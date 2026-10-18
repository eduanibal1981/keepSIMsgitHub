/// KeepSIMs — Calling Repository

library;

import 'package:keep_sims/core/utils/retail_poll_ticks.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contract/second_number_contract.dart';
import '../models/second_number_models.dart';
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

class CallingRepository implements SecondNumberContract {
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
        .select(
          'id,country_code,country_name,phone_prefix,destination_type,rate_per_minute_usd,connection_fee_usd,billing_increment_seconds,is_active',
        )
        .eq('is_active', true)
        .order('country_name');

    return (res as List).map((e) => CallRate.fromJson(e)).toList();
  }

  /// Single-record fetch for active call status polling
  Future<CallRecord?> getCallRecord(String callId) async {
    final res = await _supabase
        .from('customer_call_records')
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
    if (destData?['number'] != null &&
        destData!['number'] != destinationNumber) {
      throw Exception('The call quote does not match the destination.');
    }
    CallRate? rate;
    if (destData != null && destData['ratePerMinute'] != null) {
      rate = CallRate(
        id: destData['rateId'] as String? ?? 'preview',
        countryCode: destData['countryCode'] as String? ?? 'GLOBAL',
        countryName:
            destData['countryName'] as String? ?? 'International Destination',
        phonePrefix: '+',
        ratePerMinute: (destData['ratePerMinute'] as num).toDouble(),
        connectionFee: (destData['connectionFee'] as num?)?.toDouble() ?? 0.0,
        billingIncrementSeconds:
            destData['billingIncrementSeconds'] as int? ?? 1,
        accountTier: destData['accountTier'] as String?,
      );
    }

    if (rate == null ||
        !rate.ratePerMinute.isFinite ||
        rate.ratePerMinute <= 0 ||
        !rate.connectionFee.isFinite ||
        rate.connectionFee < 0 ||
        rate.billingIncrementSeconds < 1) {
      throw Exception('The call rate is unavailable.');
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
      billingIncrementSeconds:
          destData?['billingIncrementSeconds'] as int? ?? 1,
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
    return retailPollTicks(const Duration(seconds: 2))
        .asyncMap(
          (_) =>
              _supabase.from('customer_call_records').select().eq('id', callId),
        )
        .map(
          (list) => list.isNotEmpty ? CallRecord.fromJson(list.first) : null,
        );
  }

  /// Watch user's call history in real-time
  Stream<List<CallRecord>> watchUserCallHistory() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return retailPollTicks(const Duration(seconds: 3))
        .asyncMap(
          (_) => _supabase
              .from('customer_call_records')
              .select()
              .eq('user_id', userId)
              .order('started_at', ascending: false)
              .limit(50),
        )
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
      throw Exception('Could not load caller IDs.');
    }
    final list = res.data['callerIds'] as List? ?? [];
    final gateway = res.data['defaultGatewayNumber'] as String?;
    if (gateway == null || gateway.isEmpty) {
      throw Exception('Caller ID information is unavailable.');
    }
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

  @override
  Future<List<VirtualDidNumber>> getVirtualDids() async {
    dynamic rows;
    try {
      rows = await _supabase.rpc('get_second_numbers');
    } on PostgrestException catch (error) {
      // Older deployments expose only the owner-scoped calling-number RPC.
      // Authorization, connectivity and database errors must still surface.
      if (error.code != 'PGRST202') rethrow;
      rows = await _supabase.rpc('get_user_dids');
    }
    return (rows as List)
        .map(
          (e) => VirtualDidNumber.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> _secondNumberAction(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'manage-dids',
        body: body,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (response.status != 200 || data['success'] != true) {
        throw SecondNumberFailure(
          data['error'] as String? ??
              'Second Number is temporarily unavailable.',
        );
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details;
      if (body['action'] == 'get_countries' &&
          error.status == 400 &&
          details is Map &&
          details['error'] == "Unknown action 'get_countries'") {
        throw const SecondNumberNotEnabled();
      }
      throw SecondNumberFailure(
        details is Map
            ? details['error']?.toString() ??
                  'Second Number is temporarily unavailable.'
            : 'Second Number is temporarily unavailable.',
      );
    }
  }

  @override
  Future<List<SecondNumberCountry>> getSecondNumberCountries() async {
    final Map<String, dynamic> data;
    try {
      data = await _secondNumberAction({'action': 'get_countries'});
    } on SecondNumberNotEnabled {
      return [];
    }
    final countries = <String, SecondNumberCountry>{};
    for (final row in data['countries'] as List) {
      countries[row['country_code'] as String] = SecondNumberCountry(
        row['country_code'] as String,
        row['country_name'] as String,
      );
    }
    return countries.values.toList();
  }

  @override
  Future<SecondNumberOrder> purchaseSecondNumber({
    required String quoteId,
    required bool autoRenew,
  }) async {
    if ((await getSecondNumberCountries()).isEmpty) {
      throw const SecondNumberNotEnabled();
    }
    final data = await _secondNumberAction({
      'action': 'purchase_number',
      'quote_id': quoteId,
      'auto_renew': autoRenew,
    });
    return SecondNumberOrder.fromJson(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }

  @override
  Future<SecondNumberOrder> getSecondNumberOrder(String id) async {
    final data = await _secondNumberAction({
      'action': 'order_status',
      'order_id': id,
    });
    return SecondNumberOrder.fromJson(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }

  @override
  Stream<List<SecondNumberMessage>> watchDidMessages(String didId) {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      return Stream.error(
        const SecondNumberFailure('Sign in to read your messages.'),
      );
    }
    return _supabase
        .from('virtual_did_messages')
        .stream(primaryKey: ['id'])
        .eq('did_id', didId)
        .order('received_at', ascending: false)
        .limit(100)
        .map(
          (rows) => rows
              .where((r) => r['user_id'] == uid)
              .map((r) => SecondNumberMessage.fromJson(r))
              .toList(),
        );
  }

  @override
  Future<void> markDidMessageRead(String messageId) async {
    await _supabase.rpc(
      'mark_did_message_read',
      params: {'p_message_id': messageId},
    );
  }

  @override
  Future<void> setSecondNumberRenewal(String didId, bool enabled) async {
    await _supabase.rpc(
      'set_second_number_renewal',
      params: {'p_did_id': didId, 'p_auto_renew': enabled},
    );
  }

  @override
  Future<void> releaseSecondNumber(String didId) async {
    await _supabase.rpc(
      'request_second_number_release',
      params: {'p_did_id': didId},
    );
  }

  @override
  Future<List<SecondNumberOrder>> getPendingSecondNumberOrders() async {
    final dynamic rows;
    try {
      rows = await _supabase.rpc('get_pending_second_number_orders');
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      return [];
    }
    return (rows as List)
        .map(
          (r) =>
              SecondNumberOrder.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  /// Update call forwarding mode on a virtual DID number
  Future<void> updateDidForwarding({
    required String didId,
    required String forwardMode,
    String? forwardDestination,
  }) async {
    try {
      await _supabase.rpc(
        'update_did_forwarding',
        params: {
          'p_did_id': didId,
          'p_forward_mode': forwardMode,
          'p_forward_destination': forwardDestination,
        },
      );
    } catch (_) {
      await _supabase.functions.invoke(
        'manage-dids',
        body: {
          'action': 'update_forwarding',
          'did_id': didId,
          'forward_mode': forwardMode,
          'forward_destination': forwardDestination,
        },
      );
    }
  }

  /// Retrieve GSM call forwarding MMI codes for setting up home SIM forwarding
  Future<Map<String, dynamic>> getForwardingCodes(String didId) async {
    final res = await _supabase.functions.invoke(
      'manage-dids',
      body: {'action': 'get_forwarding_codes', 'did_id': didId},
    );
    if (res.data != null && res.data['instructions'] != null) {
      return Map<String, dynamic>.from(res.data['instructions'] as Map);
    }
    return {};
  }

  /// Fetch user's visual voicemail messages
  Future<List<VoicemailMessage>> getVoicemails({int limit = 50}) async {
    try {
      final res = await _supabase.rpc(
        'get_user_voicemails',
        params: {'p_limit': limit},
      );
      if (res is List) {
        return res
            .map(
              (e) => VoicemailMessage.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
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
          .map(
            (e) =>
                VoicemailMessage.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark a voicemail message as read
  Future<void> markVoicemailRead(String voicemailId) async {
    try {
      await _supabase.rpc(
        'mark_voicemail_read',
        params: {'p_voicemail_id': voicemailId},
      );
    } catch (_) {
      await _supabase
          .from('voicemail_messages')
          .update({
            'is_read': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', voicemailId);
    }
  }

  /// Search available virtual numbers from Telnyx with intelcallfee breakdown
  @override
  Future<List<AvailableVirtualNumber>> searchAvailableNumbers({
    required String countryCode,
    int limit = 15,
    String? areaCode,
  }) async {
    final countries = await getSecondNumberCountries();
    if (!countries.any((country) => country.code == countryCode)) {
      throw const SecondNumberNotEnabled();
    }
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
        .map(
          (e) => AvailableVirtualNumber.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Fetch real carrier supplementary service MMI divert rules for supported countries
  Future<List<CarrierDivertRule>> getCarrierDivertRules() async {
    try {
      final res = await _supabase.rpc('get_supported_carriers_divert');
      if (res is List) {
        return res
            .map(
              (e) => CarrierDivertRule.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    } catch (_) {}

    // Fallback direct query
    try {
      final rows = await _supabase
          .from('carrier_call_forwarding_rules')
          .select(
            '*, carriers!inner(name), countries!inner(name, iso_code, flag_emoji, dialing_code)',
          );
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
