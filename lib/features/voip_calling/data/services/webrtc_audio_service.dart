/// KeepSIMs — WebRTC Audio Media Service
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/services/opus_sdp_transformer.dart';

class WebRTCAudioService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  void Function(RTCIceCandidate candidate)? onLocalIceCandidate;
  void Function(RTCPeerConnectionState state)? onConnectionStateChanged;
  void Function()? onIceConnected;
  void Function()? onRemoteAudioConnected;
  void Function(String error)? onError;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  RTCPeerConnection? get peerConnection => _peerConnection;
  bool get hasRemoteDescription => _hasRemoteDescription;
  RTCSessionDescription? _lastLocalDescription;
  RTCSessionDescription? get lastLocalDescription => _lastLocalDescription;
  List<IceServerModel> _lastIceServers = const [];
  Future<RTCSessionDescription?> getLocalDescription() async {
    return _peerConnection?.getLocalDescription();
  }

  static List<Map<String, dynamic>> _buildExpandedIceServers(
    List<IceServerModel> iceServers,
  ) {
    final expanded = <Map<String, dynamic>>[];
    for (final server in iceServers) {
      for (final url in server.urls) {
        final entry = <String, dynamic>{
          'url': url,
          'urls': [url],
        };
        if (server.username != null && server.username!.isNotEmpty) {
          entry['username'] = server.username;
        }
        if (server.credential != null && server.credential!.isNotEmpty) {
          entry['credential'] = server.credential;
        }
        expanded.add(entry);
      }
    }

    final hasTurn = expanded.any(
      (e) =>
          (e['url'] as String? ?? '').startsWith('turn:') ||
          (e['url'] as String? ?? '').startsWith('turns:'),
    );

    if (!hasTurn) {
      debugPrint('[WebRTC] No TURN server found in list. Injecting default Coturn fallback.');
      for (final url in [
        'turn:34.40.33.208:3478?transport=udp',
        'turn:34.40.33.208:3478?transport=tcp',
      ]) {
        expanded.add({
          'url': url,
          'urls': [url],
          'username': 'keepsims',
          'credential': 'keepsims_turn_secret_2026_prod',
        });
      }
    }

    return expanded;
  }

  /// Initialize WebRTC PeerConnection with ICE servers (STUN + TURN)
  Future<void> initialize({required List<IceServerModel> iceServers}) async {
    _lastIceServers = iceServers;
    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
      } catch (_) {}
      _peerConnection = null;
    }

    _pendingIceCandidates.clear();
    _appliedCandidates.clear();
    _hasRemoteDescription = false;
    _lastLocalDescription = null;

    final expandedServers = _buildExpandedIceServers(iceServers);
    debugPrint('[WebRTC] Initializing with ${expandedServers.length} ICE server endpoints:');
    for (final s in expandedServers) {
      debugPrint('[WebRTC]   endpoint: ${s['url']} (user: ${s['username'] ?? 'none'})');
    }

    final configuration = <String, dynamic>{
      'iceServers': expandedServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final peerConstraints = <String, dynamic>{
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(
      configuration,
      peerConstraints,
    );

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        final cand = candidate.candidate!;
        if (cand.contains('typ relay')) {
          debugPrint('[WebRTC] *** RELAY candidate gathered: $cand');
        } else if (cand.contains('typ srflx')) {
          debugPrint('[WebRTC] SRFLX candidate gathered: $cand');
        }
        onLocalIceCandidate?.call(candidate);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state changed: $state');
      onConnectionStateChanged?.call(state);
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state changed: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onIceConnected?.call();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        debugPrint('[WebRTC] Received remote audio track');
        _remoteStream = event.streams.isNotEmpty ? event.streams.first : null;
        onRemoteAudioConnected?.call();
      }
    };
  }

  /// Dynamically update ICE servers (e.g. on ICE restart or credential refresh)
  Future<void> setIceServers(List<IceServerModel> iceServers) async {
    if (_peerConnection == null) return;
    try {
      final expandedServers = _buildExpandedIceServers(iceServers);
      final config = <String, dynamic>{
        'iceServers': expandedServers,
      };
      await _peerConnection!.setConfiguration(config);
      debugPrint('[WebRTC] Successfully updated ICE servers (${expandedServers.length} endpoints)');
    } catch (e) {
      debugPrint('[WebRTC] Error setting ICE servers: $e');
    }
  }

  /// Acquire microphone audio stream with structured hardware/software voice constraints
  Future<void> openMicrophone() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'mandatory': {
          'googEchoCancellation': 'true',
          'googAutoGainControl': 'true',
          'googNoiseSuppression': 'true',
          'googHighpassFilter': 'true',
          'echoCancellation': 'true',
          'autoGainControl': 'true',
          'noiseSuppression': 'true',
        },
        'optional': [],
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
  }

  /// Create WebRTC SDP Offer (Caller) with Opus voice optimization
  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    final offerConstraints = <String, dynamic>{
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
        if (iceRestart) 'IceRestart': true,
      },
      'optional': [
        if (iceRestart) {'IceRestart': true},
      ],
    };

    final rawOffer = await _peerConnection!.createOffer(offerConstraints);
    final optimizedSdp = OpusSdpTransformer.optimizeOpusVoiceProfile(rawOffer.sdp!);
    final description = RTCSessionDescription(optimizedSdp, rawOffer.type);

    await _peerConnection!.setLocalDescription(description);
    _lastLocalDescription = description;
    await _tuneSenderAudioParameters();

    // Bounded wait for candidate gathering so offer contains complete ICE candidates
    await _waitForIceGatheringComplete();
    final fullOffer = await _peerConnection!.getLocalDescription();
    if (fullOffer != null && fullOffer.sdp != null) {
      _lastLocalDescription = fullOffer;
      return fullOffer;
    }
    return description;
  }

  /// Create an ICE restart offer
  Future<RTCSessionDescription> createRestartOffer() async {
    return createOffer(iceRestart: true);
  }

  final List<RTCIceCandidate> _pendingIceCandidates = [];
  final Set<String> _appliedCandidates = {};
  bool _hasRemoteDescription = false;

  /// Set remote Offer and create SDP Answer (Callee) with Opus voice optimization
  Future<RTCSessionDescription> handleOfferAndCreateAnswer(
    String offerSdp,
  ) async {
    if (_peerConnection == null) {
      debugPrint('[WebRTC] PeerConnection was null in handleOfferAndCreateAnswer. Attempting auto-initialization...');
      await initialize(iceServers: _lastIceServers);
      if (_localStream == null) {
        try {
          await openMicrophone();
        } catch (e) {
          debugPrint('[WebRTC] Auto openMicrophone warning: $e');
        }
      } else {
        for (final track in _localStream!.getAudioTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }
    }

    if (_peerConnection == null) {
      throw StateError('Cannot handle offer: PeerConnection is not initialized');
    }

    final remoteDescription = RTCSessionDescription(offerSdp, 'offer');
    await _peerConnection!.setRemoteDescription(remoteDescription);
    _hasRemoteDescription = true;
    await _drainPendingCandidates();

    final answerConstraints = <String, dynamic>{
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
      'optional': [],
    };

    final rawAnswer = await _peerConnection!.createAnswer(answerConstraints);
    final optimizedSdp = OpusSdpTransformer.optimizeOpusVoiceProfile(rawAnswer.sdp!);
    final answer = RTCSessionDescription(optimizedSdp, rawAnswer.type);

    await _peerConnection!.setLocalDescription(answer);
    _lastLocalDescription = answer;
    await _tuneSenderAudioParameters();

    // Bounded wait for candidate gathering so answer contains complete ICE candidates
    await _waitForIceGatheringComplete();
    final fullAnswer = await _peerConnection!.getLocalDescription();
    if (fullAnswer != null && fullAnswer.sdp != null) {
      _lastLocalDescription = fullAnswer;
      return fullAnswer;
    }
    return answer;
  }

  /// Set remote Answer on Caller once Callee responds
  Future<void> setRemoteAnswer(String answerSdp) async {
    if (_peerConnection == null) return;
    final remoteDescription = RTCSessionDescription(answerSdp, 'answer');
    await _peerConnection!.setRemoteDescription(remoteDescription);
    _hasRemoteDescription = true;
    await _drainPendingCandidates();
    await _tuneSenderAudioParameters();
  }

  /// Adjust audio sender parameters for voice optimization
  Future<void> _tuneSenderAudioParameters() async {
    if (_peerConnection == null) return;
    try {
      final senders = await _peerConnection!.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'audio') {
          final params = sender.parameters;
          if (params.encodings != null && params.encodings!.isNotEmpty) {
            for (final encoding in params.encodings!) {
              encoding.maxBitrate = 32000;
            }
            await sender.setParameters(params);
          }
        }
      }
    } catch (e) {
      debugPrint('[WebRTC] Note: could not tune sender parameters: $e');
    }
  }

  /// Bounded wait for WebRTC local ICE gathering to complete
  Future<void> _waitForIceGatheringComplete({
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    if (_peerConnection == null) return;
    try {
      final currentState = await _peerConnection!.getIceGatheringState();
      if (currentState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        return;
      }
    } catch (_) {}

    final completer = Completer<void>();
    Timer? timer;

    final origStateCallback = _peerConnection!.onIceGatheringState;
    _peerConnection!.onIceGatheringState = (state) {
      origStateCallback?.call(state);
      debugPrint('[WebRTC] IceGatheringState: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) {
          timer?.cancel();
          completer.complete();
        }
      }
    };

    final origCandidateCallback = _peerConnection!.onIceCandidate;
    _peerConnection!.onIceCandidate = (candidate) {
      origCandidateCallback?.call(candidate);
      final cand = candidate.candidate ?? '';
      if (cand.contains('typ relay')) {
        debugPrint('[WebRTC] Relay candidate captured during gathering window');
        Timer(const Duration(milliseconds: 300), () {
          if (!completer.isCompleted) {
            timer?.cancel();
            completer.complete();
          }
        });
      }
    };

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('[WebRTC] Ice gathering window reached (${timeout.inMilliseconds}ms)');
        completer.complete();
      }
    });

    try {
      await completer.future;
    } catch (_) {}
  }

  /// Add received remote ICE candidate (buffered if remote description not yet set)
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    final cand = candidate.candidate ?? '';
    if (cand.isEmpty || _appliedCandidates.contains(cand)) {
      return;
    }

    if (!_hasRemoteDescription) {
      debugPrint('[WebRTC] Buffering candidate until remote description is set');
      _pendingIceCandidates.add(candidate);
      return;
    }

    _appliedCandidates.add(cand);
    try {
      debugPrint('[WebRTC] Applying remote ICE candidate: $cand');
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      debugPrint('[WebRTC] Error adding candidate ($cand): $e');
    }
  }

  Future<void> _drainPendingCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;
    final toDrain = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    debugPrint('[WebRTC] Draining ${toDrain.length} buffered ICE candidates');
    for (final candidate in toDrain) {
      final cand = candidate.candidate ?? '';
      if (cand.isNotEmpty && !_appliedCandidates.contains(cand)) {
        _appliedCandidates.add(cand);
        try {
          await _peerConnection?.addCandidate(candidate);
        } catch (e) {
          debugPrint('[WebRTC] Error applying buffered candidate: $e');
        }
      }
    }
  }

  /// Send in-band DTMF tone over WebRTC audio track
  Future<void> insertDtmf(String tone) async {
    if (_peerConnection == null || _localStream == null) return;
    try {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final dtmfSender = _peerConnection!.createDtmfSender(audioTracks.first);
        await dtmfSender.insertDTMF(tone);
      }
    } catch (e) {
      debugPrint('[WebRTC] Error sending DTMF: $e');
    }
  }

  /// Toggle microphone mute
  void setMuted(bool muted) {
    _isMuted = muted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    }
  }

  /// Dispose and release all media resources
  Future<void> dispose() async {
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            await track.stop();
          } catch (_) {}
        }
        try {
          await _localStream!.dispose();
        } catch (_) {}
        _localStream = null;
      }

      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          try {
            await track.stop();
          } catch (_) {}
        }
        try {
          await _remoteStream!.dispose();
        } catch (_) {}
        _remoteStream = null;
      }

      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
        } catch (_) {}
        try {
          await _peerConnection!.dispose();
        } catch (_) {}
        _peerConnection = null;
      }

      _pendingIceCandidates.clear();
      _appliedCandidates.clear();
      _hasRemoteDescription = false;
    } catch (e) {
      debugPrint('[WebRTC] Dispose error: $e');
    }
  }
}
