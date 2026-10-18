/// KeepSIMs — Calling Controller
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/data/services/call_audio_service.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

final callRatesProvider = FutureProvider<List<CallRate>>((ref) async {
  return ref.watch(callingRepositoryProvider).getActiveCallRates();
});

final callHistoryStreamProvider = StreamProvider<List<CallRecord>>((ref) {
  return ref.watch(callingRepositoryProvider).watchUserCallHistory();
});

final callerIdListProvider = FutureProvider<CallerIdListResult>((ref) async {
  return ref.watch(callingRepositoryProvider).getCallerIdList();
});

final userCallerIdsProvider = FutureProvider<List<CallerIdModel>>((ref) async {
  final res = await ref.watch(callerIdListProvider.future);
  return res.callerIds;
});

class ActiveCallState {
  final String? callId;
  final String destinationNumber;
  final String userCallbackNumber;
  final String? effectiveCallerId;
  final String? callerIdType;
  final CallRate? rate;
  final String
  status; // 'idle', 'initiating', 'ringing', 'in_progress', 'completed', 'ended', 'busy', 'no_answer', 'failed', 'declined', 'cancelled'
  final int durationSeconds;
  final double estimatedCost;
  final String? errorMessage;
  final String? policyReason;
  final String? suggestedAction;
  final int? sipHangupCause;
  final bool isMuted;
  final bool isSpeaker;

  const ActiveCallState({
    this.callId,
    this.destinationNumber = '',
    this.userCallbackNumber = '',
    this.effectiveCallerId,
    this.callerIdType,
    this.rate,
    this.status = 'idle',
    this.durationSeconds = 0,
    this.estimatedCost = 0.0,
    this.errorMessage,
    this.policyReason,
    this.suggestedAction,
    this.sipHangupCause,
    this.isMuted = false,
    this.isSpeaker = false,
  });

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

  ActiveCallState copyWith({
    String? callId,
    String? destinationNumber,
    String? userCallbackNumber,
    String? effectiveCallerId,
    String? callerIdType,
    CallRate? rate,
    String? status,
    int? durationSeconds,
    double? estimatedCost,
    String? errorMessage,
    String? policyReason,
    String? suggestedAction,
    int? sipHangupCause,
    bool? isMuted,
    bool? isSpeaker,
  }) {
    return ActiveCallState(
      callId: callId ?? this.callId,
      destinationNumber: destinationNumber ?? this.destinationNumber,
      userCallbackNumber: userCallbackNumber ?? this.userCallbackNumber,
      effectiveCallerId: effectiveCallerId ?? this.effectiveCallerId,
      callerIdType: callerIdType ?? this.callerIdType,
      rate: rate ?? this.rate,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      errorMessage: errorMessage,
      policyReason: policyReason ?? this.policyReason,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      sipHangupCause: sipHangupCause ?? this.sipHangupCause,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
    );
  }
}

class CallingController extends Notifier<ActiveCallState> {
  Timer? _durationTimer;
  Timer? _pollTimer;
  StreamSubscription<CallRecord?>? _callSub;
  int _pollCount = 0;
  int _attempt = 0;
  bool _polling = false;
  late CallAudioService _audio;

  @override
  ActiveCallState build() {
    _audio = ref.read(callAudioServiceProvider);
    ref.onDispose(() {
      _attempt++;
      _audio.close();
      _stopTimers();
      _callSub?.cancel();
    });
    return const ActiveCallState();
  }

