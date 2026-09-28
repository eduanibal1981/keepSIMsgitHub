/// KeepSIMs — Coordinated WebRTC Network Handover & ICE Recovery State Machine
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_signaling_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';

enum RecoveryState {
  idle,
  stable,
  debouncing,
  recovering,
  renegotiating,
  failed,
}

class CallRecoveryCoordinator {
  final WebRTCAudioService webrtc;
  final VoipSignalingService signaling;
  final Future<List<IceServerModel>> Function() onRefreshIceServers;
  final bool isPolite; // Callee is polite (yields on collision), Caller is impolite
  final Duration debounceDuration;
  final Duration recoveryBudget;

  RecoveryState _state = RecoveryState.idle;
  int _negotiationGeneration = 0;
  Timer? _debounceTimer;
  Timer? _budgetTimer;
  StreamSubscription<dynamic>? _connectivitySub;

  // Candidate buffering tagged by generation
  final Map<int, List<RTCIceCandidate>> _candidateBuffers = {};

  void Function(RecoveryState state)? onStateChanged;
  void Function(String reason)? onRecoveryFailed;
  void Function()? onRecoverySucceeded;

  RecoveryState get state => _state;
  int get currentGeneration => _negotiationGeneration;
  bool get isRecovering =>
      _state == RecoveryState.debouncing ||
      _state == RecoveryState.recovering ||
      _state == RecoveryState.renegotiating;

  CallRecoveryCoordinator({
    required this.webrtc,
    required this.signaling,
    required this.onRefreshIceServers,
    required this.isPolite,
    this.debounceDuration = const Duration(milliseconds: 1500),
    this.recoveryBudget = const Duration(seconds: 25),
  });

  // Network interface history for handover detection
  Set<ConnectivityResult> _lastNetworkTypes = {};

  @visibleForTesting
  Set<ConnectivityResult> get lastNetworkTypes => _lastNetworkTypes;

  @visibleForTesting
  set lastNetworkTypes(Set<ConnectivityResult> types) => _lastNetworkTypes = types;

