import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_webrtc/telnyx_webrtc.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

final callAudioServiceProvider = Provider<CallAudioService>((ref) {
  final service = CallAudioService();
  ref.onDispose(service.dispose);
  return service;
});

/// One foreground app participant. Phone dialing remains server-authorized.
class CallAudioService with WidgetsBindingObserver {
  CallAudioService() {
    WidgetsBinding.instance.addObserver(this);
  }
  TelnyxClient? _client;
  Call? _call;
  Completer<void>? _registered;
  Completer<void>? _connected;
  RTCVideoRenderer? _remoteAudioRenderer;
  void Function(String)? onFailure;
  void Function()? onEnded;
  bool _closing = false;

  Future<void> requestMicrophone() async {
    if (!kIsWeb &&
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw Exception(
        'In-app calling is supported on Android, iPhone, and web.',
      );
    }

    if (!kIsWeb) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (status.isPermanentlyDenied) {
        throw Exception(
          'Microphone permission is permanently denied. Please enable it in Settings to place calls.',
        );
      }
      if (!status.isGranted) {
        throw Exception(
          'Allow microphone access to make a call, then try again.',
        );
      }
    }

    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } catch (_) {
      throw Exception(
        'Allow microphone access to make a call, then try again.',
      );
    }
  }

  Future<void> connect(String token) async {
    close();
    onFailure = null;
    onEnded = null;
    _closing = false;
    final ready = _registered = Completer<void>();
    _connected = Completer<void>();
    // Attach an error listener immediately, including when login fails before dial.
    unawaited(_connected!.future.catchError((Object _) {}));
    final client = _client = TelnyxClient();
    client.onSocketErrorReceived = (_) =>
        _fail('Could not connect call audio. Check your internet connection.');
    client.onConnectionStateChanged = (status) {
      if (!_closing &&
          ready.isCompleted &&
          [
            ConnectionStatus.disconnected,
            ConnectionStatus.reconnecting,
          ].contains(status)) {
        _fail('Call audio disconnected. Please call again.');
      }
    };
    client.onSocketMessageReceived = (message) {
      if (_closing || _client != client) return;
      if (message.socketMethod == SocketMethod.clientReady &&
          !ready.isCompleted) {
        ready.complete();
      } else if (message.socketMethod == SocketMethod.invite && _call == null) {
        final invite = message.message.inviteParams;
        if (invite == null) return;
        // This credential exists only for the call explicitly started by the user.
        final call = _call = client.acceptCall(invite, 'KeepSIMs', '', '');
        if (kIsWeb) {
          _initWebAudio(call);
        }
        final previousStateChanged = call.callHandler.onCallStateChanged;
        call.callHandler.onCallStateChanged = (state) {
          previousStateChanged(state);
          if (_closing) return;
          if (state == CallState.active && !_connected!.isCompleted) {
            call.enableSpeakerPhone(false);
            _connected!.complete();
          } else if ([
            CallState.error,
            CallState.dropped,
            CallState.reconnecting,
          ].contains(state)) {
            _fail('Call audio disconnected. Please call again.');
          } else if (state == CallState.done) {
            if (!_connected!.isCompleted) {
              _connected!.completeError(
                Exception('Call audio ended before connecting.'),
              );
            }
            onEnded?.call();
          }
        };
      }
    };
    client.connectWithToken(
      TokenConfig(
        sipToken: token,
        sipCallerIDName: 'KeepSIMs',
        sipCallerIDNumber: '',
        debug: false,
        logLevel: LogLevel.none,
        autoReconnect: false,
      ),
    );
    await ready.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw Exception('Call audio connection timed out. Please try again.'),
    );
  }

  Future<void> _initWebAudio(Call call) async {
    try {
      final renderer = _remoteAudioRenderer = RTCVideoRenderer();
      await renderer.initialize();
      final prevOnAddStream = call.peerConnection?.onAddRemoteStream;
      call.peerConnection?.onAddRemoteStream = (session, stream) {
        prevOnAddStream?.call(session, stream);
        renderer.srcObject = stream;
      };
    } catch (_) {
      // Best-effort web audio routing helper
    }
  }

  Future<void> waitForAudio() => _connected!.future.timeout(
    const Duration(seconds: 25),
    onTimeout: () =>
        throw Exception('Could not establish call audio. Please try again.'),
  );

  void setMuted(bool muted) => _call?.setMuteState(muted);
  void setSpeaker(bool enabled) => _call?.enableSpeakerPhone(enabled);
  void sendDtmf(String tone) => _call?.dtmf(tone);

  void _fail(String message) {
    if (_closing) return;
    if (_registered != null && !_registered!.isCompleted) {
      _registered!.completeError(Exception(message));
    }
    if (_connected != null && !_connected!.isCompleted) {
      _connected!.completeError(Exception(message));
    }
    onFailure?.call(message);
  }

  void close() {
    _closing = true;
    // Cancellation must release waiters as well as the microphone/socket.
    for (final pending in [_registered, _connected]) {
      if (pending != null && !pending.isCompleted) {
        pending.completeError(Exception('Call cancelled.'));
      }
    }
    if (_remoteAudioRenderer != null) {
      try {
        _remoteAudioRenderer!.srcObject = null;
        _remoteAudioRenderer!.dispose();
      } catch (_) {}
      _remoteAudioRenderer = null;
    }
    try {
      _call?.endCall();
    } catch (_) {
      /* Already ended. */
    }
    try {
      _client?.disconnect();
    } catch (_) {
      /* Already disconnected. */
    }
    _call = null;
    _client = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground calling only until native CallKit/ConnectionService is added.
    if (_client != null &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _fail(
        'Call ended because KeepSIMs left the foreground. Keep the app open while calling.',
      );
      close();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    close();
  }
}
