/// KeepSIMs — Calling Controller
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/wallet/providers/wallet_provider.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_lines_provider.dart';

final callRatesProvider = FutureProvider<List<CallRate>>((ref) async {
  return ref.watch(callingRepositoryProvider).getActiveCallRates();
});

final callHistoryStreamProvider = StreamProvider<List<CallRecord>>((ref) {
  return ref.watch(callingRepositoryProvider).watchUserCallHistory();
});

class ActiveCallState {
  final String? callId;
  final String destinationNumber;
  final String userCallbackNumber;
  final CallRate? rate;
  final String status; // 'initiating', 'ringing', 'in_progress', 'ended', 'failed'
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

class CallingController extends StateNotifier<ActiveCallState> {
  final CallingRepository _repository;
  final Ref _ref;
  Timer? _timer;

  CallingController(this._repository, this._ref) : super(const ActiveCallState());

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
      final res = await _repository.initiateCall(
        destinationNumber: destinationNumber,
        userCallbackNumber: userCallbackNumber,
        simLineId: simLineId,
      );

      final callId = res['callId'] as String?;
      state = state.copyWith(
        callId: callId,
        status: 'ringing',
      );

      // Start duration counter simulation / ticker
      _startDurationTicker();
    } catch (e) {
      _stopDurationTicker();
      state = state.copyWith(
        status: 'failed',
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void _startDurationTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == 'ringing' && timer.tick >= 6) {
        // Transition to in-progress when connected
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
    _ref.invalidate(walletProvider);
    _ref.invalidate(callHistoryStreamProvider);
  }

  void reset() {
    _stopDurationTicker();
    state = const ActiveCallState();
  }

  @override
  void dispose() {
    _stopDurationTicker();
    super.dispose();
  }
}

final callingControllerProvider =
    StateNotifierProvider<CallingController, ActiveCallState>((ref) {
  final repo = ref.watch(callingRepositoryProvider);
  return CallingController(repo, ref);
});