  /// Attach to active call session
  void attach() {
    _state = RecoveryState.stable;
    _negotiationGeneration = 0;
    _candidateBuffers.clear();
    _lastNetworkTypes.clear();

    // Query current connectivity type non-blockingly to establish interface baseline
    Connectivity().checkConnectivity().then((initial) {
      final active = initial.where((r) => r != ConnectivityResult.none).toSet();
      if (_lastNetworkTypes.isEmpty && active.isNotEmpty) {
        _lastNetworkTypes = active;
      }
    }).catchError((_) {});

    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      handleConnectivityChange(results);
    });
  }

  @visibleForTesting
  void handleConnectivityChange(dynamic results) {
    if (_state == RecoveryState.idle || _state == RecoveryState.failed) return;

    List<ConnectivityResult> list = [];
    if (results is List<ConnectivityResult>) {
      list = results;
    } else if (results is ConnectivityResult) {
      list = [results];
    }

    final activeTypes = list.where((r) => r != ConnectivityResult.none).toSet();
    final bool networkTypeChanged = _lastNetworkTypes.isNotEmpty &&
        activeTypes.isNotEmpty &&
        !setEquals(_lastNetworkTypes, activeTypes);

    debugPrint(
      '[Recovery] Connectivity change: active=$activeTypes, prev=$_lastNetworkTypes, '
      'changed=$networkTypeChanged, state=$_state',
    );

    if (activeTypes.isEmpty) {
      _lastNetworkTypes = activeTypes;
      // Immediate network loss: start recovery debouncing
      triggerRecovery(immediate: false, reason: 'network_loss');
    } else if (networkTypeChanged && _state == RecoveryState.stable) {
      _lastNetworkTypes = activeTypes;
      // Interface handover (e.g. Wi-Fi <-> Cellular) while stable
      triggerRecovery(immediate: false, reason: 'interface_handover');
    } else if (_state == RecoveryState.recovering || _state == RecoveryState.debouncing) {
      _lastNetworkTypes = activeTypes;
      // Network returned while recovering: trigger immediate restart
      triggerRecovery(immediate: true, reason: 'network_restored');
    } else {
      _lastNetworkTypes = activeTypes;
    }
  }

  /// Handle WebRTC connection state transitions
  void handlePeerConnectionState(RTCPeerConnectionState connState) {
    debugPrint('[Recovery] PeerConnection state: $connState (current recovery state: $_state)');

    switch (connState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        if (isRecovering) {
          _completeRecovery();
        } else {
          _transition(RecoveryState.stable);
        }
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        // Debounce transient disconnections (e.g. momentary Wi-Fi handover)
        if (_state == RecoveryState.stable) {
          triggerRecovery(immediate: false, reason: 'ice_disconnected');
        }
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        // Immediate failure: do not debounce
        triggerRecovery(immediate: true, reason: 'ice_failed');
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        detach();
        break;

      default:
        break;
    }
  }

  /// Trigger ICE restart recovery
  Future<void> triggerRecovery({bool immediate = false, String reason = 'unspecified'}) async {
    if (_state == RecoveryState.idle || _state == RecoveryState.failed) return;
    if (_state == RecoveryState.renegotiating) return;

    debugPrint('[Recovery] Trigger recovery (immediate: $immediate, reason: $reason)');

    _debounceTimer?.cancel();

    if (immediate) {
      await _startRenegotiation();
    } else {
      _transition(RecoveryState.debouncing);
      _debounceTimer = Timer(debounceDuration, () {
        if (_state == RecoveryState.debouncing) {
          _startRenegotiation();
        }
      });
    }
  }

  Future<void> _startRenegotiation() async {
    _transition(RecoveryState.recovering);

    // Start recovery budget timer if not already active
    _budgetTimer ??= Timer(recoveryBudget, () {
      debugPrint('[Recovery] Recovery budget ($recoveryBudget) exceeded!');
      _failRecovery('recovery_timeout');
    });

    _negotiationGeneration++;
    final gen = _negotiationGeneration;
    _candidateBuffers[gen] = [];

    debugPrint('[Recovery] Starting ICE restart renegotiation for generation $gen');

    try {
      // 1. Refresh ICE servers if credentials might have expired
      try {
        final freshServers = await onRefreshIceServers();
        if (freshServers.isNotEmpty) {
          await webrtc.setIceServers(freshServers);
        }
      } catch (e) {
        debugPrint('[Recovery] Ice server refresh warning: $e');
      }

      // 2. Re-establish signaling connection if dropped
      final currentCallId = signaling.currentCallId;
      if (currentCallId != null) {
        await signaling.connect(currentCallId);
      }

      _transition(RecoveryState.renegotiating);

      // 3. Create ICE restart offer
      final offer = await webrtc.createRestartOffer();

      // 4. Send over signaling with generation tag
      await signaling.sendIceRestartOffer(offer.sdp!, gen);
      debugPrint('[Recovery] Sent ICE restart offer for generation $gen');
    } catch (e) {
      debugPrint('[Recovery] Error creating restart offer: $e');
      // If we failed to create offer, let budget timer handle failure
    }
  }

  /// Handle incoming ICE restart offer from remote peer
  Future<void> handleRemoteRestartOffer(String sdp, int remoteGen) async {
    debugPrint('[Recovery] Received remote restart offer for generation $remoteGen (local: $_negotiationGeneration, isPolite: $isPolite)');

    // Collision detection: we are both attempting to renegotiate simultaneously
    final bool isCollision =
        _state == RecoveryState.renegotiating || _state == RecoveryState.recovering;

    if (isCollision && !isPolite) {
      // Impolite peer rejects remote colliding offer and enforces its own offer
      debugPrint('[Recovery] Impolite peer ignoring colliding remote offer');
      return;
    }

    // Polite peer yields to remote offer
    _transition(RecoveryState.renegotiating);
    _negotiationGeneration = remoteGen;
    final gen = _negotiationGeneration;
    _candidateBuffers[gen] = [];

    _budgetTimer ??= Timer(recoveryBudget, () {
      _failRecovery('recovery_timeout');
    });

    try {
      final answer = await webrtc.handleOfferAndCreateAnswer(sdp);
      await signaling.sendIceRestartAnswer(answer.sdp!, gen);
      debugPrint('[Recovery] Sent ICE restart answer for generation $gen');

      // Drain any candidates buffered for this generation
      await _drainCandidatesForGeneration(gen);
    } catch (e) {
      debugPrint('[Recovery] Error handling remote restart offer: $e');
    }
  }

  /// Handle incoming ICE restart answer from remote peer
  Future<void> handleRemoteRestartAnswer(String sdp, int remoteGen) async {
    if (remoteGen != _negotiationGeneration) {
      debugPrint('[Recovery] Ignoring stale restart answer for gen $remoteGen (current: $_negotiationGeneration)');
      return;
    }

    debugPrint('[Recovery] Handling remote restart answer for generation $remoteGen');
    try {
      await webrtc.setRemoteAnswer(sdp);
      await _drainCandidatesForGeneration(remoteGen);
    } catch (e) {
      debugPrint('[Recovery] Error setting remote restart answer: $e');
    }
  }

  /// Buffer or apply ICE candidate tagged with generation
  Future<void> handleRemoteCandidate(RTCIceCandidate candidate, int gen) async {
    // Ignore candidates from obsolete generations
    if (gen < _negotiationGeneration) {
      debugPrint('[Recovery] Dropping obsolete ICE candidate from gen $gen (current: $_negotiationGeneration)');
      return;
    }

    if (_state == RecoveryState.renegotiating && !webrtc.hasRemoteDescription) {
      debugPrint('[Recovery] Buffering remote candidate for gen $gen');
      _candidateBuffers.putIfAbsent(gen, () => []).add(candidate);
      return;
    }

    await webrtc.addCandidate(candidate);
  }

  Future<void> _drainCandidatesForGeneration(int gen) async {
    final list = _candidateBuffers.remove(gen);
    if (list != null && list.isNotEmpty) {
      debugPrint('[Recovery] Draining ${list.length} buffered candidates for gen $gen');
      for (final cand in list) {
        await webrtc.addCandidate(cand);
      }
    }
  }

  void _completeRecovery() {
    debugPrint('[Recovery] ICE recovery succeeded for generation $_negotiationGeneration!');
    _debounceTimer?.cancel();
    _budgetTimer?.cancel();
    _budgetTimer = null;
    _candidateBuffers.clear();
    _transition(RecoveryState.stable);
    onRecoverySucceeded?.call();
  }

  void _failRecovery(String reason) {
    debugPrint('[Recovery] ICE recovery failed: $reason');
    _debounceTimer?.cancel();
    _budgetTimer?.cancel();
    _budgetTimer = null;
    _candidateBuffers.clear();
    _transition(RecoveryState.failed);
    onRecoveryFailed?.call(reason);
  }

  void _transition(RecoveryState next) {
    if (_state != next) {
      _state = next;
      onStateChanged?.call(next);
    }
  }

  /// Clean up and release coordinator resources
  void detach() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _budgetTimer?.cancel();
    _budgetTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _candidateBuffers.clear();
    _lastNetworkTypes.clear();
    _state = RecoveryState.idle;
  }
}
