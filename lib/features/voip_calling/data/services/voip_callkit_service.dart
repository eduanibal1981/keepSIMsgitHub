/// KeepSIMs — Native CallKit & Android Telecom Bridge Service
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class VoipCallkitService {
  StreamSubscription<CallEvent?>? _callEventSub;

  void Function(String callId)? onCallAccepted;
  void Function(String callId)? onCallDeclined;
  void Function(String callId)? onCallTimeout;
  void Function(String callId)? onCallEnded;
  void Function()? onAudioSessionActivated;
  void Function()? onAudioSessionDeactivated;
  void Function(bool isMuted)? onToggleMute;

  /// Start listening to native CallKit / Android Telecom events
  void startListening() {
    _callEventSub?.cancel();
    _callEventSub = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      debugPrint('[CallKit] Event: ${event.eventName}');

      switch (event) {
        case CallEventActionCallAccept(:final callKitParams):
          onCallAccepted?.call(callKitParams.id);
        case CallEventActionCallDecline(:final callKitParams):
          onCallDeclined?.call(callKitParams.id);
        case CallEventActionCallTimeout(:final id):
          onCallTimeout?.call(id);
        case CallEventActionCallEnded(:final callKitParams):
          onCallEnded?.call(callKitParams.id);
        case CallEventActionCallToggleAudioSession(:final isActive):
          debugPrint('[CallKit] Native audio session active: $isActive');
          if (isActive) {
            onAudioSessionActivated?.call();
          } else {
            onAudioSessionDeactivated?.call();
          }
        case CallEventActionCallToggleMute(:final isMuted):
          debugPrint('[CallKit] Native call toggle mute: $isMuted');
          onToggleMute?.call(isMuted);
        default:
          break;
      }
    });
  }

  /// Register native outgoing call (CallKit on iOS / Telecom on Android)
  Future<void> startOutgoingCall({
    required String callId,
    required String calleeName,
    String? calleeAvatar,
    String? calleePhone,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: calleeName.isNotEmpty ? calleeName : 'KeepSIMs Contact',
      appName: 'KeepSIMs',
      avatar: calleeAvatar,
      handle: calleePhone ?? 'KeepSIMs Voice Call',
      type: 0, // Audio call
      extra: <String, dynamic>{'callId': callId, 'isOutgoing': true},
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        backgroundColor: '#0F172A',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'KeepSIMs Internet Calls',
        missedCallNotificationChannelName: 'KeepSIMs Missed Calls',
        isShowCallID: true,
        isShowFullLockedScreen: false,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );

    try {
      await FlutterCallkitIncoming.startCall(params);
      debugPrint('[CallKit] Native outgoing call registered: $callId');
    } catch (e) {
      debugPrint('[CallKit] Error registering outgoing call: $e');
    }
  }

  /// Display native incoming call UI (CallKit on iOS / Full-Screen intent on Android)
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    String? callerAvatar,
    String? callerPhone,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName.isNotEmpty ? callerName : 'KeepSIMs Caller',
      appName: 'KeepSIMs',
      avatar: callerAvatar,
      handle: callerPhone ?? 'KeepSIMs Voice Call',
      type: 0, // Audio call
      duration: 45000, // 45-second ring timeout
      extra: <String, dynamic>{'callId': callId, 'isOutgoing': false},
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0F172A',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'KeepSIMs Internet Calls',
        missedCallNotificationChannelName: 'KeepSIMs Missed Calls',
        isShowCallID: true,
        isShowFullLockedScreen: true,
        isFullScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        // Audio session must NOT be active while incoming call is ringing.
        // Activating it prematurely routes the incoming ringtone to the earpiece.
        audioSessionActive: false,
        configureAudioSession: false,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Inform native system that call has ended/connected
  Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
  }

  /// End all native active calls
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }

  /// Retrieve Apple PushKit VoIP token on iOS
  Future<String?> getDevicePushTokenVoIP() async {
    try {
      return await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    } catch (_) {
      return null;
    }
  }

  /// Stop listening to events
  void dispose() {
    _callEventSub?.cancel();
    _callEventSub = null;
  }
}
