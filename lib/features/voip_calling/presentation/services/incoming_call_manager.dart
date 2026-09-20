/// KeepSIMs — Global Incoming VoIP Call Manager
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/services/device_identity_service.dart';
import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

final incomingCallManagerProvider = Provider<IncomingCallManager>((ref) {
  final manager = IncomingCallManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});

class IncomingCallManager {
  final Ref _ref;
  final VoipCallkitService _callkit = VoipCallkitService();
  StreamSubscription<RemoteMessage>? _fcmSub;
  GoRouter? _router;

  IncomingCallManager(this._ref);

  void setRouter(GoRouter router) {
    _router = router;
  }

  /// Initialize callkit listeners, FCM handlers, and token registration
  Future<void> initialize() async {
    _callkit.startListening();

    _callkit.onCallAccepted = (callId) async {
      debugPrint('[IncomingCallManager] User accepted CallKit call: $callId');
      if (callId.startsWith('mock-call-')) {
        await _ref
            .read(voipCallingControllerProvider.notifier)
            .startDebugCall(
              peerName: 'Sarah Connor',
              peerPhone: '+1 555-0199',
            );
        _router?.push('/voip-call');
        return;
      }

      final repo = _ref.read(voipCallingRepositoryProvider);
      final session = await repo.getCallSession(callId);

      if (session != null) {
        await _ref
            .read(voipCallingControllerProvider.notifier)
            .answerCall(
              callId: callId,
              callerName: session.peerName ?? 'KeepSIMs Caller',
              callerAvatar: session.peerAvatarUrl,
              callerPhone: session.peerPhone,
            );

        _router?.push('/voip-call');
      }
    };

    _callkit.onCallDeclined = (callId) async {
      debugPrint('[IncomingCallManager] User declined CallKit call: $callId');
      if (callId.startsWith('mock-call-')) return;
      await _ref
          .read(voipCallingRepositoryProvider)
          .endCall(
            callId: callId,
            status: 'declined',
            endReason: 'user_declined',
          );
    };

    _callkit.onCallTimeout = (callId) async {
      debugPrint('[IncomingCallManager] CallKit call timed out: $callId');
      if (callId.startsWith('mock-call-')) return;
      await _ref
          .read(voipCallingRepositoryProvider)
          .endCall(callId: callId, status: 'missed', endReason: 'timeout');
    };

    // Listen to foreground FCM data messages for incoming calls
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'INCOMING_VOIP_CALL') {
        _handleIncomingPush(data);
      }
    });

    // Register VoIP tokens
    await registerDeviceTokens();
  }

  /// Register push tokens with backend
  Future<void> registerDeviceTokens() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final identityService = DeviceIdentityService(supabase: supabase);
      final deviceId = await identityService.deviceId();
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      String? voipToken;
      String? fcmToken;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        voipToken = await _callkit.getDevicePushTokenVoIP();
      }

      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      await _ref
          .read(voipCallingRepositoryProvider)
          .registerVoipTokens(
            deviceId: deviceId,
            platform: platform,
            voipToken: voipToken,
            fcmToken: fcmToken,
          );
    } catch (e) {
      debugPrint('[IncomingCallManager] Token register error: $e');
    }
  }

  void _handleIncomingPush(Map<String, dynamic> data) {
    final callId = data['call_id'] as String?;
    final callerName = data['caller_name'] as String? ?? 'KeepSIMs Caller';
    final callerAvatar = data['caller_avatar'] as String?;
    final callerPhone = data['caller_phone'] as String?;

    if (callId != null) {
      _callkit.showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callerPhone: callerPhone,
      );
    }
  }

  void dispose() {
    _fcmSub?.cancel();
    _callkit.dispose();
  }
}
