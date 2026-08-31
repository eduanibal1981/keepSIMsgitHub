/// KeepSIMs — Calling Controller
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final String status; // 'idle', 'initiating', 'ringing', 'in_progress', 'ended', 'busy', 'no_answer', 'failed'
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
  StreamSubscription<CallRecord?>? _callSub;

  @override
  ActiveCallState build() {
    ref.onDispose(() {
      _stopDurationTicker();
      _callSub?.cancel();
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
    _stopDurationTicker();
    _callSub?.cancel();

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

      // Subscribe to real-time call status updates from Supabase
      if (callId != null) {
        _subscribeToCallStatus(callId);
      }
    } catch (e) {
      _stopDurationTicker();
      String rawMsg = 'Failed to initiate call';
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['errorMessage'] != null) {
          rawMsg = details['errorMessage'].toString();
        } else if (details is Map && details['error'] != null) {
          rawMsg = details['error'].toString();
        } else if (details is Map && details['message'] != null) {
          rawMsg = details['message'].toString();
        } else if (e.reasonPhrase != null && e.reasonPhrase!.isNotEmpty) {
          rawMsg = e.reasonPhrase!;
        } else if (details is String && details.isNotEmpty) {
          rawMsg = details;
        } else {
          rawMsg = 'Call request failed (${e.status}).';
        }
      } else {
        rawMsg = e.toString().replaceAll('Exception: ', '').trim();
      }

      if (rawMsg.toLowerCase().contains('insufficient_funds') ||
          rawMsg.toLowerCase().contains('insufficient balance')) {
        rawMsg = 'Insufficient wallet balance. Please top up your wallet.';
      }
      state = state.copyWith(
        status: 'failed',
        errorMessage: rawMsg,
      );
    }
  }

  void _subscribeToCallStatus(String callId) {
    final repository = ref.read(callingRepositoryProvider);
    _callSub = repository.watchActiveCall(callId).listen((record) {
      if (record == null) return;

      final serverStatus = record.status.toLowerCase();
      if (serverStatus == 'ringing' && state.status != 'ringing') {
        state = state.copyWith(status: 'ringing');
      } else if (serverStatus == 'in_progress') {
        if (state.status != 'in_progress') {
          state = state.copyWith(status: 'in_progress');
          _startDurationTicker();
        }
      } else if (serverStatus == 'completed' ||
                 serverStatus == 'busy' ||
                 serverStatus == 'no_answer' ||
                 serverStatus == 'cancelled' ||
                 serverStatus == 'declined' ||
                 serverStatus == 'failed') {
        _stopDurationTicker();
        state = state.copyWith(
          status: serverStatus,
          errorMessage: serverStatus == 'busy'
              ? 'User Busy'
              : serverStatus == 'no_answer'
                  ? 'No Answer'
                  : serverStatus == 'declined'
                      ? 'Call Declined'
                      : null,
        );
        ref.invalidate(walletControllerProvider);
        ref.invalidate(callHistoryStreamProvider);
      }
    });
  }

  void _startDurationTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  Future<void> endCall() async {
    _stopDurationTicker();
    final currentCallId = state.callId;
    state = state.copyWith(status: 'ended');

    if (currentCallId != null) {
      try {
        await ref.read(callingRepositoryProvider).endCall(currentCallId);
      } catch (_) {}
    }

    ref.invalidate(walletControllerProvider);
    ref.invalidate(callHistoryStreamProvider);
  }

  void reset() {
    _stopDurationTicker();
    _callSub?.cancel();
    state = const ActiveCallState();
  }
}

final callingControllerProvider =
    NotifierProvider<CallingController, ActiveCallState>(CallingController.new);
