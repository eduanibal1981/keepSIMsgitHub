import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/line_verification_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

part 'line_verification_controller.g.dart';

@riverpod
class LineVerificationController extends _$LineVerificationController {
  Timer? _pollingTimer;
  int _secondsElapsed = 0;
  static const int _maxPollSeconds = 15;

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
        state.status == LineVerificationStatus.ringing) {
      return;
    }

    state = const LineVerificationState.triggering();

    final repo = ref.read(simLinesRepositoryProvider);
    final callSid = await repo.triggerMissedCall(phoneNumber);

    if (callSid == null) {
      state = const LineVerificationState.failure(
        'Failed to connect with Twilio networks. Please check your phone number configuration and try again.',
      );
      return;
    }

    state = LineVerificationState.ringing(callSid);
    _startPolling(callSid);
  }

  /// Start polling the status of the call.
  void _startPolling(String callSid) {
    _pollingTimer?.cancel();
    _secondsElapsed = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _secondsElapsed++;

      if (_secondsElapsed > _maxPollSeconds) {
        timer.cancel();
        state = const LineVerificationState.failure(
          'Verification timed out. No response received from the phone line. Please ensure your SIM card is inserted and active.',
        );
        return;
      }

      final repo = ref.read(simLinesRepositoryProvider);
      final isCallActive = await repo.checkCallStatus(callSid);

      if (isCallActive) {
        timer.cancel();

        // Wait 4 seconds to let the phone ring once/twice so the user sees the missed call notification
        await Future.delayed(const Duration(seconds: 2));

        // Cancel the call to stop ringing immediately and avoid any charges
        await repo.cancelCall(callSid);

        // Successfully verified, confirm and update DB!
        try {
          await repo.confirmLineVerification(simLineId);
          state = const LineVerificationState.success();

          // Refresh the sim lines list in background so UI automatically reflects update!
          ref.invalidate(simLinesControllerProvider);
        } catch (e) {
          state = LineVerificationState.failure(e.toString());
        }
      }
    });
  }

  /// Resets the controller back to idle.
  void reset() {
    _pollingTimer?.cancel();
    state = const LineVerificationState.idle();
  }
}
