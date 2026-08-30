/// KeepSIMs — Calling Controller
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

final callRatesProvider = FutureProvider<List<CallRate>>((ref) async {
  return ref.watch(callingRepositoryProvider).getActiveCallRates();
});

final callHistoryStreamProvider = StreamProvider<List<CallRecord>>((ref) {
  return ref.watch(callingRepositoryProvider).watchUserCallHistory();
});

final userCallerIdsProvider = FutureProvider<List<CallerIdModel>>((ref) async {
  return ref.watch(callingRepositoryProvider).getUserCallerIds();
});

class ActiveCallState {
  final String? callId;
  final String destinationNumber;
  final String userCallbackNumber;
  final CallRate? rate;
  final String status; // 'idle', 'initiating', 'ringing', 'in_progress', 'ended', 'failed'
  final int durationSeconds;
  final double estimatedCost;
  final String? errorMessage;
  final bool isMuted;
  final bool isSpeaker;

  const ActiveCallState({
    this.callId,
    this.destinationNumber = '',
    this.userCallbackNumber = '',
    this.rate,
    this.status = 'idle',
    this.durationSeconds = 0,
    this.estimatedCost = 0.0,
    this.errorMessage,
    this.isMuted = false,
    this.isSpeaker = false,
  });

  ActiveCallState copyWith({
    String? callId,
    String? destinationNumber,
    String? userCallbackNumber,
    CallRate? rate,
    String? status,
    int? durationSeconds,
    double? estimatedCost,
    String? errorMessage,
    bool? isMuted,
    bool? isSpeaker,
  }) {
    return ActiveCallState(
      callId: callId ?? this.callId,
      destinationNumber: destinationNumber ?? this.destinationNumber,
      userCallbackNumber: userCallbackNumber ?? this.userCallbackNumber,
      rate: rate ?? this.rate,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      errorMessage: errorMessage,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
    );
  }
}

class CallingController extends Notifier<ActiveCallState> {
  Timer? _timer;

  @override
  ActiveCallState build() {
    ref.onDispose(() {
      _stopDurationTicker();
    });
    return const ActiveCallState();
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void toggleSpeaker() {
    state = state.copyWith(isSpeaker: !state.isSpeaker);
  }

  Future<void> startCall({
    required String destinationNumber,
    required String userCallbackNumber,
    CallRate? rate,
    String? simLineId,
  }) async {
    state = ActiveCallState(
      destinationNumber: destinationNumber,
      userCallbackNumber: userCallbackNumber,
      rate: rate,
      status: 'initiating',
    );

    try {
      final repository = ref.read(callingRepositoryProvider);
      final res = await repository.initiateCall(
        destinationNumber: destinationNumber,
        userCallbackNumber: userCallbackNumber,
        simLineId: simLineId,
      );

      final callId = res['callId'] as String?;
      state = state.copyWith(
        callId: callId,
        status: 'ringing',
      );

      _startDurationTicker();
    } catch (e) {
      _stopDurationTicker();
      String rawMsg = e.toString().replaceAll('Exception: ', '').replaceAll('FunctionException', '');
      if (rawMsg.contains('non-verified numbers') || rawMsg.contains('account level D60')) {
        rawMsg = 'Telnyx Trial Restriction: Number must be verified in Telnyx portal or upgrade to full account.';
      } else if (rawMsg.contains('insufficient_funds')) {
        rawMsg = 'Insufficient wallet balance. Please top up your wallet.';
      }
      state = state.copyWith(
        status: 'failed',
        errorMessage: rawMsg,
      );
    }
  }

  void _startDurationTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == 'ringing' && timer.tick >= 5) {
        state = state.copyWith(status: 'in_progress');
      }

      if (state.status == 'in_progress') {
        final newSecs = state.durationSeconds + 1;
        final ratePerSec = (state.rate?.ratePerMinute ?? 0.08) / 60.0;
        final cost = newSecs * ratePerSec;
        state = state.copyWith(
          durationSeconds: newSecs,
          estimatedCost: cost,
        );
      }
    });
  }

  void _stopDurationTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void endCall() {
    _stopDurationTicker();
    state = state.copyWith(status: 'ended');
    ref.invalidate(walletControllerProvider);
    ref.invalidate(callHistoryStreamProvider);
  }

  void reset() {
    _stopDurationTicker();
    state = const ActiveCallState();
  }
}

final callingControllerProvider =
    NotifierProvider<CallingController, ActiveCallState>(CallingController.new);
