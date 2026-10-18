import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/line_verification_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

part 'line_verification_controller.g.dart';

@Riverpod(keepAlive: true)
class LineVerificationController extends _$LineVerificationController {
  Timer? _pollingTimer;
  int _secondsElapsed = 0;
  static const int _maxPollSeconds = 45;

  @override
  LineVerificationState build(String simLineId) {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    // Auto-load live verification quote on mount
    Future.microtask(() => loadQuote());
    return const LineVerificationState.loadingQuote();
  }

  /// Fetches real-time pricing and plan allowances from the backend.
  Future<void> loadQuote() async {
    state = state.copyWith(
      status: LineVerificationStatus.loadingQuote,
      errorMessage: null,
    );

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final quote = await repo.quoteLineVerification(simLineId);

      // If there is already an in-flight check running for this line, resume monitoring it!
      if (quote.inFlightAttemptId != null &&
          quote.inFlightAttemptId!.isNotEmpty) {
        final attemptId = quote.inFlightAttemptId!;
        state = LineVerificationState.awaitingDlr(
          attemptId,
          attemptId: attemptId,
          quote: quote,
        );
        _startAttemptPolling(attemptId, 'sms');
        return;
      }

      state = LineVerificationState.quoteReady(quote);
    } catch (e) {
      state = LineVerificationState.failure(
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Triggers a verification check via backend Edge Function.
  /// Method: 'sms' (Silent SMS verifySMS0) or 'missed_call' (Twilio voice ring).
  Future<void> startVerification(String method) async {
    if (state.status == LineVerificationStatus.triggering ||
        state.status == LineVerificationStatus.ringing ||
        state.status == LineVerificationStatus.sendingSms ||
        state.status == LineVerificationStatus.awaitingDlr) {
      return;
    }

    final normalizedMethod = (method == 'voice' || method == 'missed_call')
        ? 'voice'
        : 'sms';
    final quote = state.quote;
    final channel = normalizedMethod == 'sms'
        ? 'telnyx_sms_dlr'
        : 'telnyx_missed_call';

    state = LineVerificationState.triggering(channel: channel, quote: quote);

    try {
      final repo = ref.read(simLinesRepositoryProvider);
      final result = await repo.startLineVerification(
        simLineId: simLineId,
        method: normalizedMethod,
      );

      final attemptId = result['attemptId'] as String?;
      final providerSid = result['providerSid'] as String? ?? attemptId ?? '';

      if (attemptId == null) {
        state = LineVerificationState.failure(
          'Failed to initialize telecom verification session.',
          channel: channel,
          quote: quote,
        );
        return;
      }

      if (normalizedMethod == 'sms') {
        state = LineVerificationState.awaitingDlr(
          providerSid,
          attemptId: attemptId,
          quote: quote,
        );
      } else {
        state = LineVerificationState.ringing(
          providerSid,
          attemptId: attemptId,
          quote: quote,
        );
      }

      _startAttemptPolling(attemptId, normalizedMethod);
    } catch (e) {
      state = LineVerificationState.failure(
        e.toString().replaceAll('Exception: ', ''),
        channel: channel,
        quote: quote,
      );
    }
  }

  /// Polls the database/edge function for the final carrier delivery receipt / ring callback.
  void _startAttemptPolling(String attemptId, String method) {
    _pollingTimer?.cancel();
    _secondsElapsed = 0;

    final channel = method == 'sms' ? 'telnyx_sms_dlr' : 'telnyx_missed_call';

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _secondsElapsed += 2;

      final repo = ref.read(simLinesRepositoryProvider);
      try {
        final result = await repo.getLineVerificationAttemptStatus(attemptId);
        final status = result['status'] as String?;
        final outcome = result['outcome'] as String? ?? status;
        final carrier =
            result['carrierName'] as String? ??
            result['carrier_name'] as String? ??
            result['carrier'] as String?;

        if (status == 'terminal' && result['isSuccess'] == true) {
          timer.cancel();

          state = LineVerificationState.success(
            channel: channel,
            carrier: carrier,
            quote: state.quote,
            attemptId: attemptId,
          );

          // Invalidate SIM line controllers to reflect new verification timestamp and health score
          ref.invalidate(simLinesControllerProvider);
          ref.invalidate(hasRealLiveVerificationProvider(simLineId));
          ref.invalidate(simLineActivityLogsProvider(simLineId));
          return;
        }

        if (outcome == 'failed' ||
            status == 'failed' ||
            status == 'timed_out' ||
            outcome == 'inconclusive') {
          timer.cancel();

          final errorMsg =
              result['errorMessage'] as String? ??
              result['error_message'] as String? ??
              (method == 'sms'
                  ? 'SMS delivery failed. The destination carrier indicated this SIM line is unprovisioned, off, or disconnected.'
                  : 'Verification call failed. The line did not ring or was unavailable on the cellular network.');

          state = LineVerificationState.failure(
            errorMsg,
            channel: channel,
            quote: state.quote,
            attemptId: attemptId,
          );
          return;
        }

        if (_secondsElapsed >= _maxPollSeconds) {
          timer.cancel();

          state = LineVerificationState.failure(
            method == 'sms'
                ? 'SMS delivery receipt timed out. Please ensure the SIM card is powered on and within network coverage.'
                : 'Call verification timed out. No network ring was detected within the timeout window.',
            channel: channel,
            quote: state.quote,
            attemptId: attemptId,
          );
        }
      } catch (e) {
        if (_secondsElapsed >= _maxPollSeconds) {
          timer.cancel();
          state = LineVerificationState.failure(
            'Verification tracking error: $e',
            channel: channel,
            quote: state.quote,
            attemptId: attemptId,
          );
        }
      }
    });
  }

  /// Backwards compatibility methods
  Future<void> startSmsVerification([String? _]) => startVerification('sms');
  Future<void> startMissedCallVerification([String? _]) =>
      startVerification('voice');

  /// Resets the controller and reloads quote.
  void reset() {
    _pollingTimer?.cancel();
    loadQuote();
  }
}
