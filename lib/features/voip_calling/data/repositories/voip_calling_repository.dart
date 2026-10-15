/// KeepSIMs — VoIP Calling Repository
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_recipient.dart';
export 'package:keep_sims/features/voip_calling/domain/free_call_recipient.dart';

final voipCallingRepositoryProvider = Provider<VoipCallingRepository>((ref) {
  return VoipCallingRepository(supabase);
});

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

  String? get currentUserId {
    try {
      return _supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserPhone {
    try {
      return _supabase.auth.currentUser?.phone;
    } catch (_) {
      return null;
    }
  }

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
    return (await resolveFreeCallRecipient(phone: phone)).recipient;
  }

  Future<FreeRecipientResolution> resolveFreeCallRecipient({
    String? phone,
    String? userId,
  }) async {
    if ((phone == null) == (userId == null) ||
        (phone != null && !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone))) {
      throw const FormatException('Confirm a full international number first');
    }
    final res = await _supabase.rpc(
      'resolve_free_call_recipient',
      params: {'p_phone': ?phone, 'p_user_id': ?userId},
    );
    // Missing/newer backend contracts must fail safely, never use the old
    // first/suffix-match RPC as a fallback.
    return FreeRecipientResolution.parse(res, phone: phone, userId: userId);
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

      final hasTurn = iceServers.any(
        (s) =>
            s.urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:')),
      );
      final finalIceServers = hasTurn
          ? iceServers
          : (iceServers.isEmpty
                ? defaultIceServers
                : [...iceServers, defaultIceServers.last]);

      final calleeData = data['callee'] as Map<String, dynamic>? ?? {};

      return InitiateVoipCallResult(
        ok: true,
        callId: data['call_id'] as String,
        status: data['status'] as String? ?? 'initiating',
        iceServers: finalIceServers,
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
  Future<Map<String, dynamic>> saveOffer({
    required String callId,
    required String offerSdp,
  }) async {
    try {
      final res = await _supabase.rpc(
        'save_voip_offer',
        params: {'p_call_id': callId, 'p_offer_sdp': offerSdp},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'ok': true, 'status': 'saved'};
    } catch (e) {
      debugPrint('[VoipCallingRepo] saveOffer RPC warning: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Update call session when callee accepts (keeps connected_at null until media connects)
  Future<Map<String, dynamic>> answerCall({
    required String callId,
    required String answerSdp,
    String? calleeDeviceId,
  }) async {
    try {
      final res = await _supabase.rpc(
        'answer_voip_session',
        params: {
          'p_call_id': callId,
          'p_answer_sdp': answerSdp,
          'p_device_id': calleeDeviceId,
        },
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'ok': true, 'status': 'accepted'};
    } catch (e) {
      debugPrint('[VoipCallingRepo] answerCall RPC warning: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Atomically mark call as connected in DB once WebRTC media is established
  Future<Map<String, dynamic>> markConnected(String callId) async {
    try {
      final res = await _supabase.rpc(
        'mark_voip_session_connected',
        params: {'p_call_id': callId},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'ok': true, 'status': 'connected'};
    } catch (e) {
      debugPrint('[VoipCallingRepo] markConnected warning: $e');
      return {'ok': false, 'error': e.toString()};
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
    } catch (e) {
      debugPrint(
        '[VoipCallingRepo] end-voip-call error, falling back to RPC: $e',
      );
      try {
        await _supabase.rpc(
          'terminate_voip_session',
          params: {
            'p_call_id': callId,
            'p_status': status,
            'p_end_reason': endReason,
          },
        );
      } catch (rpcErr) {
        debugPrint(
          '[VoipCallingRepo] terminate_voip_session RPC error: $rpcErr',
        );
      }
    }
  }

  static const List<IceServerModel> defaultIceServers = [
    IceServerModel(
      urls: [
        'stun:34.40.33.208:3478',
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    ),
    IceServerModel(
      urls: [
        'turn:34.40.33.208:3478?transport=udp',
        'turn:34.40.33.208:3478?transport=tcp',
      ],
      username: 'keepsims',
      credential: 'keepsims_turn_secret_2026_prod',
    ),
  ];

  /// Fetch authorized ICE servers (STUN + TURN) for an active call session
  Future<List<IceServerModel>> getCallIceServers(String callId) async {
    try {
      final response = await _supabase.functions.invoke(
        'get-turn-credentials',
        body: {'call_id': callId},
      );
      final data = response.data as Map<String, dynamic>?;
      final rawList = data?['ice_servers'] as List? ?? [];
      if (rawList.isNotEmpty) {
        final parsed = rawList
            .map(
              (e) =>
                  IceServerModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final hasTurn = parsed.any(
          (s) => s.urls.any(
            (u) => u.startsWith('turn:') || u.startsWith('turns:'),
          ),
        );
        if (hasTurn) {
          debugPrint(
            '[VoipCallingRepo] Fetched ${parsed.length} authorized ICE servers from backend',
          );
          return parsed;
        }
      }
    } catch (e) {
      debugPrint(
        '[VoipCallingRepo] get-turn-credentials invocation warning: $e',
      );
    }

    debugPrint(
      '[VoipCallingRepo] Using reliable default ICE servers with Open Relay TURN',
    );
    return defaultIceServers;
  }

  /// Single record fetch with automatic auth recovery and exponential retries
  Future<VoipCallSession?> getCallSession(
    String callId, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final res = await AuthSessionManager.withAuthRecovery(
          _supabase,
          () => _supabase
              .from('voip_call_sessions')
              .select()
              .eq('id', callId)
              .maybeSingle(),
        );

        if (res != null) {
          return VoipCallSession.fromJson(res, currentUserId: currentUserId);
        }
      } catch (e) {
        debugPrint(
          '[VoipCallingRepo] getCallSession error (attempt $attempt): $e',
        );
      }

      if (attempt < maxRetries) {
        // Backoff: 300ms, 600ms, 1200ms
        await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
      }
    }
    return null;
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
