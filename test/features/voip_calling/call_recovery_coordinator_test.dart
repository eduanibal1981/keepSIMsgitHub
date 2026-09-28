import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/services/call_recovery_coordinator.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_signaling_service.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';
import 'package:mocktail/mocktail.dart';

class MockWebRTCAudioService extends Mock implements WebRTCAudioService {}
class MockVoipSignalingService extends Mock implements VoipSignalingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallRecoveryCoordinator State Machine Tests', () {
    late MockWebRTCAudioService mockWebrtc;
    late MockVoipSignalingService mockSignaling;

    setUp(() {
      mockWebrtc = MockWebRTCAudioService();
      mockSignaling = MockVoipSignalingService();

      registerFallbackValue(RTCIceCandidate('dummy', 'audio', 0));
      registerFallbackValue(RTCSessionDescription('v=0', 'offer'));

      when(() => mockSignaling.currentCallId).thenReturn('test-call-101');
      when(() => mockSignaling.connect(any())).thenAnswer((_) async => SignalingSubscriptionResult.subscribed);
      when(() => mockSignaling.sendIceRestartOffer(any(), any())).thenAnswer((_) async {});
      when(() => mockSignaling.sendIceRestartAnswer(any(), any())).thenAnswer((_) async {});

      when(() => mockWebrtc.setIceServers(any())).thenAnswer((_) async {});
      when(() => mockWebrtc.createRestartOffer()).thenAnswer(
        (_) async => RTCSessionDescription('v=0\r\no=- restart', 'offer'),
      );
      when(() => mockWebrtc.handleOfferAndCreateAnswer(any())).thenAnswer(
        (_) async => RTCSessionDescription('v=0\r\no=- answer', 'answer'),
      );
      when(() => mockWebrtc.setRemoteAnswer(any())).thenAnswer((_) async {});
      when(() => mockWebrtc.addCandidate(any())).thenAnswer((_) async {});
      when(() => mockWebrtc.hasRemoteDescription).thenReturn(true);
    });

    test('Disconnected triggers debounced recovery, not immediate restart', () async {
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [const IceServerModel(urls: ['stun:example.com'])],
        isPolite: false,
        debounceDuration: const Duration(milliseconds: 100),
      );

      coordinator.attach();
      expect(coordinator.state, equals(RecoveryState.stable));

      // Disconnected reported: enters debouncing
      coordinator.handlePeerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
      expect(coordinator.state, equals(RecoveryState.debouncing));

      // No restart offer sent yet
      verifyNever(() => mockSignaling.sendIceRestartOffer(any(), any()));

      // After debounce window, recovery commences
      await Future.delayed(const Duration(milliseconds: 150));
      expect(coordinator.state, equals(RecoveryState.renegotiating));
      expect(coordinator.currentGeneration, equals(1));
      verify(() => mockSignaling.sendIceRestartOffer(any(), 1)).called(1);

      coordinator.detach();
    });

    test('Failed state triggers immediate recovery without debounce', () async {
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false,
        debounceDuration: const Duration(seconds: 5), // large debounce
      );

      coordinator.attach();
      coordinator.handlePeerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateFailed);

      // Immediately enters recovering/renegotiating
      expect(coordinator.isRecovering, isTrue);
      expect(coordinator.currentGeneration, equals(1));

      coordinator.detach();
    });

    test('Collision handling: Impolite peer ignores colliding remote offer', () async {
      final impolite = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false, // IMPOLITE (Caller)
      );

      impolite.attach();
      await impolite.triggerRecovery(immediate: true);
      expect(impolite.state, equals(RecoveryState.renegotiating));
      expect(impolite.currentGeneration, equals(1));

      // Colliding remote offer arrives
      await impolite.handleRemoteRestartOffer('v=0\r\ncolliding-offer', 1);

      // Impolite peer must NOT answer the colliding offer
      verifyNever(() => mockSignaling.sendIceRestartAnswer(any(), any()));
      expect(impolite.currentGeneration, equals(1));

      impolite.detach();
    });

    test('Collision handling: Polite peer yields and answers remote offer', () async {
      final polite = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: true, // POLITE (Callee)
      );

      polite.attach();
      await polite.triggerRecovery(immediate: true);
      expect(polite.state, equals(RecoveryState.renegotiating));

      // Colliding remote offer arrives for generation 2
      await polite.handleRemoteRestartOffer('v=0\r\nremote-offer', 2);

      // Polite peer yields, handles remote offer, and responds with answer
      verify(() => mockSignaling.sendIceRestartAnswer(any(), 2)).called(1);
      expect(polite.currentGeneration, equals(2));

      polite.detach();
    });

    test('Obsolete generation candidate is discarded', () async {
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false,
      );

      coordinator.attach();
      await coordinator.triggerRecovery(immediate: true);
      expect(coordinator.currentGeneration, equals(1));

      // Candidate from generation 0 (before restart) arrives
      final oldCandidate = RTCIceCandidate('candidate:1', 'audio', 0);
      await coordinator.handleRemoteCandidate(oldCandidate, 0);

      // Old candidate must be dropped
      verifyNever(() => mockWebrtc.addCandidate(oldCandidate));

      // Current generation candidate is processed
      final freshCandidate = RTCIceCandidate('candidate:2', 'audio', 0);
      await coordinator.handleRemoteCandidate(freshCandidate, 1);
      verify(() => mockWebrtc.addCandidate(freshCandidate)).called(1);

      coordinator.detach();
    });

    test('Connected peer state completes recovery and returns to stable', () async {
      bool recoverySucceeded = false;
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false,
      );

      coordinator.onRecoverySucceeded = () {
        recoverySucceeded = true;
      };

      coordinator.attach();
      await coordinator.triggerRecovery(immediate: true);
      expect(coordinator.isRecovering, isTrue);

      // WebRTC becomes connected again
      coordinator.handlePeerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(coordinator.state, equals(RecoveryState.stable));
      expect(recoverySucceeded, isTrue);

      coordinator.detach();
    });

    test('Network interface handover (Wi-Fi to Cellular) while stable triggers debounced recovery', () async {
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false,
        debounceDuration: const Duration(milliseconds: 100),
      );

      coordinator.attach();
      // Establish initial Wi-Fi connection
      coordinator.lastNetworkTypes = {ConnectivityResult.wifi};
      expect(coordinator.state, equals(RecoveryState.stable));

      // User walks out of Wi-Fi into Cellular coverage: connectivity shifts to mobile
      coordinator.handleConnectivityChange([ConnectivityResult.mobile]);

      // State transitions into debouncing for interface_handover
      expect(coordinator.state, equals(RecoveryState.debouncing));
      verifyNever(() => mockSignaling.sendIceRestartOffer(any(), any()));

      // After debounce window expires, renegotiation commences
      await Future.delayed(const Duration(milliseconds: 150));
      expect(coordinator.state, equals(RecoveryState.renegotiating));
      expect(coordinator.currentGeneration, equals(1));
      verify(() => mockSignaling.sendIceRestartOffer(any(), 1)).called(1);

      coordinator.detach();
    });

    test('Initial network event on attach does not trigger spurious handover', () async {
      final coordinator = CallRecoveryCoordinator(
        webrtc: mockWebrtc,
        signaling: mockSignaling,
        onRefreshIceServers: () async => [],
        isPolite: false,
      );

      coordinator.attach();
      expect(coordinator.lastNetworkTypes, isEmpty);

      // Initial broadcast from Connectivity plugin after attaching
      coordinator.handleConnectivityChange([ConnectivityResult.wifi]);

      // Baseline recorded, remains stable
      expect(coordinator.lastNetworkTypes, equals({ConnectivityResult.wifi}));
      expect(coordinator.state, equals(RecoveryState.stable));
      verifyNever(() => mockSignaling.sendIceRestartOffer(any(), any()));

      coordinator.detach();
    });
  });
}
