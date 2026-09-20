/// KeepSIMs — VoIP Calling Controller
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/call_audio_session_manager.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_signaling_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';

class VoipActiveCallState {
  final String? callId;
  final String peerUserId;
  final String peerName;
  final String? peerAvatarUrl;
  final String? peerPhone;
  final bool isOutgoing;
  final String
  status; // 'idle', 'calling', 'ringing', 'connected', 'reconnecting', 'ended', 'declined', 'busy', 'failed', 'timeout'
  final int durationSeconds;
  final bool isMuted;
  final bool isSpeaker;
  final bool isNearEar;
  final bool isPeerMuted;
  final bool isMinimized;
  final String? errorMessage;

  const VoipActiveCallState({
    this.callId,
    this.peerUserId = '',
    this.peerName = '',
    this.peerAvatarUrl,
    this.peerPhone,
    this.isOutgoing = false,
    this.status = 'idle',
    this.durationSeconds = 0,
    this.isMuted = false,
    this.isSpeaker = false,
    this.isNearEar = false,
    this.isPeerMuted = false,
    this.isMinimized = false,
    this.errorMessage,
  });

  bool get isActive =>
      status == 'calling' ||
      status == 'ringing' ||
      status == 'connected' ||
      status == 'reconnecting';
  bool get isTerminal =>
      status == 'ended' ||
      status == 'completed' ||
      status == 'declined' ||
      status == 'busy' ||
      status == 'failed' ||
      status == 'timeout';

  VoipActiveCallState copyWith({
    String? callId,
    String? peerUserId,
    String? peerName,
    String? peerAvatarUrl,
    String? peerPhone,
    bool? isOutgoing,
    String? status,
    int? durationSeconds,
    bool? isMuted,
    bool? isSpeaker,
    bool? isNearEar,
    bool? isPeerMuted,
    bool? isMinimized,
    String? errorMessage,
  }) {
    return VoipActiveCallState(
      callId: callId ?? this.callId,
      peerUserId: peerUserId ?? this.peerUserId,
      peerName: peerName ?? this.peerName,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      peerPhone: peerPhone ?? this.peerPhone,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isNearEar: isNearEar ?? this.isNearEar,
      isPeerMuted: isPeerMuted ?? this.isPeerMuted,
      isMinimized: isMinimized ?? this.isMinimized,
      errorMessage: errorMessage,
    );
  }
}

final voipCallingControllerProvider =
    NotifierProvider<VoipCallingController, VoipActiveCallState>(
      VoipCallingController.new,
    );

class VoipCallingController extends Notifier<VoipActiveCallState> {
  final WebRTCAudioService _webrtc = WebRTCAudioService();
  final VoipSignalingService _signaling = VoipSignalingService();
  final CallAudioSessionManager _audioSession = CallAudioSessionManager();
  final VoipCallkitService _callkit = VoipCallkitService();

  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  StreamSubscription<VoipCallSession?>? _dbSessionSub;

