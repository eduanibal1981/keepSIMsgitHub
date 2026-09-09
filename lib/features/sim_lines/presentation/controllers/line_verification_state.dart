import 'package:keep_sims/features/sim_lines/data/models/line_verification_quote_model.dart';

enum LineVerificationStatus {
  idle,
  loadingQuote,
  quoteReady,
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
  final String? attemptId;
  final String? carrierName;
  final String? verificationChannel;
  final LineVerificationQuote? quote;

  const LineVerificationState({
    required this.status,
    this.errorMessage,
    this.callSid,
    this.messageId,
    this.attemptId,
    this.carrierName,
    this.verificationChannel,
    this.quote,
  });

  const LineVerificationState.idle()
      : status = LineVerificationStatus.idle,
        errorMessage = null,
        callSid = null,
        messageId = null,
        attemptId = null,
        carrierName = null,
        verificationChannel = null,
        quote = null;

  const LineVerificationState.loadingQuote()
      : status = LineVerificationStatus.loadingQuote,
        errorMessage = null,
        callSid = null,
        messageId = null,
        attemptId = null,
        carrierName = null,
        verificationChannel = null,
        quote = null;

  const LineVerificationState.quoteReady(LineVerificationQuote q)
      : status = LineVerificationStatus.quoteReady,
        errorMessage = null,
        callSid = null,
        messageId = null,
        attemptId = null,
        carrierName = null,
        verificationChannel = null,
        quote = q;

  const LineVerificationState.triggering({
    String? channel,
    this.quote,
  })  : status = LineVerificationStatus.triggering,
        errorMessage = null,
        callSid = null,
        messageId = null,
        attemptId = null,
        carrierName = null,
        verificationChannel = channel ?? 'twilio_missed_call';

  const LineVerificationState.ringing(
    String sid, {
    this.attemptId,
    this.quote,
  })  : status = LineVerificationStatus.ringing,
        errorMessage = null,
        callSid = sid,
        messageId = null,
        carrierName = null,
        verificationChannel = 'twilio_missed_call';

  const LineVerificationState.sendingSms({
    this.quote,
  })  : status = LineVerificationStatus.sendingSms,
        errorMessage = null,
        callSid = null,
        messageId = null,
        attemptId = null,
        carrierName = null,
        verificationChannel = 'telnyx_sms_dlr';

  const LineVerificationState.awaitingDlr(
    String msgId, {
    String? carrier,
    this.attemptId,
    this.quote,
  })  : status = LineVerificationStatus.awaitingDlr,
        errorMessage = null,
        callSid = null,
        messageId = msgId,
        carrierName = carrier,
        verificationChannel = 'telnyx_sms_dlr';

  const LineVerificationState.success({
    String? channel,
    String? carrier,
    this.attemptId,
    this.quote,
  })  : status = LineVerificationStatus.success,
        errorMessage = null,
        callSid = null,
        messageId = null,
        carrierName = carrier,
        verificationChannel = channel;

  const LineVerificationState.failure(
    String message, {
    String? channel,
    this.attemptId,
    this.quote,
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
    String? attemptId,
    String? carrierName,
    String? verificationChannel,
    LineVerificationQuote? quote,
  }) {
    return LineVerificationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      callSid: callSid ?? this.callSid,
      messageId: messageId ?? this.messageId,
      attemptId: attemptId ?? this.attemptId,
      carrierName: carrierName ?? this.carrierName,
      verificationChannel: verificationChannel ?? this.verificationChannel,
      quote: quote ?? this.quote,
    );
  }
}
