/// KeepSIMs — VoIP Calling Repository
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';

final voipCallingRepositoryProvider = Provider<VoipCallingRepository>((ref) {
  return VoipCallingRepository(supabase);
});

class ContactLookupResult {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String phone;
  final bool isOnline;

  final bool isSelf;

  const ContactLookupResult({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.phone,
    required this.isOnline,
    this.isSelf = false,
  });

  factory ContactLookupResult.fromJson(Map<String, dynamic> json) {
    return ContactLookupResult(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'KeepSIMs User',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      isSelf: json['is_self'] as bool? ?? false,
    );
  }
}

class InitiateVoipCallResult {
  final bool ok;
  final String callId;
  final String status;
  final List<IceServerModel> iceServers;
  final ContactLookupResult callee;
  final String? message;

  const InitiateVoipCallResult({
    required this.ok,
    required this.callId,
    required this.status,
    required this.iceServers,
    required this.callee,
    this.message,
  });
}

class VoipCallingRepository {
  final SupabaseClient _supabase;

  VoipCallingRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Register device VoIP PushKit & FCM tokens with user account
  Future<void> registerVoipTokens({
    required String deviceId,
    required String platform,
    String? voipToken,
    String? fcmToken,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _supabase.from('voip_push_tokens').upsert({
      'user_id': uid,
      'device_id': deviceId,
      'platform': platform,
      'voip_token': voipToken,
      'fcm_token': fcmToken,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,device_id');
  }

  /// Check if a phone number belongs to a registered KeepSIMs user eligible for free VoIP calls.
  /// Returns null if not found, or throws if a network/service error occurs.
  Future<ContactLookupResult?> lookupContactByPhone(String phone) async {
    final res = await _supabase.rpc(
      'lookup_voip_contact_by_phone',
      params: {'p_phone': phone},
    );

    if (res is List && res.isNotEmpty) {
      return ContactLookupResult.fromJson(
        Map<String, dynamic>.from(res.first as Map),
      );
    }
    return null;
  }

  /// Initiate a VoIP call via Supabase Edge Function
  Future<InitiateVoipCallResult> initiateCall({
    required String calleeId,
    String? offerSdp,
    String? callerDeviceId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'initiate-voip-call',
        body: {
          'callee_id': calleeId,
          'offer_sdp': offerSdp,
          'caller_device_id': callerDeviceId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'busy') {
        return InitiateVoipCallResult(
          ok: false,
          callId: '',
          status: 'busy',
          iceServers: const [],
          callee: ContactLookupResult(
            userId: calleeId,
            fullName: '',
            phone: '',
            isOnline: false,
          ),
          message:
              data['message'] as String? ??
              'User is currently on another call.',
        );
      }

      final iceServersRaw = data['ice_servers'] as List? ?? [];
      final iceServers = iceServersRaw
          .map(
            (e) => IceServerModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      final calleeData = data['callee'] as Map<String, dynamic>? ?? {};

      return InitiateVoipCallResult(
        ok: true,
        callId: data['call_id'] as String,
        status: data['status'] as String? ?? 'initiating',
        iceServers: iceServers,
        callee: ContactLookupResult(
          userId: calleeData['id'] as String? ?? calleeId,
          fullName: calleeData['name'] as String? ?? 'KeepSIMs User',
          avatarUrl: calleeData['avatar'] as String?,
          phone: calleeData['phone'] as String? ?? '',
          isOnline: true,
        ),
      );
    } catch (e) {
      throw Exception('Failed to initiate internet call: $e');
    }
  }

  /// Persist caller's SDP offer to session
  Future<void> saveOffer({
    required String callId,
    required String offerSdp,
  }) async {
    try {
      await _supabase.rpc('save_voip_offer', params: {
        'p_call_id': callId,
        'p_offer_sdp': offerSdp,
      });
    } catch (_) {
      try {
        await _supabase
            .from('voip_call_sessions')
            .update({
              'offer_sdp': offerSdp,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', callId);
      } catch (_) {}
    }
  }

  /// Update call session when callee accepts
  Future<void> answerCall({
    required String callId,
    required String answerSdp,
    String? calleeDeviceId,
  }) async {
    try {
      await _supabase.rpc('answer_voip_session', params: {
        'p_call_id': callId,
        'p_answer_sdp': answerSdp,
        'p_device_id': calleeDeviceId,
      });
    } catch (_) {
      await _supabase
          .from('voip_call_sessions')
          .update({
            'status': 'accepted',
            'answer_sdp': answerSdp,
            'connected_at': DateTime.now().toIso8601String(),
            'callee_device_id': calleeDeviceId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);
    }
  }

  /// End or decline call
  Future<void> endCall({
    required String callId,
    String status = 'completed',
    String endReason = 'normal_hangup',
  }) async {
    try {
      await _supabase.functions.invoke(
        'end-voip-call',
        body: {'call_id': callId, 'status': status, 'end_reason': endReason},
      );
    } catch (_) {
      try {
        await _supabase.rpc('terminate_voip_session', params: {
          'p_call_id': callId,
          'p_status': status,
          'p_end_reason': endReason,
        });
      } catch (_) {
        await _supabase
            .from('voip_call_sessions')
            .update({
              'status': status,
              'end_reason': endReason,
              'ended_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', callId);
      }
    }
  }

  /// Single record fetch
  Future<VoipCallSession?> getCallSession(String callId) async {
    final res = await _supabase
        .from('voip_call_sessions')
        .select()
        .eq('id', callId)
        .maybeSingle();

    if (res == null) return null;
    return VoipCallSession.fromJson(res, currentUserId: currentUserId);
  }

  /// Realtime stream of single call session
  Stream<VoipCallSession?> watchCallSession(String callId) {
    return _supabase
        .from('voip_call_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return VoipCallSession.fromJson(
            rows.first,
            currentUserId: currentUserId,
          );
        });
  }

  /// Fetch call history for user
  Future<List<VoipCallSession>> getCallHistory({int limit = 50}) async {
    try {
      final res = await _supabase.rpc(
        'get_voip_call_history',
        params: {'p_limit': limit},
      );

      if (res is List) {
        return res
            .map(
              (e) => VoipCallSession.fromJson(
                Map<String, dynamic>.from(e as Map),
                currentUserId: currentUserId,
              ),
            )
            .toList();
      }
    } catch (_) {}

    // Fallback direct query
    final uid = currentUserId;
    if (uid == null) return [];
    final res = await _supabase
        .from('voip_call_sessions')
        .select()
        .or('caller_id.eq.$uid,callee_id.eq.$uid')
        .order('started_at', ascending: false)
        .limit(limit);

    return (res as List)
        .map((e) => VoipCallSession.fromJson(e, currentUserId: uid))
        .toList();
  }
}
