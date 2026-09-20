/// KeepSIMs — Global Incoming VoIP Call Manager
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/router/app_router.dart';
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
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _realtimeChannel;
  GoRouter? _router;

  IncomingCallManager(this._ref);

  void setRouter(RouterConfig<Object> router) {
    if (router is GoRouter) {
      _router = router;
    }
  }

  void _navigateToCall() {
    if (_router != null) {
      _router!.push('/voip-call');
      return;
    }
    final router = _ref.read(appRouterProvider);
    if (router is GoRouter) {
      router.push('/voip-call');
    }
  }

  /// Initialize callkit listeners, FCM handlers, Realtime listeners, and token registration
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
        _navigateToCall();
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

        _navigateToCall();
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

    // 1. Foreground FCM push listener
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['type'] == 'INCOMING_VOIP_CALL') {
        _handleIncomingPush(data);
      }
    });

    // 2. OneSignal foreground push listener
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] == 'INCOMING_VOIP_CALL') {
        event.preventDefault();
        _handleIncomingPush(Map<String, dynamic>.from(data));
      }
    });

    // 3. OneSignal notification tap listener
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] == 'INCOMING_VOIP_CALL') {
        _handleIncomingPush(Map<String, dynamic>.from(data));
      }
    });

    // 4. Realtime Postgres listener on voip_call_sessions
    _setupRealtimeIncomingCallListener();

    _authSub?.cancel();
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _setupRealtimeIncomingCallListener();
        registerDeviceTokens();
      }
    });

    // Register VoIP tokens with backend
    await registerDeviceTokens();
  }

  void _setupRealtimeIncomingCallListener() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('user_incoming_calls_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'voip_call_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: uid,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            if (record.isEmpty) return;

            final status = record['status'] as String?;
            final callId = record['id'] as String?;
            if (callId == null) return;

            if (status == 'initiating') {
              final callerId = record['caller_id'] as String?;
              String callerName = 'KeepSIMs Caller';
              String? callerAvatar;
              String? callerPhone;

              if (callerId != null) {
                try {
                  final profileRes = await supabase
                      .from('profiles')
                      .select('full_name, avatar_url, phone')
                      .eq('id', callerId)
                      .maybeSingle();
                  if (profileRes != null) {
                    callerName =
                        profileRes['full_name'] as String? ?? 'KeepSIMs Caller';
                    callerAvatar = profileRes['avatar_url'] as String?;
                    callerPhone = profileRes['phone'] as String?;
                  }
                } catch (_) {}
              }

              _callkit.showIncomingCall(
                callId: callId,
                callerName: callerName,
                callerAvatar: callerAvatar,
                callerPhone: callerPhone,
              );
            } else if (status == 'ended' ||
                status == 'completed' ||
                status == 'declined' ||
                status == 'timeout') {
              await _callkit.endCall(callId);
            }
          },
        )
        .subscribe();
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
    _authSub?.cancel();
    _realtimeChannel?.unsubscribe();
    _callkit.dispose();
  }
}
