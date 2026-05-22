enum LineVerificationStatus { idle, triggering, ringing, success, failure }

class LineVerificationState {
  final LineVerificationStatus status;
  final String? errorMessage;
  final String? callSid;

  const LineVerificationState({
    required this.status,
    this.errorMessage,
    this.callSid,
  });

  const LineVerificationState.idle()
    : status = LineVerificationStatus.idle,
      errorMessage = null,
      callSid = null;

  const LineVerificationState.triggering()
    : status = LineVerificationStatus.triggering,
      errorMessage = null,
      callSid = null;

  const LineVerificationState.ringing(String sid)
    : status = LineVerificationStatus.ringing,
      errorMessage = null,
      callSid = sid;

  const LineVerificationState.success()
    : status = LineVerificationStatus.success,
      errorMessage = null,
      callSid = null;

  const LineVerificationState.failure(String message)
    : status = LineVerificationStatus.failure,
      errorMessage = message,
      callSid = null;

  LineVerificationState copyWith({
    LineVerificationStatus? status,
    String? errorMessage,
    String? callSid,
  }) {
    return LineVerificationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      callSid: callSid ?? this.callSid,
    );
  }
}