  void toggleMute() {
    if (state.status != 'in_progress') return;
    _audio.setMuted(!state.isMuted);
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void toggleSpeaker() {
    if (state.status != 'in_progress') return;
    _audio.setSpeaker(!state.isSpeaker);
    state = state.copyWith(isSpeaker: !state.isSpeaker);
  }

  void sendDtmf(String tone) {
    if (state.status != 'in_progress') return;
    _audio.sendDtmf(tone);
  }

  Future<void> startCall({
    required String destinationNumber,
    String? callerIdId,
    bool explicitGateway = false,
    String? userCallbackNumber,
    CallRate? rate,
    String? simLineId,
  }) async {
    if (state.status != 'idle' && !state.isTerminal) return;
    final attempt = ++_attempt;
    final repository = ref.read(callingRepositoryProvider);
    _stopTimers();
    _callSub?.cancel();

    state = ActiveCallState(
      destinationNumber: destinationNumber,
      userCallbackNumber: userCallbackNumber ?? '',
      rate: rate,
      status:
          'initiating', // Retain 'initiating' until server confirms ringing/answer
    );

    try {
      await _audio.requestMicrophone();
      if (attempt != _attempt) return;
      final media = await repository.prepareCallAudio();
      if (attempt != _attempt) return;
      await _audio.connect(media['token'] as String);
      if (attempt != _attempt) return;
      final res = await repository.initiateCall(
        destinationNumber: destinationNumber,
        callerIdId: callerIdId,
        explicitGateway: explicitGateway,
        userCallbackNumber: userCallbackNumber,
        simLineId: simLineId,
        mediaSessionId: media['mediaSessionId'] as String,
        idempotencyKey: media['mediaSessionId'] as String,
      );

      final callId = res['callId'] as String?;
      if (attempt != _attempt) {
        if (callId != null) await repository.endCall(callId);
        return;
      }
      if (callId == null) throw Exception('Unable to create call.');
      final effectiveCallerId = res['callerId'] as String?;
      final callerIdType = res['callerIdType'] as String?;
      final accepted = res['destination'];
      final acceptedRate = accepted is Map
          ? CallRate(
              id: rate?.id ?? '',
              countryCode: accepted['countryCode'] as String? ?? '',
              countryName: accepted['countryName'] as String? ?? '',
              phonePrefix: destinationNumber,
              ratePerMinute: (accepted['ratePerMinute'] as num).toDouble(),
              connectionFee:
                  (accepted['connectionFee'] as num?)?.toDouble() ?? 0,
              billingIncrementSeconds:
                  (accepted['billingIncrementSeconds'] as num?)?.toInt() ?? 1,
            )
          : rate;

      state = state.copyWith(
        callId: callId,
        effectiveCallerId: effectiveCallerId,
        callerIdType: callerIdType,
        rate: acceptedRate,
        status: 'initiating', // Setup started; do NOT display premature ringing
      );

      _subscribeToCallStatus(callId);
      await _audio.waitForAudio();
      if (attempt != _attempt || state.isTerminal) return;
      await repository.confirmCallAudio(callId);
      if (attempt != _attempt || state.isTerminal) return;
      _audio.onFailure = (message) {
        if (attempt != _attempt || state.isTerminal) return;
        _stopTimers();
        state = state.copyWith(status: 'failed', errorMessage: message);
        _audio.close();
        unawaited(repository.endCall(callId).catchError((Object _) {}));
      };
      _audio.onEnded = () {
        if (attempt != _attempt || state.isTerminal) return;
        unawaited(endCall());
      };
    } catch (e) {
      if (attempt != _attempt) return;
      _stopTimers();
      _audio.close();
      final failedCallId = state.callId;
      if (failedCallId != null) {
        await repository.endCall(failedCallId).catchError((Object _) {});
      }
      if (attempt != _attempt || state.isTerminal) return;
      String rawMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('FunctionException', '');
      String? suggestedAction;

      if (rawMsg.contains('insufficient_funds')) {
        rawMsg = 'Insufficient wallet balance. Please top up your wallet.';
      } else if (rawMsg.contains('unsupported_same_country_route')) {
        suggestedAction = 'use_gateway';
      } else if (rawMsg.contains('self_dial_conflict')) {
        suggestedAction = 'use_gateway';
      } else if (rawMsg.toLowerCase().contains('settings') ||
          rawMsg.toLowerCase().contains('permanently denied')) {
        suggestedAction = 'open_settings';
      }

      state = state.copyWith(
        status: 'failed',
        errorMessage: rawMsg,
        suggestedAction: suggestedAction,
      );
    }
  }

  void _subscribeToCallStatus(String callId) {
    final repository = ref.read(callingRepositoryProvider);
    _pollCount = 0;

    // 1. Supabase Realtime Stream
    _callSub = repository
        .watchActiveCall(callId)
        .listen(
          (record) {
            if (record != null && state.callId == callId) {
              _handleCallRecordUpdate(record);
            }
          },
          onError: (Object _) {
            /* Polling continues if Realtime disconnects. */
          },
        );

    // Poll through the whole call; setup times out instead of leaving a silent call.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (state.isTerminal || state.callId != callId) {
        timer.cancel();
        return;
      }
      if (_polling) return;
      _pollCount++;
      if (_pollCount >= 45 && state.status != 'in_progress') {
        await endCall();
        return;
      }

      _polling = true;
      try {
        final record = await repository.getCallRecord(callId);
        if (record != null && state.callId == callId) {
          _handleCallRecordUpdate(record);
        }
      } catch (_) {
      } finally {
        _polling = false;
      }
    });
  }

  void _handleCallRecordUpdate(CallRecord record) {
    final serverStatus = record.status.toLowerCase();

    // Prevent late non-terminal events from regressing a terminal state
    if (state.isTerminal) return;

    if (serverStatus == 'ringing') {
      if (state.status != 'ringing' && state.status != 'in_progress') {
        state = state.copyWith(status: 'ringing');
      }
    } else if (serverStatus == 'in_progress') {
      if (state.status != 'in_progress') {
        state = state.copyWith(
          status: 'in_progress',
          effectiveCallerId:
              record.effectiveCallerId ?? state.effectiveCallerId,
        );
        _startDurationTicker();
      }
    } else if (record.isTerminal) {
      _audio.close();
      _stopTimers();
      _callSub?.cancel();

      String? diagnosticMessage = record.errorMessage;
      if (serverStatus == 'declined') {
        diagnosticMessage ??=
            'Call declined or rejected by the destination network';
      } else if (serverStatus == 'busy') {
        diagnosticMessage ??= 'Destination line is busy';
      } else if (serverStatus == 'no_answer') {
        diagnosticMessage ??= 'No answer from recipient';
      } else if (serverStatus == 'cancelled') {
        diagnosticMessage ??= 'Call cancelled';
      } else if (serverStatus == 'failed') {
        diagnosticMessage ??= 'Call failed';
      }

      state = state.copyWith(
        status: serverStatus,
        durationSeconds: record.durationSeconds,
        estimatedCost: record.totalCost,
        errorMessage: diagnosticMessage,
        sipHangupCause: record.sipHangupCause,
        policyReason: record.policyReason,
        effectiveCallerId: record.effectiveCallerId ?? state.effectiveCallerId,
      );

      ref.invalidate(walletControllerProvider);
      ref.invalidate(callHistoryStreamProvider);
    }
  }

  void _startDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == 'in_progress') {
        final newSecs = state.durationSeconds + 1;
        final cost = state.rate?.estimatedCostForSeconds(newSecs) ?? 0;
        state = state.copyWith(durationSeconds: newSecs, estimatedCost: cost);
      }
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> endCall() async {
    _attempt++;
    _audio.close();
    _stopTimers();
    final currentCallId = state.callId;

    if (!state.isTerminal) {
      state = state.copyWith(status: 'ended');
    }

    if (currentCallId != null) {
      try {
        await ref.read(callingRepositoryProvider).endCall(currentCallId);
      } catch (_) {}
    }

    ref.invalidate(walletControllerProvider);
    ref.invalidate(callHistoryStreamProvider);
  }

  void reset() {
    _attempt++;
    _audio.close();
    _stopTimers();
    _callSub?.cancel();
    state = const ActiveCallState();
  }
}

final callingControllerProvider =
    NotifierProvider<CallingController, ActiveCallState>(CallingController.new);
