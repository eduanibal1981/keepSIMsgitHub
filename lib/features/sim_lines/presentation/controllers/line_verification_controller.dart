import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/datasources/telnyx_verification_service.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/line_verification_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

part 'line_verification_controller.g.dart';

@riverpod
class LineVerificationController extends _$LineVerificationController {
  Timer? _pollingTimer;
  int _secondsElapsed = 0;
  static const int _maxPollSeconds = 15;
  static const int _maxSmsPollSeconds = 24;

  @override
  LineVerificationState build(String simLineId) {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return const LineVerificationState.idle();
  }

  /// Triggers a phone verification via Twilio Missed Call.
  Future<void> startVerification(String phoneNumber) async {
    if (state.status == LineVerificationStatus.triggering ||
        state.status == LineVerificationStatus.ringing ||
        state.status == LineVerificationStatus.sendingSms ||
        state.status == LineVerificationStatus.awaitingDlr) {
      return;
    }

    state = const LineVerificationState.triggering();

    final repo = ref.read(simLinesRepositoryProvider);
    final callSid = await repo.triggerMissedCall(phoneNumber);

    if (callSid == null) {
      state = const LineVerificationState.failure(
        'Failed to connect with Twilio networks. Please check your phone number configuration and try again.',
        channel: 'twilio_missed_call',
      );
      return;
    }

    state = LineVerificationState.ringing(callSid);
    _startCallPolling(callSid);
  }

  /// Start polling the status of the call.
  void _startCallPolling(String callSid) {
    _pollingTimer?.cancel();
    _secondsElapsed = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _secondsElapsed++;

      if (_secondsElapsed > _maxPollSeconds) {
        timer.cancel();
        state = const LineVerificationState.failure(
          'Verification timed out. No response received from the phone line. Please ensure your SIM card is inserted and active.',
          channel: 'twilio_missed_call',
        );
        return;
      }

      final repo = ref.read(simLinesRepositoryProvider);
      final isCallActive = await repo.checkCallStatus(callSid);

      if (isCallActive) {
        timer.cancel();

        // Wait 2 seconds to let the phone ring once/twice
        await Future.delayed(const Duration(seconds: 2));

        // Cancel the call to stop ringing immediately
        await repo.cancelCall(callSid);

        // Successfully verified, confirm and update DB!
        try {
          await repo.confirmLineVerification(
            simLineId,
            channel: 'twilio_missed_call',
          );
          state = const LineVerificationState.success(
            channel: 'twilio_missed_call',
          );

          // Refresh the sim lines list in background
          ref.invalidate(simLinesControllerProvider);
        } catch (e) {
          state = LineVerificationState.failure(
            e.toString(),
            channel: 'twilio_missed_call',
          );
        }
      }
    });
  }

  /// Triggers a silent verification ping via Telnyx SMS (verifySMS0).
  Future<void> startSmsVerification(String phoneNumber) async {
    if (state.status == LineVerificationStatus.triggering ||
        state.status == LineVerificationStatus.ringing ||
        state.status == LineVerificationStatus.sendingSms ||
        state.status == LineVerificationStatus.awaitingDlr) {
      return;
    }

    state = const LineVerificationState.sendingSms();

    final repo = ref.read(simLinesRepositoryProvider);
    final messageId = await repo.triggerSmsVerification(phoneNumber);

    if (messageId == null) {
      state = const LineVerificationState.failure(
        'Failed to dispatch verification SMS via telecom gateway. Please verify the phone number format.',
        channel: 'telnyx_sms_dlr',
      );
      return;
    }

    state = LineVerificationState.awaitingDlr(messageId);
    _startSmsPolling(messageId);
  }

  /// Start polling the Delivery Receipt (DLR) status of the sent SMS.
  void _startSmsPolling(String messageId) {
    _pollingTimer?.cancel();
    _secondsElapsed = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _secondsElapsed += 2;

      final repo = ref.read(simLinesRepositoryProvider);
      final result = await repo.checkSmsDeliveryStatus(messageId);

      // If carrier delivery or network dispatch is confirmed
      if (result.status == TelnyxSmsDeliveryStatus.delivered ||
          (result.status == TelnyxSmsDeliveryStatus.sent && _secondsElapsed >= 4)) {
        timer.cancel();

        try {
          await repo.confirmLineVerification(
            simLineId,
            channel: 'telnyx_sms_dlr',
            carrierName: result.carrierName,
          );

          state = LineVerificationState.success(
            channel: 'telnyx_sms_dlr',
            carrier: result.carrierName,
          );

          ref.invalidate(simLinesControllerProvider);
        } catch (e) {
          state = LineVerificationState.failure(
            e.toString(),
            channel: 'telnyx_sms_dlr',
          );
        }
        return;
      }

      if (result.status == TelnyxSmsDeliveryStatus.failed ||
          result.status == TelnyxSmsDeliveryStatus.undelivered) {
        timer.cancel();
        state = const LineVerificationState.failure(
          'SMS delivery failed. The destination carrier indicated this SIM line is unprovisioned, off, or disconnected.',
          channel: 'telnyx_sms_dlr',
        );
        return;
      }

      if (_secondsElapsed > _maxSmsPollSeconds) {
        timer.cancel();
        state = const LineVerificationState.failure(
          'SMS delivery receipt timed out. Please ensure the SIM card is powered on and within network coverage.',
          channel: 'telnyx_sms_dlr',
        );
      }
    });
  }

  /// Resets the controller back to idle.
  void reset() {
    _pollingTimer?.cancel();
    state = const LineVerificationState.idle();
  }
}
