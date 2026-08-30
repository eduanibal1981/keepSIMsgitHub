enum LineVerificationStatus {
  idle,
  triggering,
  ringing,
  sendingSms,
  awaitingDlr,
  success,
  failure,
}

class LineVerificationState {
  final LineVerificationStatus status;
  final String? errorMessage;
  final String? callSid;
  final String? messageId;
  final String? carrierName;
  final String? verificationChannel;

  const LineVerificationState({
    required this.status,
    this.errorMessage,
    this.callSid,
    this.messageId,
    this.carrierName,
    this.verificationChannel,
  });

  const LineVerificationState.idle()
      : status = LineVerificationStatus.idle,
        errorMessage = null,
        callSid = null,
        messageId = null,
        carrierName = null,
        verificationChannel = null;

  const LineVerificationState.triggering()
      : status = LineVerificationStatus.triggering,
        errorMessage = null,
        callSid = null,
        messageId = null,
        carrierName = null,
        verificationChannel = 'twilio_missed_call';

  const LineVerificationState.ringing(String sid)
      : status = LineVerificationStatus.ringing,
        errorMessage = null,
        callSid = sid,
        messageId = null,
        carrierName = null,
        verificationChannel = 'twilio_missed_call';

  const LineVerificationState.sendingSms()
      : status = LineVerificationStatus.sendingSms,
        errorMessage = null,
        callSid = null,
        messageId = null,
        carrierName = null,
        verificationChannel = 'telnyx_sms_dlr';

  const LineVerificationState.awaitingDlr(String msgId, {String? carrier})
      : status = LineVerificationStatus.awaitingDlr,
        errorMessage = null,
        callSid = null,
        messageId = msgId,
        carrierName = carrier,
        verificationChannel = 'telnyx_sms_dlr';

  const LineVerificationState.success({
    String? channel,
    String? carrier,
  })  : status = LineVerificationStatus.success,
        errorMessage = null,
        callSid = null,
        messageId = null,
        carrierName = carrier,
        verificationChannel = channel;

  const LineVerificationState.failure(
    String message, {
    String? channel,
  })  : status = LineVerificationStatus.failure,
        errorMessage = message,
        callSid = null,
        messageId = null,
        carrierName = null,
        verificationChannel = channel;

  LineVerificationState copyWith({
    LineVerificationStatus? status,
    String? errorMessage,
    String? callSid,
    String? messageId,
    String? carrierName,
    String? verificationChannel,
  }) {
    return LineVerificationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      callSid: callSid ?? this.callSid,
      messageId: messageId ?? this.messageId,
      carrierName: carrierName ?? this.carrierName,
      verificationChannel: verificationChannel ?? this.verificationChannel,
    );
  }
}
