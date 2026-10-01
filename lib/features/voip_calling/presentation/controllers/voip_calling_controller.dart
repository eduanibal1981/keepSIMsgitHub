/// KeepSIMs — VoIP Calling Controller
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/call_audio_session_manager.dart';
import 'package:keep_sims/features/voip_calling/data/services/call_recovery_coordinator.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_signaling_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_quality_collector.dart';

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
  final CallQualitySnapshot? qualitySnapshot;
  final bool showQualityHud;
  final Map<String, dynamic>? lastSessionReport;

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
    this.qualitySnapshot,
    this.showQualityHud = false,
    this.lastSessionReport,
  });

  bool get isActive =>
      status == 'calling' ||
      status == 'ringing' ||
      status == 'connecting' ||
      status == 'connected' ||
      status == 'reconnecting';
  bool get isTerminal =>
      status == 'ended' ||
      status == 'completed' ||
      status == 'declined' ||
      status == 'busy' ||
      status == 'failed' ||
      status == 'timeout' ||
      status == 'missed';

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
    CallQualitySnapshot? qualitySnapshot,
    bool? showQualityHud,
    Map<String, dynamic>? lastSessionReport,
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
      qualitySnapshot: qualitySnapshot ?? this.qualitySnapshot,
      showQualityHud: showQualityHud ?? this.showQualityHud,
      lastSessionReport: lastSessionReport ?? this.lastSessionReport,
    );
  }
}

final voipCallingControllerProvider =
    NotifierProvider<VoipCallingController, VoipActiveCallState>(
      VoipCallingController.new,
    );

/// Provider for fetching VoIP call history
final voipCallHistoryProvider =
    FutureProvider.autoDispose<List<VoipCallSession>>((ref) async {
  final repo = ref.watch(voipCallingRepositoryProvider);
  return repo.getCallHistory();
});

class VoipCallingController extends Notifier<VoipActiveCallState> {
  final WebRTCAudioService _webrtc = WebRTCAudioService();
  final VoipSignalingService _signaling = VoipSignalingService();
  final CallAudioSessionManager _audioSession = CallAudioSessionManager();
  final VoipCallkitService _callkit = VoipCallkitService();
  final WebRTCQualityCollector _qualityCollector = WebRTCQualityCollector();
  CallRecoveryCoordinator? _recoveryCoordinator;
  StreamSubscription<CallQualitySnapshot>? _qualitySub;

  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Timer? _connectingDeadlineTimer;
  Timer? _answerPollTimer;
  StreamSubscription<VoipCallSession?>? _dbSessionSub;
  bool _isEnding = false;
  bool _isAnswering = false;

  @override
  VoipActiveCallState build() {
    ref.onDispose(() {
      _cleanup();
    });

    _callkit.startListening();
    _callkit.onAudioSessionActivated = () {
      // Only activate audio session once call is actually connected.
      // Activating prematurely while incoming alert is ringing forces ringtone to earpiece.
      if (state.isActive && state.status == 'connected') {
        _audioSession.setActive(true);
      }
    };
    _callkit.onToggleMute = (muted) {
      if (state.isMuted != muted) {
        toggleMute();
      }
    };

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

      // Register outgoing call with native CallKit / Android Telecom
      unawaited(_callkit.startOutgoingCall(
        callId: callId,
        calleeName: calleeName,
        calleeAvatar: calleeAvatar,
        calleePhone: calleePhone,
      ));

      // Initialize WebRTC with received STUN/TURN servers
      final hasTurn = initRes.iceServers.any(
        (s) => s.urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:')),
      );
      _qualityCollector.setHasTurnServers(hasTurn);
      await _webrtc.initialize(iceServers: initRes.iceServers);
      await _webrtc.openMicrophone();

      // Initialize Call Recovery Coordinator (Caller is impolite)
      _recoveryCoordinator = CallRecoveryCoordinator(
        webrtc: _webrtc,
        signaling: _signaling,
        onRefreshIceServers: () => repository.getCallIceServers(callId),
        isPolite: false,
      );
      _wireRecoveryCallbacks();
      _recoveryCoordinator!.attach();

      // Setup WebRTC callbacks
      _webrtc.onLocalIceCandidate = (candidate) {
        final gen = _recoveryCoordinator?.currentGeneration ?? 0;
        _signaling.sendIceCandidate(candidate, gen);
      };

      _webrtc.onConnectionStateChanged = (connState) {
        if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onCallConnected();
        }
        _recoveryCoordinator?.handlePeerConnectionState(connState);
      };

