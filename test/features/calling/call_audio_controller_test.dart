import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/data/services/call_audio_service.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';

class AudioMock extends Mock implements CallAudioService {
  @override
  void Function(String)? onFailure;

  @override
  void Function()? onEnded;
}

class RepositoryMock extends Mock implements CallingRepository {}

class FakeWalletController extends WalletController {
  @override
  FutureOr<WalletState> build() {
    return const WalletState(
      wallet: Wallet(id: 'test', userId: 'owner', balance: 10.0),
      transactions: [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AudioMock audio;
  late RepositoryMock repository;
  late ProviderContainer container;
  late StreamController<CallRecord?> records;
  late List<String> steps;

  setUp(() {
    audio = AudioMock();
    repository = RepositoryMock();
    records = StreamController<CallRecord?>.broadcast(sync: true);
    steps = [];
    when(() => audio.requestMicrophone()).thenAnswer((_) async {
      steps.add('microphone');
    });
    when(() => repository.prepareCallAudio()).thenAnswer((_) async {
      steps.add('credentials');
      return {'mediaSessionId': 'session', 'token': 'test-token'};
    });
    when(() => audio.connect(any())).thenAnswer((_) async {
      steps.add('register');
    });
    when(() => audio.waitForAudio()).thenAnswer((_) async {
      steps.add('audio');
    });
    when(
      () => repository.initiateCall(
        destinationNumber: any(named: 'destinationNumber'),
        mediaSessionId: any(named: 'mediaSessionId'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      steps.add('dial-app');
      return {'callId': 'call'};
    });
    when(() => repository.confirmCallAudio(any())).thenAnswer((_) async {
      steps.add('dial-phone');
    });
    when(() => repository.endCall(any())).thenAnswer((_) async {});
    when(
      () => repository.watchActiveCall(any()),
    ).thenAnswer((_) => records.stream);
    when(() => repository.getCallRecord(any())).thenAnswer((_) async => null);
    when(
      () => repository.watchUserCallHistory(),
    ).thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(
      overrides: [
        callAudioServiceProvider.overrideWithValue(audio),
        callingRepositoryProvider.overrideWithValue(repository),
        walletControllerProvider.overrideWith(FakeWalletController.new),
      ],
    );
  });
  tearDown(() async {
    container.read(callingControllerProvider.notifier).reset();
    container.dispose();
    await records.close();
  });

  test(
    'connects microphone and app audio before allowing destination dialing',
    () async {
      await container
          .read(callingControllerProvider.notifier)
          .startCall(destinationNumber: '+12025550123');
      expect(steps, [
        'microphone',
        'credentials',
        'register',
        'dial-app',
        'audio',
        'dial-phone',
      ]);
      expect(container.read(callingControllerProvider).status, 'initiating');
    },
  );
  test('microphone denial never creates or dials a call', () async {
    when(
      () => audio.requestMicrophone(),
    ).thenThrow(Exception('Allow microphone access.'));
    await container
        .read(callingControllerProvider.notifier)
        .startCall(destinationNumber: '+12025550123');
    verifyNever(() => repository.prepareCallAudio());
    expect(container.read(callingControllerProvider).status, 'failed');
  });
  test(
    'audio failure hangs up the app leg without dialing the phone',
    () async {
      when(
        () => audio.waitForAudio(),
      ).thenThrow(Exception('Audio unavailable'));
      await container
          .read(callingControllerProvider.notifier)
          .startCall(destinationNumber: '+12025550123');
      verify(() => repository.endCall('call')).called(1);
      verifyNever(() => repository.confirmCallAudio(any()));
      expect(container.read(callingControllerProvider).status, 'failed');
    },
  );
  test(
    'cancel during call creation cleans up the late server response',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      when(
        () => repository.initiateCall(
          destinationNumber: any(named: 'destinationNumber'),
          mediaSessionId: any(named: 'mediaSessionId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) => pending.future);
      final controller = container.read(callingControllerProvider.notifier);
      final start = controller.startCall(destinationNumber: '+12025550123');
      await Future<void>.delayed(Duration.zero);
      await controller.endCall();
      pending.complete({'callId': 'late-call'});
      await start;
      verify(() => repository.endCall('late-call')).called(1);
      verifyNever(() => repository.confirmCallAudio(any()));
      expect(container.read(callingControllerProvider).status, 'ended');
    },
  );
  test('mute and speaker operate actual audio only while connected', () async {
    final controller = container.read(callingControllerProvider.notifier);
    await controller.startCall(destinationNumber: '+12025550123');
    controller.toggleMute();
    verifyNever(() => audio.setMuted(any()));
    records.add(
      CallRecord.fromJson({
        'id': 'call',
        'user_id': 'owner',
        'call_type': 'app_to_phone_webrtc',
        'caller_number': '+12025550124',
        'destination_number': '+12025550123',
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'rate_per_minute_usd': .1,
      }),
    );
    controller.toggleMute();
    controller.toggleSpeaker();
    verify(() => audio.setMuted(true)).called(1);
    verify(() => audio.setSpeaker(true)).called(1);
  });

  test(
    'audio failure callback during connected call triggers cleanup and sets status to failed',
    () async {
      final controller = container.read(callingControllerProvider.notifier);
      await controller.startCall(destinationNumber: '+12025550123');
      expect(audio.onFailure, isNotNull);
      audio.onFailure!('WebRTC media connection lost');
      expect(container.read(callingControllerProvider).status, 'failed');
      expect(
        container.read(callingControllerProvider).errorMessage,
        'WebRTC media connection lost',
      );
      verify(() => repository.endCall('call')).called(1);
      verify(() => audio.close()).called(greaterThanOrEqualTo(1));
    },
  );

  test('audio onEnded callback triggers endCall', () async {
    final controller = container.read(callingControllerProvider.notifier);
    await controller.startCall(destinationNumber: '+12025550123');
    expect(audio.onEnded, isNotNull);
    audio.onEnded!();
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.endCall('call')).called(1);
    expect(container.read(callingControllerProvider).status, 'ended');
  });

  test(
    'terminal state is permanent and rejects late ringing or in_progress updates',
    () async {
      final controller = container.read(callingControllerProvider.notifier);
      await controller.startCall(destinationNumber: '+12025550123');
      records.add(
        CallRecord.fromJson({
          'id': 'call',
          'user_id': 'owner',
          'call_type': 'app_to_phone_webrtc',
          'caller_number': '+12025550124',
          'destination_number': '+12025550123',
          'status': 'completed',
          'duration_seconds': 45,
          'rate_per_minute_usd': 0.1,
        }),
      );
      expect(container.read(callingControllerProvider).status, 'completed');
      expect(container.read(callingControllerProvider).isTerminal, isTrue);

      // Emit late non-terminal event
      records.add(
        CallRecord.fromJson({
          'id': 'call',
          'user_id': 'owner',
          'call_type': 'app_to_phone_webrtc',
          'caller_number': '+12025550124',
          'destination_number': '+12025550123',
          'status': 'ringing',
        }),
      );
      expect(container.read(callingControllerProvider).status, 'completed');
    },
  );

  test('calling reset returns state to idle and closes audio', () async {
    final controller = container.read(callingControllerProvider.notifier);
    await controller.startCall(destinationNumber: '+12025550123');
    expect(container.read(callingControllerProvider).status, 'initiating');
    controller.reset();
    expect(container.read(callingControllerProvider).status, 'idle');
    expect(container.read(callingControllerProvider).callId, isNull);
  });
}