  @override
  VoipActiveCallState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const VoipActiveCallState();
  }

  /// Start an outgoing WhatsApp-like internet voice call
  Future<void> startCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatar,
    String? calleePhone,
  }) async {
    if (state.isActive) return;

    state = VoipActiveCallState(
      peerUserId: calleeId,
      peerName: calleeName,
      peerAvatarUrl: calleeAvatar,
      peerPhone: calleePhone,
      isOutgoing: true,
      status: 'calling',
    );

    try {
      await _audioSession.initialize();
      _audioSession.onProximityChanged = (near) {
        state = state.copyWith(isNearEar: near);
      };

      final repository = ref.read(voipCallingRepositoryProvider);
      final initRes = await repository.initiateCall(calleeId: calleeId);

      if (!initRes.ok && initRes.status == 'busy') {
        state = state.copyWith(status: 'busy', errorMessage: initRes.message);
        await _cleanup();
        return;
      }

      final callId = initRes.callId;
      state = state.copyWith(callId: callId, status: 'calling');

      // Initialize WebRTC with received STUN/TURN servers
      await _webrtc.initialize(iceServers: initRes.iceServers);
      await _webrtc.openMicrophone();

      // Setup WebRTC callbacks
      _webrtc.onLocalIceCandidate = (candidate) {
        _signaling.sendIceCandidate(candidate);
      };
      _webrtc.onConnectionStateChanged = (connState) {
        if (connState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onCallConnected();
        } else if (connState ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            connState ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          state = state.copyWith(status: 'reconnecting');
        }
      };

      // Connect Realtime Signaling Channel
      await _signaling.connect(callId);
      _setupSignalingListeners();

      // Create Offer and broadcast
      final offer = await _webrtc.createOffer();
      await _signaling.sendOffer(offer.sdp!);

      // Also persist offer_sdp to session in DB for reliable negotiation / callee fallback
      if (offer.sdp != null) {
        await repository.saveOffer(callId: callId, offerSdp: offer.sdp!);
      }

      // Watch session from DB as state fallback
      _subscribeDbSession(callId);

      // Start 45s Ring Timeout Timer
      _ringTimeoutTimer?.cancel();
      _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (state.status == 'calling' || state.status == 'ringing') {
          endCall(status: 'timeout', reason: 'no_answer');
        }
      });
    } catch (e) {
      debugPrint('[VoIP Controller] Call start error: $e');
      state = state.copyWith(status: 'failed', errorMessage: e.toString());
      await _cleanup();
    }
  }

  /// Answer an incoming WhatsApp-like call
  Future<void> answerCall({
    required String callId,
    required String callerName,
    String? callerAvatar,
    String? callerPhone,
  }) async {
    _ringTimeoutTimer?.cancel();
    state = VoipActiveCallState(
      callId: callId,
      peerName: callerName,
      peerAvatarUrl: callerAvatar,
      peerPhone: callerPhone,
      isOutgoing: false,
      status: 'connecting',
    );

    try {
      await _audioSession.initialize();
      _audioSession.onProximityChanged = (near) {
        state = state.copyWith(isNearEar: near);
      };

      final repository = ref.read(voipCallingRepositoryProvider);
      final session = await repository.getCallSession(callId);
      if (session == null || session.isTerminal) {
        state = state.copyWith(
          status: 'ended',
          errorMessage: 'Call is no longer available',
        );
        await _cleanup();
        return;
      }

      // Initialize WebRTC
      const defaultIce = [
        IceServerModel(
          urls: [
            'stun:stun.l.google.com:19302',
            'stun:stun1.l.google.com:19302',
          ],
        ),
      ];
      await _webrtc.initialize(iceServers: defaultIce);
      await _webrtc.openMicrophone();

      _webrtc.onLocalIceCandidate = (candidate) {
        _signaling.sendIceCandidate(candidate);
      };
      _webrtc.onConnectionStateChanged = (connState) {
        if (connState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onCallConnected();
        }
      };

      await _signaling.connect(callId);
      _setupSignalingListeners();

      // If offer is available from DB or signaling, handle it
      if (session.offerSdp != null && session.offerSdp!.isNotEmpty) {
        final answer = await _webrtc.handleOfferAndCreateAnswer(
          session.offerSdp!,
        );
        await _signaling.sendAnswer(answer.sdp!);
        await repository.answerCall(callId: callId, answerSdp: answer.sdp!);
      }

      _subscribeDbSession(callId);
    } catch (e) {
      debugPrint('[VoIP Controller] Answer error: $e');
      state = state.copyWith(status: 'failed', errorMessage: e.toString());
      await _cleanup();
    }
  }

  /// Start a simulated debug call to test UI, sensors, timer, and audio routing without backend
  Future<void> startDebugCall({
    required String peerName,
    required String peerPhone,
    String? peerAvatar,
  }) async {
    if (state.isActive) return;

    state = VoipActiveCallState(
      callId: 'debug-call-${DateTime.now().millisecondsSinceEpoch}',
      peerName: peerName,
      peerPhone: peerPhone,
      peerAvatarUrl: peerAvatar,
      isOutgoing: true,
      status: 'calling',
    );

    try {
      await _audioSession.initialize();
      _audioSession.onProximityChanged = (near) {
        state = state.copyWith(isNearEar: near);
      };

      try {
        await _webrtc.openMicrophone();
      } catch (_) {}

      // Transition from calling -> ringing -> connected
      Timer(const Duration(seconds: 2), () {
        if (state.status == 'calling') {
          state = state.copyWith(status: 'ringing');
        }
      });

      Timer(const Duration(seconds: 4), () {
        if (state.status == 'ringing') {
          _onCallConnected();
        }
      });
    } catch (e) {
      debugPrint('[VoIP Controller] Debug call error: $e');
    }
  }

  void _setupSignalingListeners() {
    _signaling.onCalleeRinging = () {
      if (state.status == 'calling') {
        state = state.copyWith(status: 'ringing');
      }
    };

    _signaling.onSdpOfferReceived = (sdp) async {
      if (!state.isOutgoing) {
        final answer = await _webrtc.handleOfferAndCreateAnswer(sdp);
        await _signaling.sendAnswer(answer.sdp!);
        final repo = ref.read(voipCallingRepositoryProvider);
        if (state.callId != null) {
          await repo.answerCall(callId: state.callId!, answerSdp: answer.sdp!);
        }
      }
    };

    _signaling.onSdpAnswerReceived = (sdp) async {
      if (state.isOutgoing) {
        await _webrtc.setRemoteAnswer(sdp);
      }
    };

    _signaling.onRemoteCandidateReceived = (candidate) async {
      await _webrtc.addCandidate(candidate);
    };

    _signaling.onCallDeclined = (reason) {
      state = state.copyWith(
        status: 'declined',
        errorMessage: 'Call was declined',
      );
      _cleanup();
    };

    _signaling.onCallEnded = (reason) {
      state = state.copyWith(status: 'ended');
      _cleanup();
    };

    _signaling.onPeerMuteChanged = (isMuted) {
      state = state.copyWith(isPeerMuted: isMuted);
    };
  }

  void _onCallConnected() {
    _ringTimeoutTimer?.cancel();
    state = state.copyWith(status: 'connected');

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });
  }

  void _subscribeDbSession(String callId) {
    _dbSessionSub?.cancel();
    _dbSessionSub = ref
        .read(voipCallingRepositoryProvider)
        .watchCallSession(callId)
        .listen((session) {
          if (session == null) return;
          if (session.isTerminal && !state.isTerminal) {
            state = state.copyWith(status: session.status);
            _cleanup();
          }
        });
  }

  void toggleMute() {
    final next = !state.isMuted;
    _webrtc.setMuted(next);
    _signaling.sendMuteStatus(next);
    state = state.copyWith(isMuted: next);
  }

  void toggleSpeaker() {
    final next = !state.isSpeaker;
    _audioSession.setSpeakerphone(next);
    state = state.copyWith(isSpeaker: next);
  }

  void sendDtmf(String tone) {
    if (state.status != 'connected') return;
    _webrtc.insertDtmf(tone);
  }

  void setMinimized(bool minimized) {
    state = state.copyWith(isMinimized: minimized);
  }

  Future<void> endCall({
    String status = 'completed',
    String reason = 'normal_hangup',
  }) async {
    final callId = state.callId;

    // Immediately set state to ended & un-minimized so floating bar & UI dismiss instantly
    state = state.copyWith(status: 'ended', isMinimized: false);

    if (callId != null &&
        !callId.startsWith('debug-call-') &&
        !callId.startsWith('mock-call-')) {
      unawaited(_signaling.sendEnded(reason: reason));
      unawaited(_callkit.endCall(callId));
      try {
        await ref
            .read(voipCallingRepositoryProvider)
            .endCall(callId: callId, status: status, endReason: reason);
      } catch (_) {}
    } else if (callId != null) {
      unawaited(_callkit.endCall(callId));
    }

    await _cleanup();
    state = const VoipActiveCallState();
  }

  Future<void> declineCall({String reason = 'user_declined'}) async {
    final callId = state.callId;
    state = state.copyWith(status: 'declined', isMinimized: false);

    if (callId != null &&
        !callId.startsWith('debug-call-') &&
        !callId.startsWith('mock-call-')) {
      unawaited(_signaling.sendDeclined(reason: reason));
      unawaited(_callkit.endCall(callId));
      try {
        await ref
            .read(voipCallingRepositoryProvider)
            .endCall(callId: callId, status: 'declined', endReason: reason);
      } catch (_) {}
    } else if (callId != null) {
      unawaited(_callkit.endCall(callId));
    }

    await _cleanup();
    state = const VoipActiveCallState();
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _dbSessionSub?.cancel();
    _dbSessionSub = null;

    try {
      await _webrtc.dispose();
    } catch (e) {
      debugPrint('[VoIP Controller] WebRTC dispose error: $e');
    }
    try {
      await _signaling.disconnect();
    } catch (_) {}
    try {
      await _audioSession.dispose();
    } catch (_) {}
  }
}
