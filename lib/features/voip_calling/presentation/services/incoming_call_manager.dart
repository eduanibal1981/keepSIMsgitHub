/// KeepSIMs — Global Incoming VoIP Call Manager
library;

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
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
  final Set<String> _presentedCallIds = {};
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _realtimeChannel;
  RouterConfig<Object>? _router;
  bool _isInitialized = false;

  IncomingCallManager(this._ref);

  void setRouter(RouterConfig<Object> router) {
    _router = router;
  }

  void _navigateToCall([String? callId]) {
    final route = callId != null && callId.isNotEmpty
        ? '${AppRoutes.voipCall}/$callId'
        : AppRoutes.voipCall;

    void executeNavigation(dynamic router) {
      if (router is FilteringRouterConfig) {
        final currentPath =
            router.rawRouter.routerDelegate.currentConfiguration.uri.path;
        if (currentPath.startsWith(AppRoutes.voipCall)) return;
        router.push(route);
      } else if (router is GoRouter) {
        final currentPath =
            router.routerDelegate.currentConfiguration.uri.path;
        if (currentPath.startsWith(AppRoutes.voipCall)) return;
        router.push(route);
      }
    }

    if (_router != null) {
      executeNavigation(_router);
      return;
    }
    final globalRouter = _ref.read(appRouterProvider);
    executeNavigation(globalRouter);
  }

  /// Fast-path cold launch when user clicked Accept in the notification while app was terminated
  Future<void> initializeWithAcceptedCall(Map<String, String> callData) async {
    final callId = callData['callId']!;
    final callerName = callData['callerName'] ?? 'KeepSIMs Caller';
    final callerAvatar = callData['callerAvatar'];
    final callerPhone = callData['callerPhone'];

    debugPrint('[IncomingCallManager] Fast launch with accepted call: $callId');
    _ref.read(splashCompletedProvider.notifier).complete();

    // Start background listeners (CallKit, FCM, Realtime)
    unawaited(initialize());

    // Answer call immediately
    await _ref.read(voipCallingControllerProvider.notifier).answerCall(
          callId: callId,
          callerName: callerName,
          callerAvatar: callerAvatar?.isNotEmpty == true ? callerAvatar : null,
          callerPhone: callerPhone?.isNotEmpty == true ? callerPhone : null,
        );

    _navigateToCall(callId);
  }

  /// Initialize callkit listeners, FCM handlers, Realtime listeners, and token registration
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _callkit.startListening();

    _callkit.onCallAccepted = (callId) async {
      debugPrint('[IncomingCallManager] User accepted CallKit call: $callId');
      _presentedCallIds.remove(callId);
      _ref.read(splashCompletedProvider.notifier).complete();

      final currentCallState = _ref.read(voipCallingControllerProvider);
      if (currentCallState.isActive && currentCallState.callId == callId) {
        debugPrint('[IncomingCallManager] Call $callId already active in controller; navigating directly');
        _navigateToCall(callId);
        return;
      }

      if (callId.startsWith('mock-call-')) {
        await _ref
            .read(voipCallingControllerProvider.notifier)
            .startDebugCall(
              peerName: 'Sarah Connor',
              peerPhone: '+1 555-0199',
            );
        _navigateToCall(callId);
        return;
      }

      final repo = _ref.read(voipCallingRepositoryProvider);
      final session = await repo.getCallSession(callId);

      await _ref
          .read(voipCallingControllerProvider.notifier)
          .answerCall(
            callId: callId,
            callerName: session?.peerName ?? 'KeepSIMs Caller',
            callerAvatar: session?.peerAvatarUrl,
            callerPhone: session?.peerPhone,
          );

      _navigateToCall(callId);
    };

    _callkit.onCallDeclined = (callId) async {
      debugPrint('[IncomingCallManager] User declined CallKit call: $callId');
      _presentedCallIds.remove(callId);
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
      _presentedCallIds.remove(callId);
      if (callId.startsWith('mock-call-')) return;
      final currentCallState = _ref.read(voipCallingControllerProvider);
      if (currentCallState.isActive && currentCallState.callId == callId) {
        debugPrint('[IncomingCallManager] Call $callId is active in app; ignoring native notification timeout');
        return;
      }
      await _ref
          .read(voipCallingRepositoryProvider)
          .endCall(callId: callId, status: 'missed', endReason: 'timeout');
    };

    _callkit.onCallEnded = (callId) async {
      debugPrint('[IncomingCallManager] User or system ended CallKit call: $callId');
      _presentedCallIds.remove(callId);
      if (callId.startsWith('mock-call-')) return;
      final currentCallState = _ref.read(voipCallingControllerProvider);
      if (currentCallState.isActive && currentCallState.callId == callId) {
        await _ref
            .read(voipCallingControllerProvider.notifier)
            .endCall(status: 'completed', reason: 'native_hangup');
      }
    };

    // Cold-start recovery: check for calls accepted before Flutter attached listeners
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      debugPrint('[IncomingCallManager] Active CallKit calls at init: ${activeCalls.length}');
      for (final call in activeCalls) {
        final isOutgoing = call.extra?['isOutgoing'] == true;
        if (isOutgoing) {
          await FlutterCallkitIncoming.endCall(call.id);
          continue;
        }
        if (call.isAccepted) {
          final currentCallState = _ref.read(voipCallingControllerProvider);
          if (currentCallState.isActive && currentCallState.callId == call.id) {
            debugPrint('[IncomingCallManager] Call ${call.id} already active in controller; skipping duplicate recovery');
            _navigateToCall(call.id);
            break;
          }

          final repo = _ref.read(voipCallingRepositoryProvider);
          final session = await repo.getCallSession(call.id);
          if (session == null ||
              session.status == 'ended' ||
              session.status == 'completed' ||
              session.status == 'declined' ||
              session.status == 'timeout' ||
              session.status == 'failed') {
            debugPrint('[IncomingCallManager] Call ${call.id} is already in terminal status (${session?.status}); clearing native CallKit');
            await FlutterCallkitIncoming.endCall(call.id);
            continue;
          }

          debugPrint('[IncomingCallManager] Recovering accepted CallKit call: ${call.id}');
          _ref.read(splashCompletedProvider.notifier).complete();

          await _ref
              .read(voipCallingControllerProvider.notifier)
              .answerCall(
                callId: call.id,
                callerName:
                    session.peerName ?? call.nameCaller ?? 'KeepSIMs Caller',
                callerAvatar: session.peerAvatarUrl ?? call.avatar,
                callerPhone: session.peerPhone ?? call.handle,
              );

          _navigateToCall(call.id);
          break;
        }
      }
    } catch (e) {
      debugPrint('[IncomingCallManager] Error inspecting activeCalls at init: $e');
    }

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
      debugPrint('[IncomingCallManager] Auth event: ${data.event}');
      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated) {
        _setupRealtimeIncomingCallListener();
        registerDeviceTokens();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _realtimeChannel?.unsubscribe();
        _realtimeChannel = null;
      }
    });

    // If user is already authenticated at initialize(), set up immediately
    if (supabase.auth.currentUser != null) {
      _setupRealtimeIncomingCallListener();
      await registerDeviceTokens();
    }
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
              if (_presentedCallIds.contains(callId)) {
                debugPrint('[IncomingCallManager] Call $callId already presented, skipping duplicate event');
                return;
              }
              final currentCallState = _ref.read(voipCallingControllerProvider);
              if (currentCallState.isActive && currentCallState.callId == callId) {
                debugPrint('[IncomingCallManager] Call $callId already active in controller, skipping show');
                return;
              }
              _presentedCallIds.add(callId);

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
                status == 'timeout' ||
                status == 'failed') {
              _presentedCallIds.remove(callId);
              debugPrint('[IncomingCallManager] Ending native CallKit for call $callId with status $status');
              await _callkit.endCall(callId);
              await _callkit.endAllCalls();
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[IncomingCallManager] Realtime subscription status for $uid: $status (error: $error)');
        });
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
      if (_presentedCallIds.contains(callId)) {
        debugPrint('[IncomingCallManager] Call $callId already presented via push, skipping duplicate');
        return;
      }
      final currentCallState = _ref.read(voipCallingControllerProvider);
      if (currentCallState.isActive && currentCallState.callId == callId) {
        debugPrint('[IncomingCallManager] Call $callId already active in controller, skipping push show');
        return;
      }
      _presentedCallIds.add(callId);

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
