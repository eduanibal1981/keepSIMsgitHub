/// KeepSIMs — WebRTC Audio Media Service
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';

class WebRTCAudioService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  void Function(RTCIceCandidate candidate)? onLocalIceCandidate;
  void Function(RTCPeerConnectionState state)? onConnectionStateChanged;
  void Function()? onRemoteAudioConnected;
  void Function(String error)? onError;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  /// Initialize WebRTC PeerConnection with ICE servers (STUN + TURN)
  Future<void> initialize({required List<IceServerModel> iceServers}) async {
    final configuration = <String, dynamic>{
      'iceServers': iceServers.map((s) => s.toMap()).toList(),
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
        onLocalIceCandidate?.call(candidate);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state changed: $state');
      onConnectionStateChanged?.call(state);
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        debugPrint('[WebRTC] Received remote audio track');
        _remoteStream = event.streams.isNotEmpty ? event.streams.first : null;
        onRemoteAudioConnected?.call();
      }
    };
  }

  /// Acquire microphone audio stream with noise suppression and echo cancellation
  Future<void> openMicrophone() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'highpassFilter': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection?.addTrack(track, _localStream!);
    }
  }

  /// Create WebRTC SDP Offer (Caller)
  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    final offerConstraints = <String, dynamic>{
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
      'optional': [],
    };

    final description = await _peerConnection!.createOffer(offerConstraints);
    await _peerConnection!.setLocalDescription(description);
    return description;
  }

  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _hasRemoteDescription = false;

  /// Set remote Offer and create SDP Answer (Callee)
  Future<RTCSessionDescription> handleOfferAndCreateAnswer(
    String offerSdp,
  ) async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    final remoteDescription = RTCSessionDescription(offerSdp, 'offer');
    await _peerConnection!.setRemoteDescription(remoteDescription);
    _hasRemoteDescription = true;
    await _drainPendingCandidates();

    final answerConstraints = <String, dynamic>{
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
      'optional': [],
    };

    final answer = await _peerConnection!.createAnswer(answerConstraints);
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  /// Set remote Answer on Caller once Callee responds
  Future<void> setRemoteAnswer(String answerSdp) async {
    if (_peerConnection == null) return;
    final remoteDescription = RTCSessionDescription(answerSdp, 'answer');
    await _peerConnection!.setRemoteDescription(remoteDescription);
    _hasRemoteDescription = true;
    await _drainPendingCandidates();
  }

  /// Add received remote ICE candidate (buffered if remote description not yet set)
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    if (!_hasRemoteDescription) {
      debugPrint('[WebRTC] Buffering candidate until remote description is set');
      _pendingIceCandidates.add(candidate);
      return;
    }
    try {
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      debugPrint('[WebRTC] Error adding candidate: $e');
    }
  }

  Future<void> _drainPendingCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;
    debugPrint('[WebRTC] Draining ${_pendingIceCandidates.length} buffered ICE candidates');
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Error applying buffered candidate: $e');
      }
    }
    _pendingIceCandidates.clear();
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
      _hasRemoteDescription = false;
    } catch (e) {
      debugPrint('[WebRTC] Dispose error: $e');
    }
  }
}
