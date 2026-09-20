/// KeepSIMs — Supabase Realtime VoIP Signaling Service
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/supabase_client.dart';

class VoipSignalingService {
  RealtimeChannel? _channel;
  String? _currentCallId;

  String? get currentCallId => _currentCallId;

  void Function(String sdp)? onSdpOfferReceived;
  void Function(String sdp)? onSdpAnswerReceived;
  void Function(RTCIceCandidate candidate)? onRemoteCandidateReceived;
  void Function()? onCalleeRinging;
  void Function(String reason)? onCallDeclined;
  void Function(String reason)? onCallEnded;
  void Function(bool isMuted)? onPeerMuteChanged;

  /// Connect to the realtime signaling channel for [callId]
  Future<void> connect(String callId) async {
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
          event: 'ice_candidate',
          callback: (payload) {
            final cand = payload['candidate'] as String?;
            final mid = payload['sdpMid'] as String?;
            final mLineIndex = payload['sdpMLineIndex'] as int?;
            if (cand != null) {
              final candidate = RTCIceCandidate(cand, mid, mLineIndex);
              onRemoteCandidateReceived?.call(candidate);
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

    final completer = Completer<void>();
    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) completer.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!completer.isCompleted) {
          completer.completeError(
            error ?? Exception('VoIP signaling channel failed with $status'),
          );
        }
      }
    });

    try {
      await completer.future.timeout(const Duration(seconds: 8));
      debugPrint('[VoIP Signaling] Subscribed to voip_call:$callId');
    } catch (e) {
      debugPrint('[VoIP Signaling] Channel subscription warning: $e');
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

  /// Broadcast local ICE Candidate
  Future<void> sendIceCandidate(RTCIceCandidate candidate) async {
    await _channel?.sendBroadcastMessage(
      event: 'ice_candidate',
      payload: {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    );
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
    if (_channel != null) {
      try {
        await _channel!.unsubscribe();
      } catch (_) {}
      _channel = null;
    }
    _currentCallId = null;
  }
}
