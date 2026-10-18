import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/contract/auth_contract.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/notifications/data/repositories/device_token_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthContract {}

class _Devices extends Mock implements DeviceTokenRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth repository;
  late ProviderContainer container;
  late StreamController<String?> events;
  var authenticated = false;
  const profile = UserProfile(id: 'apple-user', fullName: 'Ada Lovelace');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('OneSignal'),
          (_) async => null,
        );
    repository = _Auth();
    events = StreamController<String?>.broadcast();
    authenticated = false;
    when(() => repository.isAuthenticated).thenAnswer((_) => authenticated);
    when(() => repository.authStateChanges).thenAnswer((_) => events.stream);
    when(() => repository.ensureValidSession()).thenAnswer((_) async => true);
    when(
      () => repository.getCurrentProfile(),
    ).thenAnswer((_) async => const Success(profile));
    final devices = _Devices();
    when(() => devices.registerCurrentDevice(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((_) => repository),
        deviceTokenRepositoryProvider.overrideWith((_) => devices),
      ],
    );
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    events.add(null); // Initial session event, which build() skips.
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    container.dispose();
    await events.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('OneSignal'), null);
  });

  test(
    'keeps signedIn from routing before the Apple name has been saved',
    () async {
      final completion = Completer<Result<UserProfile>>();
      when(
        () => repository.signInWithApple(),
      ).thenAnswer((_) => completion.future);
      final controller = container.read(authControllerProvider.notifier);
      final signingIn = controller.signInWithApple();
      authenticated = true;
      events.add('apple-user');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider).isLoading, isTrue);
      verifyNever(() => repository.getCurrentProfile());
      await controller
          .signInWithApple(); // Repeated taps cannot launch a second sheet.
      verify(() => repository.signInWithApple()).called(1);
      completion.complete(const Success(profile));
      await signingIn;
      expect(await container.read(authControllerProvider.future), profile);
    },
  );

  test('cancellation returns to signed out without an error', () async {
    when(() => repository.signInWithApple()).thenAnswer(
      (_) async => const Failure(AppFailure.auth(message: 'Sign-in canceled.')),
    );
    await container.read(authControllerProvider.notifier).signInWithApple();
    final state = container.read(authControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.value, isNull);
  });

  test('verification failures are visible and can be retried', () async {
    when(() => repository.signInWithApple()).thenAnswer(
      (_) async => const Failure(AppFailure.auth(message: 'Try again.')),
    );
    final controller = container.read(authControllerProvider.notifier);
    await controller.signInWithApple();
    expect(container.read(authControllerProvider).error, 'Try again.');
    when(() => repository.signInWithApple()).thenAnswer(
      (_) async => const Failure(AppFailure.auth(message: 'Sign-in canceled.')),
    );
    await controller.signInWithApple();
    expect(container.read(authControllerProvider).hasError, isFalse);
  });
}
