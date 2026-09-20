/// KeepSIMs — Call Record Model
library;

class CallRecord {
  final String id;
  final String userId;
  final String? simLineId;
  final String callType;
  final String callerNumber;
  final String destinationNumber;
  final String? destinationCountryCode;
  final String? destinationCountryName;
  final String status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int billedDurationSeconds;
  final double ratePerMinute;
  final double totalCost;
  final String? walletTxnId;
  final String? errorMessage;
  final int? sipHangupCause;
  final String? telnyxHangupCause;
  final String? hangupSource;
  final String? requestedCallerId;
  final String? effectiveCallerId;
  final String? callerIdType;
  final String? policyReason;

  const CallRecord({
    required this.id,
    required this.userId,
    this.simLineId,
    this.callType = 'outbound_direct',
    required this.callerNumber,
    required this.destinationNumber,
    this.destinationCountryCode,
    this.destinationCountryName,
    this.status = 'initiated',
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.billedDurationSeconds = 0,
    required this.ratePerMinute,
    this.totalCost = 0.0,
    this.walletTxnId,
    this.errorMessage,
    this.sipHangupCause,
    this.telnyxHangupCause,
    this.hangupSource,
    this.requestedCallerId,
    this.effectiveCallerId,
    this.callerIdType,
    this.policyReason,
  });

  String get flagEmoji {
    final country = (destinationCountryCode ?? '').toUpperCase();
    if (country.length != 2) return '🌐';
    final int first = country.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = country.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get isTerminal {
    final s = status.toLowerCase();
    return s == 'completed' ||
        s == 'declined' ||
        s == 'busy' ||
        s == 'no_answer' ||
        s == 'cancelled' ||
        s == 'failed' ||
        s == 'ended';
  }

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      simLineId: json['sim_line_id'] as String?,
      callType: json['call_type'] as String? ?? 'outbound_direct',
      callerNumber: json['caller_number'] as String? ?? '',
      destinationNumber: json['destination_number'] as String? ?? '',
      destinationCountryCode: json['destination_country_code'] as String?,
      destinationCountryName: json['destination_country_name'] as String?,
      status: json['status'] as String? ?? 'initiated',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      billedDurationSeconds: json['billed_duration_seconds'] as int? ?? 0,
      ratePerMinute: (json['rate_per_minute_usd'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost_usd'] as num?)?.toDouble() ?? 0.0,
      walletTxnId: json['wallet_txn_id'] as String?,
      errorMessage: json['error_message'] as String?,
      sipHangupCause: json['sip_hangup_cause'] as int?,
      telnyxHangupCause: json['telnyx_hangup_cause'] as String?,
      hangupSource: json['hangup_source'] as String?,
      requestedCallerId: json['requested_caller_id'] as String?,
      effectiveCallerId: json['effective_caller_id'] as String?,
      callerIdType: json['caller_id_type'] as String?,
      policyReason: json['policy_reason'] as String?,
    );
  }
}
