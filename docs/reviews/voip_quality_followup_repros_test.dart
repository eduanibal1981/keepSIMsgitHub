// Review-only regression probes. Run explicitly; these are expected to fail
// until the corresponding production issues are fixed.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/services/call_recovery_coordinator.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_signaling_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_quality_collector.dart';
import 'package:mocktail/mocktail.dart';

class MockAudio extends Mock implements WebRTCAudioService {}

class MockSignaling extends Mock implements VoipSignalingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAudio audio;
  late MockSignaling signaling;
  late CallRecoveryCoordinator recovery;

  setUp(() {
    audio = MockAudio();
    signaling = MockSignaling();
    registerFallbackValue(RTCIceCandidate('candidate:test', '0', 0));
    when(() => audio.hasRemoteDescription).thenReturn(true);
    when(() => audio.addCandidate(any())).thenAnswer((_) async {});
    when(() => audio.setIceServers(any())).thenAnswer((_) async {});
    when(
      () => audio.createRestartOffer(),
    ).thenAnswer((_) async => RTCSessionDescription('restart', 'offer'));
    when(
      () => audio.handleOfferAndCreateAnswer(any()),
    ).thenAnswer((_) async => RTCSessionDescription('answer', 'answer'));
    when(() => signaling.currentCallId).thenReturn('call');
    when(
      () => signaling.connect(any()),
    ).thenAnswer((_) async => SignalingSubscriptionResult.subscribed);
    when(
      () => signaling.sendIceRestartOffer(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => signaling.sendIceRestartAnswer(any(), any()),
    ).thenAnswer((_) async {});
    recovery = CallRecoveryCoordinator(
      webrtc: audio,
      signaling: signaling,
      onRefreshIceServers: () async => [],
      isPolite: true,
    );
    recovery.attach();
  });
  tearDown(() => recovery.detach());

  test(
    'future-generation candidate waits for its remote restart offer',
    () async {
      final candidate = RTCIceCandidate('candidate:new-generation', '0', 0);
      await recovery.handleRemoteCandidate(candidate, 1);
      verifyNever(() => audio.addCandidate(candidate));
    },
  );

  test(
    'detach cancels an in-flight restart before it sends an offer',
    () async {
      recovery.detach();
      final refresh = Completer<List<IceServerModel>>();
      recovery = CallRecoveryCoordinator(
        webrtc: audio,
        signaling: signaling,
        onRefreshIceServers: () => refresh.future,
        isPolite: true,
      );
      recovery.attach();
      final pending = recovery.triggerRecovery(immediate: true);
      recovery.detach();
      refresh.complete([]);
      await pending;
      expect(recovery.state, RecoveryState.idle);
      verifyNever(() => signaling.sendIceRestartOffer(any(), any()));
    },
  );

  test('stale remote restart offer cannot roll back the generation', () async {
    await recovery.handleRemoteRestartOffer('new', 2);
    recovery.handlePeerConnectionState(
      RTCPeerConnectionState.RTCPeerConnectionStateConnected,
    );
    await recovery.handleRemoteRestartOffer('stale', 1);
    expect(recovery.currentGeneration, 2);
    verifyNever(() => audio.handleOfferAndCreateAnswer('stale'));
  });

  test('recovery requests are serialized during credential refresh', () async {
    recovery.detach();
    final refresh = Completer<List<IceServerModel>>();
    recovery = CallRecoveryCoordinator(
      webrtc: audio,
      signaling: signaling,
      onRefreshIceServers: () => refresh.future,
      isPolite: true,
    );
    recovery.attach();
    final first = recovery.triggerRecovery(immediate: true);
    final second = recovery.triggerRecovery(immediate: true);
    refresh.complete([]);
    await Future.wait([first, second]);
    verify(() => audio.createRestartOffer()).called(1);
  });

  test(
    'stats follow the selected transport pair, not the last succeeded pair',
    () {
      final collector = WebRTCQualityCollector();
      addTearDown(collector.dispose);
      final snapshot = collector.parseStatsReports([
        StatsReport('transport', 'transport', 1000, {
          'selectedCandidatePairId': 'selected',
        }),
        StatsReport('selected', 'candidate-pair', 1000, {
          'state': 'succeeded',
          'nominated': true,
          'currentRoundTripTime': 0.020,
          'localCandidateId': 'direct',
        }),
        StatsReport('unused', 'candidate-pair', 1000, {
          'state': 'succeeded',
          'nominated': false,
          'currentRoundTripTime': 0.250,
          'localCandidateId': 'relay',
        }),
        StatsReport('direct', 'local-candidate', 1000, {
          'candidateType': 'host',
          'protocol': 'udp',
        }),
        StatsReport('relay', 'local-candidate', 1000, {
          'candidateType': 'relay',
          'protocol': 'udp',
        }),
      ], DateTime(2026, 9, 24));
      expect(snapshot!.currentRttMs, 20);
      expect(snapshot.isRelayed, isFalse);
    },
  );
}
