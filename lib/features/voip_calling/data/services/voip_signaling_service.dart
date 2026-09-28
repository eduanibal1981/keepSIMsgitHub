/// KeepSIMs — Supabase Realtime VoIP Signaling Service
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';

enum SignalingSubscriptionResult {
  subscribed,
  channelError,
  timedOut,
}

class VoipSignalingService {
  RealtimeChannel? _channel;
  String? _currentCallId;
  bool _isSubscribed = false;
  final List<Map<String, dynamic>> _pendingLocalCandidates = [];

  String? get currentCallId => _currentCallId;
  bool get isSubscribed => _isSubscribed;

  void Function(String sdp)? onSdpOfferReceived;
  void Function(String sdp)? onSdpAnswerReceived;
  void Function(String sdp, int generation)? onIceRestartOfferReceived;
  void Function(String sdp, int generation)? onIceRestartAnswerReceived;
  void Function(RTCIceCandidate candidate, int generation)? onRemoteCandidateReceived;
  void Function()? onCalleeRinging;
  void Function()? onCalleeReady;
  void Function(String reason)? onCallDeclined;
  void Function(String reason)? onCallEnded;
  void Function(bool isMuted)? onPeerMuteChanged;

  /// Connect to the realtime signaling channel for [callId]
  Future<SignalingSubscriptionResult> connect(String callId) async {
    await disconnect();
    _currentCallId = callId;

    _channel = supabase.channel('voip_call:$callId');

    _channel!
        .onBroadcast(
          event: 'sdp_offer',
          callback: (payload) {
            final sdp = payload['sdp'] as String?;
            if (sdp != null) onSdpOfferReceived?.call(sdp);
          },
        )
        .onBroadcast(
          event: 'sdp_answer',
          callback: (payload) {
            final sdp = payload['sdp'] as String?;
            if (sdp != null) onSdpAnswerReceived?.call(sdp);
          },
        )
        .onBroadcast(
          event: 'ice_restart_offer',
          callback: (payload) {
            final sdp = payload['sdp'] as String?;
            final gen = payload['generation'] as int? ?? 1;
            if (sdp != null) onIceRestartOfferReceived?.call(sdp, gen);
          },
        )
        .onBroadcast(
          event: 'ice_restart_answer',
          callback: (payload) {
            final sdp = payload['sdp'] as String?;
            final gen = payload['generation'] as int? ?? 1;
            if (sdp != null) onIceRestartAnswerReceived?.call(sdp, gen);
          },
        )
        .onBroadcast(
          event: 'ice_candidate',
          callback: (payload) {
            final cand = payload['candidate'] as String?;
            final mid = payload['sdpMid'] as String?;
            final mLineIndex = payload['sdpMLineIndex'] as int?;
            final gen = payload['generation'] as int? ?? 0;
            if (cand != null) {
              final candidate = RTCIceCandidate(cand, mid, mLineIndex);
              onRemoteCandidateReceived?.call(candidate, gen);
            }
          },
        )
        .onBroadcast(
          event: 'callee_ringing',
          callback: (_) {
            onCalleeRinging?.call();
          },
        )
        .onBroadcast(
          event: 'callee_ready',
          callback: (_) {
            onCalleeReady?.call();
          },
        )
        .onBroadcast(
          event: 'call_declined',
          callback: (payload) {
            final reason = payload['reason'] as String? ?? 'declined';
            onCallDeclined?.call(reason);
          },
        )
        .onBroadcast(
          event: 'call_ended',
          callback: (payload) {
            final reason = payload['reason'] as String? ?? 'ended';
            onCallEnded?.call(reason);
          },
        )
        .onBroadcast(
          event: 'mic_muted',
          callback: (payload) {
            final isMuted = payload['is_muted'] as bool? ?? false;
            onPeerMuteChanged?.call(isMuted);
          },
        );

    final completer = Completer<SignalingSubscriptionResult>();
    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSubscribed = true;
        _drainPendingLocalCandidates();
        if (!completer.isCompleted) completer.complete(SignalingSubscriptionResult.subscribed);
      } else if (status == RealtimeSubscribeStatus.channelError) {
        _isSubscribed = false;
        if (!completer.isCompleted) completer.complete(SignalingSubscriptionResult.channelError);
      } else if (status == RealtimeSubscribeStatus.timedOut) {
        _isSubscribed = false;
        if (!completer.isCompleted) completer.complete(SignalingSubscriptionResult.timedOut);
      }
    });

    try {
      final res = await completer.future.timeout(const Duration(seconds: 8));
      debugPrint('[VoIP Signaling] Subscribed to voip_call:$callId ($res)');
      return res;
    } catch (e) {
      debugPrint('[VoIP Signaling] Channel subscription timed out after 8s: $e');
      _isSubscribed = false;
      return SignalingSubscriptionResult.timedOut;
    }
  }

  /// Broadcast SDP Offer
  Future<void> sendOffer(String sdp) async {
    await _channel?.sendBroadcastMessage(
      event: 'sdp_offer',
      payload: {'sdp': sdp},
    );
  }

  /// Broadcast SDP Answer
  Future<void> sendAnswer(String sdp) async {
    await _channel?.sendBroadcastMessage(
      event: 'sdp_answer',
      payload: {'sdp': sdp},
    );
  }

  /// Broadcast Callee Ready signal to prompt caller to send/resend offer
  Future<void> sendCalleeReady() async {
    await _channel?.sendBroadcastMessage(
      event: 'callee_ready',
      payload: {'ready': true},
    );
  }

  /// Broadcast ICE restart SDP Offer with generation tag
  Future<void> sendIceRestartOffer(String sdp, int generation) async {
    await _channel?.sendBroadcastMessage(
      event: 'ice_restart_offer',
      payload: {'sdp': sdp, 'generation': generation},
    );
  }

  /// Broadcast ICE restart SDP Answer with generation tag
  Future<void> sendIceRestartAnswer(String sdp, int generation) async {
    await _channel?.sendBroadcastMessage(
      event: 'ice_restart_answer',
      payload: {'sdp': sdp, 'generation': generation},
    );
  }

  /// Broadcast local ICE Candidate (buffered if channel not yet subscribed)
  Future<void> sendIceCandidate(RTCIceCandidate candidate, [int generation = 0]) async {
    final payload = {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'generation': generation,
    };

    if (!_isSubscribed || _channel == null) {
      debugPrint('[VoIP Signaling] Buffering local candidate until channel subscribed');
      _pendingLocalCandidates.add(payload);
      return;
    }

    try {
      await _channel?.sendBroadcastMessage(
        event: 'ice_candidate',
        payload: payload,
      );
    } catch (e) {
      debugPrint('[VoIP Signaling] Error broadcasting local candidate: $e');
    }
  }

  void _drainPendingLocalCandidates() {
    if (_pendingLocalCandidates.isEmpty || _channel == null) return;
    final toDrain = List<Map<String, dynamic>>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    debugPrint('[VoIP Signaling] Flushing ${toDrain.length} buffered local candidates');
    for (final payload in toDrain) {
      _channel?.sendBroadcastMessage(
        event: 'ice_candidate',
        payload: payload,
      );
    }
  }

  /// Callee notifies caller that device is ringing
  Future<void> sendRinging() async {
    await _channel?.sendBroadcastMessage(event: 'callee_ringing', payload: {});
  }

  /// Callee declined call
  Future<void> sendDeclined({String reason = 'declined'}) async {
    await _channel?.sendBroadcastMessage(
      event: 'call_declined',
      payload: {'reason': reason},
    );
  }

  /// Hang up / ended
  Future<void> sendEnded({String reason = 'ended'}) async {
    await _channel?.sendBroadcastMessage(
      event: 'call_ended',
      payload: {'reason': reason},
    );
  }

  /// Mute status update
  Future<void> sendMuteStatus(bool isMuted) async {
    await _channel?.sendBroadcastMessage(
      event: 'mic_muted',
      payload: {'is_muted': isMuted},
    );
  }

  /// Disconnect signaling channel
  Future<void> disconnect() async {
    _isSubscribed = false;
    _pendingLocalCandidates.clear();
    if (_channel != null) {
      try {
        await _channel!.unsubscribe();
      } catch (_) {}
      _channel = null;
    }
    _currentCallId = null;
  }
}
