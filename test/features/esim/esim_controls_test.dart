import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_controls_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_controls.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_controls_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_controls_screen.dart';

class AuthFixture extends AuthController {
  @override
  FutureOr<UserProfile?> build() => const UserProfile(id: 'owner');
  void leave() => state = const AsyncData(null);
}

class ControlsFixture implements EsimControlsRepository {
  final keys = <String>[];
  bool failOnce = false;
  @override
  Future<String> control(
    String id,
    String action,
    String key,
    EsimControlSnapshot s,
  ) async {
    keys.add(key);
    if (failOnce) {
      failOnce = false;
      throw Exception('uncertain transport');
    }
    return 'ACCEPTED';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GuardFixture implements PaymentAuthGuard {
  Completer<BiometricResult>? waiting;
  @override
  Future<BiometricResult> confirmPayment({
    required String reason,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async => waiting == null ? BiometricResult.success : waiting!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('money inputs preserve cents and reject invented precision', () {
    expect(EsimAutomationSettings.parseCents('1.73'), 173);
    expect(EsimAutomationSettings.parseLocalEnd('2026-13-01'), isNull);
    expect(EsimAutomationSettings.parseLocalEnd('2026-02-30'), isNull);
    expect(EsimAutomationSettings.parseLocalEnd('2026-12-01')?.month, 12);
    expect(EsimAutomationSettings.parseCents('0.10'), 10);
    for (final value in ['NaN', '1e3', '-2', '1.001', '1,00']) {
      expect(EsimAutomationSettings.parseCents(value), isNull);
    }
  });
  test('daily quota trigger cannot silently reuse fixed consent', () {
    const s = EsimAutomationSettings(
      packageId: 'P',
      daily: true,
      maxCents: 100,
      monthlyCents: 200,
      threshold: 24,
      intervalHours: 6,
    );
    expect(s.valid, false);
    expect(s.toJson()['trigger'], 'daily_near_expiry');
  });
  test('default projection exposes no enabled control or consent', () {
    const s = EsimControlSnapshot({}, {});
    expect(s.cancellationEnabled, false);
    expect(s.autoEnabled, false);
    expect(s.autoAvailable, false);
    expect(s.refunds, isEmpty);
  });
  test(
    'uncertain retry retains its key; a later service action receives a new key',
    () async {
      final repo = ControlsFixture()..failOnce = true;
      final c = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(AuthFixture.new),
          esimControlsRepositoryProvider.overrideWithValue(repo),
          paymentAuthGuardProvider.overrideWithValue(GuardFixture()),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(esimControlsActionsProvider('p'), (_, _) {});
      addTearDown(sub.close);
      await c.read(authControllerProvider.future);
      const snapshot = EsimControlSnapshot({
        'owner_id': 'owner',
        'suspend_enabled': true,
      }, {});
      final actions = c.read(esimControlsActionsProvider('p'));
      await expectLater(
        actions.run(snapshot, action: 'suspend'),
        throwsException,
      );
      expect(await actions.run(snapshot, action: 'suspend'), 'ACCEPTED');
      expect(repo.keys[0], repo.keys[1]);
      expect(await actions.run(snapshot, action: 'suspend'), 'ACCEPTED');
      expect(repo.keys[2], isNot(repo.keys[1]));
    },
  );
  test('sign-out during confirmation prevents a service request', () async {
    final repo = ControlsFixture(),
        guard = GuardFixture()..waiting = Completer<BiometricResult>();
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimControlsRepositoryProvider.overrideWithValue(repo),
        paymentAuthGuardProvider.overrideWithValue(guard),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(esimControlsActionsProvider('p'), (_, _) {});
    addTearDown(sub.close);
    await c.read(authControllerProvider.future);
    final action = c
        .read(esimControlsActionsProvider('p'))
        .run(
          const EsimControlSnapshot({
            'owner_id': 'owner',
            'suspend_enabled': true,
          }, {}),
          action: 'suspend',
        );
    (c.read(authControllerProvider.notifier) as AuthFixture).leave();
    guard.waiting!.complete(BiometricResult.success);
    expect(await action, 'ACCOUNT_CHANGED');
    expect(repo.keys, isEmpty);
  });
  testWidgets(
    'disabled controls explain pending refunds and never offer enabled automation',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(AuthFixture.new),
            esimControlsProvider('p').overrideWith(
              (ref) async => const EsimControlSnapshot({
                'owner_id': 'owner',
                'status': 'READY',
                'profile_state': 'issued',
                'cancellation_reason': 'REFUND_POLICY_UNVERIFIED',
                'operations': [
                  {'action': 'cancel', 'state': 'refund_pending'},
                ],
              }, {}),
            ),
          ],
          child: const MaterialApp(home: EsimControlsScreen(profileId: 'p')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('cancel: refund_pending'), findsOneWidget);
      expect(
        find.text('Automatic recharge is currently unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Review & enable automatic recharge'), findsNothing);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review cancellation & refund'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('sign-out clears saved control data', (t) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimControlsProvider('p').overrideWith((ref) async {
          final owner = ref.watch(authControllerProvider).value?.id;
          if (owner == null) throw Exception('Sign in');
          return const EsimControlSnapshot({
            'owner_id': 'owner',
            'profile_state': 'suspended',
          }, {});
        }),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EsimControlsScreen(profileId: 'p')),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Service: suspended'), findsOneWidget);
    (container.read(authControllerProvider.notifier) as AuthFixture).leave();
    await t.pumpAndSettle();
    expect(find.text('Service: suspended'), findsNothing);
  });
}