      _webrtc.onIceConnected = () {
        debugPrint('[VoIP Controller] onIceConnected fired on caller');
        _onCallConnected();
      };

      // Wire signaling listeners BEFORE connecting channel
      _setupSignalingListeners();

      // Connect Realtime Signaling Channel
      final subResult = await _signaling.connect(callId);
      if (subResult == SignalingSubscriptionResult.channelError) {
        debugPrint('[VoIP Controller] Warning: signaling channelError on startCall');
      }

      // Create Offer with gathered ICE candidates embedded in SDP
      final offer = await _webrtc.createOffer();
      if (offer.sdp != null) {
        await _signaling.sendOffer(offer.sdp!);
        await repository.saveOffer(callId: callId, offerSdp: offer.sdp!);
      }

      // Watch session from DB and poll for answer if broadcast is dropped
      _subscribeDbSession(callId);
      _pollAnswerFromDbIfPending(callId);

      // Start 45s Ring Timeout Timer
      _ringTimeoutTimer?.cancel();
      _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (state.status == 'calling' || state.status == 'ringing') {
          endCall(status: 'timeout', reason: 'no_answer');
        }
      });
    } catch (e) {
      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Call start error during teardown suppressed: $e');
        return;
      }
      debugPrint('[VoIP Controller] Call start error: $e');
      state = state.copyWith(status: 'failed', errorMessage: e.toString());
      await _cleanup();
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (state.status == 'failed') {
          state = const VoipActiveCallState();
          _isEnding = false;
        }
      });
    }
  }

  /// Answer an incoming WhatsApp-like call
  Future<void> answerCall({
    required String callId,
    required String callerName,
    String? callerAvatar,
    String? callerPhone,
  }) async {
    if (_isAnswering) {
      debugPrint('[VoIP Controller] answerCall already in progress, ignoring duplicate call');
      return;
    }
    if (state.isActive && state.callId == callId && !state.isTerminal) {
      debugPrint('[VoIP Controller] Call $callId already active in state');
      return;
    }
    _isAnswering = true;
    _isEnding = false;

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
      if (session != null && session.isTerminal) {
        state = state.copyWith(
          status: 'ended',
          errorMessage: 'Call is no longer available',
        );
        await _cleanup();
        return;
      }

      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Call aborted during session fetch');
        return;
      }

      // Retrieve authorized ICE servers (STUN + TURN) for the callee
      final iceServers = await repository.getCallIceServers(callId);
      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Call aborted during ICE server fetch');
        return;
      }

      final hasTurn = iceServers.any(
        (s) => s.urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:')),
      );
      _qualityCollector.setHasTurnServers(hasTurn);
      await _webrtc.initialize(iceServers: iceServers);
      await _webrtc.openMicrophone();

      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Call aborted during WebRTC initialization');
        return;
      }

      // Initialize Call Recovery Coordinator (Callee is polite)
      _recoveryCoordinator = CallRecoveryCoordinator(
        webrtc: _webrtc,
        signaling: _signaling,
        onRefreshIceServers: () => repository.getCallIceServers(callId),
        isPolite: true,
      );
      _wireRecoveryCallbacks();
      _recoveryCoordinator!.attach();

      _webrtc.onLocalIceCandidate = (candidate) {
        final gen = _recoveryCoordinator?.currentGeneration ?? 0;
        _signaling.sendIceCandidate(candidate, gen);
      };

      _webrtc.onConnectionStateChanged = (connState) {
        if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onCallConnected();
        }
        _recoveryCoordinator?.handlePeerConnectionState(connState);
      };

      _webrtc.onIceConnected = () {
        debugPrint('[VoIP Controller] onIceConnected fired on callee');
        _onCallConnected();
      };

      // Wire signaling listeners BEFORE connecting channel
      _setupSignalingListeners();

      // Start 25s bounded connecting deadline
      _startConnectingDeadlineTimer();

      await _signaling.connect(callId);

      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Call aborted during signaling connect');
        return;
      }

      // If offer is available from DB, handle it immediately
      if (session != null &&
          session.offerSdp != null &&
          session.offerSdp!.isNotEmpty) {
        final answer = await _webrtc.handleOfferAndCreateAnswer(
          session.offerSdp!,
        );
        if (answer.sdp != null) {
          await _signaling.sendAnswer(answer.sdp!);
          final claimRes = await repository.answerCall(callId: callId, answerSdp: answer.sdp!);
          debugPrint('[VoIP Controller] Answer claim response: $claimRes');
        }
      } else {
        // Prompt caller via signaling and poll DB fallback for offer
        await _signaling.sendCalleeReady();
        _pollOfferFromDbIfPending(callId);
      }

      _subscribeDbSession(callId);
    } catch (e) {
      if (_isEnding || state.isTerminal) {
        debugPrint('[VoIP Controller] Answer error during teardown suppressed: $e');
        return;
      }
      debugPrint('[VoIP Controller] Answer error: $e');
      state = state.copyWith(status: 'failed', errorMessage: e.toString());
      await _cleanup();
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (state.status == 'failed') {
          state = const VoipActiveCallState();
          _isEnding = false;
        }
      });
    } finally {
      _isAnswering = false;
    }
  }

  void _wireRecoveryCallbacks() {
    _recoveryCoordinator?.onStateChanged = (recState) {
      if (_recoveryCoordinator!.isRecovering && state.status == 'connected') {
        state = state.copyWith(status: 'reconnecting');
      }
    };
    _recoveryCoordinator?.onRecoverySucceeded = () {
      state = state.copyWith(status: 'connected');
    };
    _recoveryCoordinator?.onRecoveryFailed = (reason) {
      endCall(status: 'failed', reason: reason);
    };
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

    _signaling.onCalleeReady = () async {
      if (state.isOutgoing) {
        debugPrint('[VoIP Controller] Callee ready received. Re-broadcasting SDP offer if needed.');
        final offer = _webrtc.lastLocalDescription;
        if (offer != null && offer.sdp != null) {
          await _signaling.sendOffer(offer.sdp!);
        }
      }
    };

    _signaling.onSdpOfferReceived = (sdp) async {
      try {
        if (!state.isOutgoing &&
            !_webrtc.hasRemoteDescription &&
            !state.isTerminal &&
            !_isEnding) {
          if (_webrtc.peerConnection == null) {
            debugPrint('[VoIP Controller] onSdpOfferReceived: peerConnection not initialized, skipping');
            return;
          }
          final answer = await _webrtc.handleOfferAndCreateAnswer(sdp);
          if (answer.sdp != null) {
            await _signaling.sendAnswer(answer.sdp!);
            final repo = ref.read(voipCallingRepositoryProvider);
            if (state.callId != null) {
              await repo.answerCall(callId: state.callId!, answerSdp: answer.sdp!);
            }
          }
        }
      } catch (e) {
        debugPrint('[VoIP Controller] Error handling SDP offer from signaling: $e');
      }
    };

    _signaling.onSdpAnswerReceived = (sdp) async {
      try {
        if (state.isOutgoing &&
            !_webrtc.hasRemoteDescription &&
            !state.isTerminal &&
            !_isEnding &&
            _webrtc.peerConnection != null) {
          debugPrint('[VoIP Controller] SDP answer received via signaling');
          state = state.copyWith(status: 'connecting');
          _startConnectingDeadlineTimer();
          await _webrtc.setRemoteAnswer(sdp);
        }
      } catch (e) {
        debugPrint('[VoIP Controller] Error handling SDP answer from signaling: $e');
      }
    };

    _signaling.onIceRestartOfferReceived = (sdp, gen) async {
      await _recoveryCoordinator?.handleRemoteRestartOffer(sdp, gen);
    };

    _signaling.onIceRestartAnswerReceived = (sdp, gen) async {
      await _recoveryCoordinator?.handleRemoteRestartAnswer(sdp, gen);
    };

    _signaling.onRemoteCandidateReceived = (candidate, gen) async {
      if (_recoveryCoordinator != null) {
        await _recoveryCoordinator!.handleRemoteCandidate(candidate, gen);
      } else {
        await _webrtc.addCandidate(candidate);
      }
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

  void _startConnectingDeadlineTimer() {
    _connectingDeadlineTimer?.cancel();
    _connectingDeadlineTimer = Timer(const Duration(seconds: 25), () {
      if (state.isActive &&
          (state.status == 'connecting' || state.status == 'calling' || state.status == 'ringing')) {
        debugPrint('[VoIP Controller] Bounded connecting deadline (25s) expired without media connection');
        endCall(status: 'failed', reason: 'connection_timeout');
      }
    });
  }

  void _pollOfferFromDbIfPending(String callId) {
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!state.isActive ||
          state.status == 'connected' ||
          state.isTerminal ||
          _isEnding ||
          _webrtc.hasRemoteDescription) {
        timer.cancel();
        return;
      }
      if (timer.tick > 60) {
        timer.cancel();
        return;
      }
      try {
        final session = await ref
            .read(voipCallingRepositoryProvider)
            .getCallSession(callId, maxRetries: 0);
        if (session != null &&
            session.offerSdp != null &&
            session.offerSdp!.isNotEmpty &&
            state.isActive &&
            state.status == 'connecting' &&
            !state.isTerminal &&
            !_isEnding &&
            _webrtc.peerConnection != null &&
            !_webrtc.hasRemoteDescription) {
          timer.cancel();
          final answer = await _webrtc.handleOfferAndCreateAnswer(
            session.offerSdp!,
          );
          if (answer.sdp != null) {
            await _signaling.sendAnswer(answer.sdp!);
            await ref
                .read(voipCallingRepositoryProvider)
                .answerCall(callId: callId, answerSdp: answer.sdp!);
          }
        }
      } catch (e) {
        debugPrint('[VoIP Controller] Poll offer fallback error: $e');
      }
    });
  }

  void _pollAnswerFromDbIfPending(String callId) {
    _answerPollTimer?.cancel();
    _answerPollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!state.isActive ||
          state.status == 'connected' ||
          state.isTerminal ||
          _isEnding ||
          _webrtc.hasRemoteDescription) {
        timer.cancel();
        return;
      }
      if (timer.tick > 60) {
        timer.cancel();
        return;
      }
      try {
        final session = await ref
            .read(voipCallingRepositoryProvider)
            .getCallSession(callId, maxRetries: 0);
        if (session != null &&
            session.answerSdp != null &&
            session.answerSdp!.isNotEmpty &&
            state.isActive &&
            (state.status == 'calling' || state.status == 'ringing' || state.status == 'connecting') &&
            !state.isTerminal &&
            !_isEnding &&
            _webrtc.peerConnection != null &&
            !_webrtc.hasRemoteDescription) {
          timer.cancel();
          debugPrint('[VoIP Controller] Answer retrieved from DB fallback. Setting remote description.');
          state = state.copyWith(status: 'connecting');
          _startConnectingDeadlineTimer();
          await _webrtc.setRemoteAnswer(session.answerSdp!);
        }
      } catch (e) {
        debugPrint('[VoIP Controller] Poll answer fallback error: $e');
      }
    });
  }

  void _onCallConnected() {
    if (state.status == 'connected') return;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _connectingDeadlineTimer?.cancel();
    _connectingDeadlineTimer = null;
    state = state.copyWith(status: 'connected');

    final callId = state.callId;
    if (callId != null &&
        !callId.startsWith('debug-call-') &&
        !callId.startsWith('mock-call-')) {
      unawaited(FlutterCallkitIncoming.setCallConnected(callId));
      unawaited(
        ref
            .read(voipCallingRepositoryProvider)
            .markConnected(callId)
            .catchError((e) {
              debugPrint('[VoIP Controller] markConnected warning: $e');
              return {'ok': false, 'error': e.toString()};
            }),
      );
    }

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });

    // Start quality telemetry collector
    final pc = _webrtc.peerConnection;
    if (pc != null) {
      _qualityCollector.start(pc);
      _qualitySub?.cancel();
      _qualitySub = _qualityCollector.snapshotStream.listen((snapshot) {
        state = state.copyWith(qualitySnapshot: snapshot);
      });
    }
  }

  void _subscribeDbSession(String callId) {
    _dbSessionSub?.cancel();
    _dbSessionSub = ref
        .read(voipCallingRepositoryProvider)
        .watchCallSession(callId)
        .listen((session) async {
          if (session == null) return;
          if (session.isTerminal && !state.isTerminal) {
            state = state.copyWith(status: session.status);
            _cleanup();
            return;
          }

          // If caller sees callee accepted with answerSdp and remote description is not set yet
          if (state.isOutgoing &&
              (session.status == 'accepted' || session.status == 'connected') &&
              session.answerSdp != null &&
              session.answerSdp!.isNotEmpty &&
              !state.isTerminal &&
              !_isEnding &&
              _webrtc.peerConnection != null &&
              !_webrtc.hasRemoteDescription) {
            debugPrint('[VoIP Controller] DB session stream provided answer_sdp');
            state = state.copyWith(status: 'connecting');
            _startConnectingDeadlineTimer();
            try {
              await _webrtc.setRemoteAnswer(session.answerSdp!);
            } catch (e) {
              debugPrint('[VoIP Controller] Error setting remote answer from DB stream: $e');
            }
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

  void toggleQualityHud() {
    state = state.copyWith(showQualityHud: !state.showQualityHud);
  }

  void sendDtmf(String tone) {
    if (state.status != 'connected') return;
    _webrtc.insertDtmf(tone);
  }

  void setMinimized(bool minimized) {
    state = state.copyWith(isMinimized: minimized);
  }

  Map<String, dynamic> exportSanitizedSessionReport() {
    return _qualityCollector.exportSanitizedSessionReport(
      callId: state.callId,
      endReason: 'user_exported',
    );
  }

  Map<String, dynamic> exportDiagnosticsReport() => exportSanitizedSessionReport();

  Future<void> endCall({
    String status = 'completed',
    String reason = 'normal_hangup',
  }) async {
    if (_isEnding) return;
    _isEnding = true;

    final callId = state.callId;

    // Export sanitized session summary before tearing down
    final sessionReport = _qualityCollector.exportSanitizedSessionReport(
      callId: callId,
      endReason: reason,
    );

    // Cancel all timers immediately
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _connectingDeadlineTimer?.cancel();
    _answerPollTimer?.cancel();

    // Determine truthful final status
    String finalStatus = status;
    if (state.status != 'connected' && finalStatus == 'completed') {
      finalStatus = state.isOutgoing ? 'cancelled' : 'declined';
    }

    // Immediately set state to ended & un-minimized so floating bar & UI dismiss instantly
    state = state.copyWith(
      status: 'ended',
      isMinimized: false,
      lastSessionReport: sessionReport,
    );

    if (callId != null &&
        !callId.startsWith('debug-call-') &&
        !callId.startsWith('mock-call-')) {
      // 1. Broadcast ended event FIRST before disconnecting channel
      try {
        await _signaling.sendEnded(reason: reason);
      } catch (e) {
        debugPrint('[VoIP Controller] sendEnded error: $e');
      }

      // 2. Clear native CallKit
      try {
        await _callkit.endCall(callId);
        await _callkit.endAllCalls();
      } catch (_) {}

      // 3. Persist terminal transition
      try {
        await ref
            .read(voipCallingRepositoryProvider)
            .endCall(callId: callId, status: finalStatus, endReason: reason);
      } catch (e) {
        debugPrint('[VoIP Controller] Repository endCall error: $e');
      }
    } else if (callId != null) {
      unawaited(_callkit.endCall(callId));
      unawaited(_callkit.endAllCalls());
    }

    // 4. Release local microphone, audio session, WebRTC, and channel
    await _cleanup();
    ref.invalidate(voipCallHistoryProvider);
    // Keep terminal state visible for 2.5s so screen displays final status before resetting
    Future.delayed(const Duration(milliseconds: 2500), () {
      state = const VoipActiveCallState();
      _isEnding = false;
    });
  }

  Future<void> declineCall({String reason = 'user_declined'}) async {
    if (_isEnding) return;
    _isEnding = true;

    final callId = state.callId;
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _connectingDeadlineTimer?.cancel();
    _answerPollTimer?.cancel();

    state = state.copyWith(status: 'declined', isMinimized: false);

    if (callId != null &&
        !callId.startsWith('debug-call-') &&
        !callId.startsWith('mock-call-')) {
      try {
        await _signaling.sendDeclined(reason: reason);
      } catch (e) {
        debugPrint('[VoIP Controller] sendDeclined error: $e');
      }
      try {
        await _callkit.endCall(callId);
        await _callkit.endAllCalls();
      } catch (_) {}
      try {
        await ref
            .read(voipCallingRepositoryProvider)
            .endCall(callId: callId, status: 'declined', endReason: reason);
      } catch (e) {
        debugPrint('[VoIP Controller] Repository declineCall error: $e');
      }
    } else if (callId != null) {
      unawaited(_callkit.endCall(callId));
    }

    await _cleanup();
    ref.invalidate(voipCallHistoryProvider);
    // Keep terminal state visible for 2.5s so screen displays final status before resetting
    Future.delayed(const Duration(milliseconds: 2500), () {
      state = const VoipActiveCallState();
      _isEnding = false;
    });
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = null;
    _connectingDeadlineTimer?.cancel();
    _connectingDeadlineTimer = null;
    _answerPollTimer?.cancel();
    _answerPollTimer = null;
    _dbSessionSub?.cancel();
    _dbSessionSub = null;

    _qualitySub?.cancel();
    _qualitySub = null;
    _qualityCollector.stop();

    _recoveryCoordinator?.detach();
    _recoveryCoordinator = null;

    // Release CallKit and Android Telecom call state immediately
    final callId = state.callId;
    if (callId != null) {
      try {
        await _callkit.endCall(callId);
      } catch (_) {}
    }
    try {
      await _callkit.endAllCalls();
    } catch (_) {}

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
