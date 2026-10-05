import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/profile/domain/contract/profile_contract.dart';
import 'package:mocktail/mocktail.dart';

import 'rate_precision_test.dart' show omrDisplay;

class DisplayTestAuth extends AuthController {
  @override
  Future<UserProfile?> build() async => const UserProfile(id: 'user-a');

  void change(UserProfile? profile) => state = AsyncData(profile);
}

class StoredDisplayAuth extends AuthController {
  StoredDisplayAuth(this.profile);
  final UserProfile Function() profile;
  @override
  Future<UserProfile?> build() async => profile();
}

class MockDisplayProfileRepository extends Mock implements ProfileContract {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'currency setter writes the preference and refreshes without changing tier or onboarding',
    () async {
      var stored = const UserProfile(id: 'a', subscriptionTier: 'standard');
      final repo = MockDisplayProfileRepository();
      registerFallbackValue(const UserProfile());
      when(() => repo.updateProfile(any())).thenAnswer((invocation) async {
        stored = invocation.positionalArguments.first as UserProfile;
        return Success(stored);
      });
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => StoredDisplayAuth(() => stored),
          ),
          profileRepositoryProvider.overrideWithValue(repo),
          fxDisplayContextLoaderProvider.overrideWithValue(
            () async => stored.preferredCurrency == 'USD'
                ? const FxContext()
                : omrDisplay,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container.read(fxControllerProvider.future);
      expect(
        await container
            .read(fxControllerProvider.notifier)
            .setDisplayCurrency('OMR'),
        isTrue,
      );
      expect(stored.preferredCurrency, 'OMR');
      expect(stored.subscriptionTier, 'standard');
      expect(stored.onboardingCompleted, isFalse);
      expect(container.read(fxControllerProvider).value?.currency, 'OMR');
      verify(() => repo.updateProfile(any())).called(1);
    },
  );

  test(
    'expiry delay uses server age, a safety margin and request elapsed time',
    () {
      expect(
        fxRefreshDelay(omrDisplay, Duration.zero),
        const Duration(hours: 6),
      );
      expect(
        fxRefreshDelay(omrDisplay.copyWith(ageHours: 71.99), Duration.zero),
        isNull,
      );
      expect(
        fxRefreshDelay(
          omrDisplay.copyWith(ageHours: 71.5),
          const Duration(seconds: 10),
        ),
        const Duration(minutes: 28, seconds: 50),
      );
      expect(
        fxRefreshDelay(omrDisplay.copyWith(ageHours: null), Duration.zero),
        isNull,
      );
      expect(
        fxRefreshDelay(
          omrDisplay.copyWith(ageHours: double.nan),
          Duration.zero,
        ),
        isNull,
      );
      // The device-wall-clock timestamp cannot change the server-derived delay.
      expect(
        fxRefreshDelay(
          omrDisplay.copyWith(asOf: DateTime(1900)),
          Duration.zero,
        ),
        const Duration(hours: 6),
      );
    },
  );

  testWidgets(
    'account change, sign-out and sign-in clear and reload display FX',
    (tester) async {
      var requests = 0;
      final pending = Completer<FxContext>();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(DisplayTestAuth.new),
          fxDisplayContextLoaderProvider.overrideWithValue(() async {
            requests++;
            return requests == 2 ? pending.future : omrDisplay;
          }),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(children: [Text(r'$10.00'), ApproxLocalText(10)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('≈ OMR 3.850'), findsOneWidget);
      final auth =
          container.read(authControllerProvider.notifier) as DisplayTestAuth;
      auth.change(const UserProfile(id: 'user-b', preferredCurrency: 'EUR'));
      await tester.pump();
      expect(find.text('≈ OMR 3.850'), findsNothing);
      expect(find.text(r'$10.00'), findsOneWidget);
      pending.complete(
        omrDisplay.copyWith(
          currency: 'EUR',
          symbol: '€',
          rate: 0.9,
          decimalDigits: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('≈ €9.00'), findsOneWidget);
      auth.change(null);
      await tester.pumpAndSettle();
      expect(find.text('≈ €9.00'), findsNothing);
      expect(requests, 2);
      auth.change(const UserProfile(id: 'user-a'));
      await tester.pumpAndSettle();
      expect(requests, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets(
    'expiry refresh hides retained data and failed refresh falls back',
    (tester) async {
      var requests = 0;
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(DisplayTestAuth.new),
          fxDisplayContextLoaderProvider.overrideWithValue(() async {
            requests++;
            if (requests > 1) throw StateError('offline');
            return omrDisplay.copyWith(ageHours: 71.9);
          }),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ApproxLocalRateText(0.012, unit: '/min'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('≈ OMR 0.0046/min'), findsOneWidget);
      await tester.pump(const Duration(minutes: 6));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('≈ OMR 0.0046/min'), findsNothing);
      expect(
        container.read(fxControllerProvider).value?.convertsMoney,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  testWidgets('resume revalidates FX and pause cancels background refresh', (
    tester,
  ) async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(DisplayTestAuth.new),
        fxDisplayContextLoaderProvider.overrideWithValue(() async {
          requests++;
          return omrDisplay;
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ApproxLocalText(10)),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(hours: 7));
    expect(requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
