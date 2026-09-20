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
        default:
          break;
      }
    });
  }

  /// Display native incoming call UI (CallKit on iOS / Telecom & Full-Screen intent on Android)
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
      extra: <String, dynamic>{'callId': callId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0F172A',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'KeepSIMs Internet Calls',
        missedCallNotificationChannelName: 'KeepSIMs Missed Calls',
        isShowCallID: true,
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
