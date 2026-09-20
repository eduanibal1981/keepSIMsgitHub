/// KeepSIMs — VoIP Call Session Model
library;

class VoipCallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final String callType;
  final String status;
  final String? offerSdp;
  final String? answerSdp;
  final String? endReason;
  final DateTime startedAt;
  final DateTime? ringingAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String? callerDeviceId;
  final String? calleeDeviceId;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? peerPhone;
  final bool isOutgoing;

  const VoipCallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    this.callType = 'voice',
    this.status = 'initiating',
    this.offerSdp,
    this.answerSdp,
    this.endReason,
    required this.startedAt,
    this.ringingAt,
    this.connectedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.callerDeviceId,
    this.calleeDeviceId,
    this.peerName,
    this.peerAvatarUrl,
    this.peerPhone,
    this.isOutgoing = false,
  });

  bool get isTerminal {
    final s = status.toLowerCase();
    return s == 'completed' ||
        s == 'declined' ||
        s == 'busy' ||
        s == 'missed' ||
        s == 'failed' ||
        s == 'timeout';
  }

  factory VoipCallSession.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final caller = json['caller_id'] as String? ?? '';
    final isOut =
        json['is_outgoing'] as bool? ??
        (currentUserId != null && caller == currentUserId);

    DateTime? parseDt(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return VoipCallSession(
      id: json['id'] as String,
      callerId: caller,
      calleeId: json['callee_id'] as String? ?? '',
      callType: json['call_type'] as String? ?? 'voice',
      status: json['status'] as String? ?? 'initiating',
      offerSdp: json['offer_sdp'] as String?,
      answerSdp: json['answer_sdp'] as String?,
      endReason: json['end_reason'] as String?,
      startedAt: parseDt(json['started_at']) ?? DateTime.now(),
      ringingAt: parseDt(json['ringing_at']),
      connectedAt: parseDt(json['connected_at']),
      endedAt: parseDt(json['ended_at']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      callerDeviceId: json['caller_device_id'] as String?,
      calleeDeviceId: json['callee_device_id'] as String?,
      peerName: json['peer_name'] as String?,
      peerAvatarUrl: json['peer_avatar_url'] as String?,
      peerPhone: json['peer_phone'] as String?,
      isOutgoing: isOut,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'call_type': callType,
      'status': status,
      'offer_sdp': offerSdp,
      'answer_sdp': answerSdp,
      'end_reason': endReason,
      'started_at': startedAt.toIso8601String(),
      'ringing_at': ringingAt?.toIso8601String(),
      'connected_at': connectedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'caller_device_id': callerDeviceId,
      'callee_device_id': calleeDeviceId,
    };
  }
}
