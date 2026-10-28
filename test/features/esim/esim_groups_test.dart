import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_group.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_group_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_group_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_group_checkout_screen.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_help_screen.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_group_panel.dart';

class AuthFixture extends AuthController {
  @override
  FutureOr<UserProfile?> build() => const UserProfile(id: 'owner');
  void leave() => state = const AsyncData(null);
}

class GuardFixture implements PaymentAuthGuard {
  Completer<BiometricResult>? pending;
  @override
  Future<BiometricResult> confirmPayment({
    required String reason,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async => pending == null ? BiometricResult.success : pending!.future;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

EsimGroupQuote quoted({String owner = 'owner', bool enabled = false}) =>
    EsimGroupQuote({
      'status': 'QUOTED',
      'quote_id': 'quote',
      'acceptance_key': 'accept',
      'owner_id': owner,
      'payer_id': owner,
      'currency': 'USD',
      'retail_total': 3,
      'acceptance_enabled': enabled,
      'balance_state': 'sufficient',
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 2))
          .toIso8601String(),
      'members': [
        {'traveller_label': 'Alex', 'title': 'Oman', 'retail_total': 1.5},
        {'traveller_label': 'Sam', 'title': 'Oman', 'retail_total': 1.5},
      ],
    });

class GroupFixture implements EsimGroupRepository {
  EsimGroupQuote result = quoted();
  int accepted = 0;
  Completer<EsimGroupQuote>? waiting;
  @override
  Future<EsimGroupQuote> quote(
    String group,
    List<EsimTravellerIntent> members,
  ) async => waiting == null ? result : waiting!.future;
  @override
  Future<EsimOrganization> organization() async => const EsimOrganization({
    'owner_id': 'owner',
    'max_members': 3,
    'groups': [],
    'labels': [],
  });
  @override
  Future<Map<String, dynamic>> accept(
    String q,
    String key,
    String request,
  ) async {
    accepted++;
    return {'status': 'ACCEPTED', 'batch_id': 'batch'};
  }

  @override
  Future<String> label(String id, String traveller, String group) async =>
      'SAVED';
}

void main() {
  test('group review rejects incomplete and unbalanced totals', () {
    expect(quoted().complete, true);
    expect(
      EsimGroupQuote({...quoted().data, 'retail_total': 2}).complete,
      false,
    );
    expect(
      EsimGroupQuote({...quoted().data, 'currency': 'EUR'}).enabled,
      false,
    );
    expect(const EsimTravellerIntent('A', 'Bad\nlabel').valid, false);
  });
  test('daily traveller durations are exact and bounded', () {
    expect(
      const EsimTravellerIntent('A', 'Alex', days: 5).toJson()['period_count'],
      5,
    );
    for (final days in [0, 366]) {
      expect(EsimTravellerIntent('A', 'Alex', days: days).valid, false);
    }
  });
  test('late quote response cannot cross an account change', () async {
    final repo = GroupFixture()..waiting = Completer<EsimGroupQuote>();
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimGroupRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(esimGroupActionsProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(authControllerProvider.future);
    final pending = c.read(esimGroupActionsProvider).review('Trip', [
      const EsimTravellerIntent('A', 'Alex'),
    ]);
    (c.read(authControllerProvider.notifier) as AuthFixture).leave();
    repo.waiting!.complete(quoted());
    expect((await pending).status, 'ACCOUNT_CHANGED');
  });
  test('foreign quote and disabled sales cannot request payment', () async {
    final repo = GroupFixture();
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimGroupRepositoryProvider.overrideWithValue(repo),
        paymentAuthGuardProvider.overrideWithValue(GuardFixture()),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(esimGroupActionsProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(authControllerProvider.future);
    final action = c.read(esimGroupActionsProvider);
    expect(
      (await action.accept(
        quoted(owner: 'other', enabled: true),
        'key',
      ))['status'],
      'ACCOUNT_CHANGED',
    );
    expect(
      (await action.accept(quoted(), 'key'))['status'],
      'QUOTE_UNAVAILABLE',
    );
    expect(repo.accepted, 0);
  });
  testWidgets(
    'checkout shows separate profiles, exact reviewed total and disabled purchase',
    (t) async {
      final repo = GroupFixture();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(AuthFixture.new),
            esimGroupRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: EsimGroupCheckoutScreen(
              plan: EsimPlan(
                id: 'A',
                name: 'Oman',
                dataAmountMB: 1024,
                durationDays: 7,
                priceUsd: 1.5,
                providerName: 'esimaccess',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Review server total'));
      await t.pump();
      await t.pump();
      await t.scrollUntilVisible(
        find.text('Total USD 3.00'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Total USD 3.00'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm group purchase'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.accepted, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('group delivery and refund pending remain per traveller', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          esimOrganizationProvider.overrideWith(
            (ref) => Stream.value(
              const EsimOrganization({
                'groups': [
                  {
                    'group_label': 'Trip',
                    'batch_id': 'batch',
                    'state': 'partial',
                    'retail_total': 3,
                    'members': [
                      {
                        'traveller_label': 'Alex',
                        'delivery_state': 'completed',
                        'reserved_amount': 0,
                        'charged_amount': 1.5,
                        'released_amount': 0,
                        'refunded_amount': 0,
                        'refund_pending': true,
                      },
                      {
                        'traveller_label': 'Sam',
                        'delivery_state': 'reconciling',
                        'reserved_amount': 1.5,
                        'charged_amount': 0,
                        'released_amount': 0,
                        'refunded_amount': 0,
                      },
                    ],
                  },
                ],
              }),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: EsimGroupPanel())),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Trip • partial'), findsOneWidget);
    expect(find.text('Sam • reconciling'), findsOneWidget);
    expect(find.textContaining('Refund pending'), findsOneWidget);
  });
  testWidgets(
    'customer help separates service suspension, automation, refund and group states',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: EsimHelpScreen()));
      expect(find.text('Suspend versus expiry'), findsOneWidget);
      expect(
        find.text('Traveller groups and partial delivery'),
        findsOneWidget,
      );
    },
  );
  testWidgets('traveller checkout hides typed labels after sign-out', (
    t,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimGroupRepositoryProvider.overrideWithValue(GroupFixture()),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: EsimGroupCheckoutScreen(
            plan: EsimPlan(
              id: 'A',
              name: 'Oman',
              dataAmountMB: 1024,
              durationDays: 7,
              priceUsd: 1.5,
              providerName: 'esimaccess',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Private trip');
    (c.read(authControllerProvider.notifier) as AuthFixture).leave();
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text('Sign in again to manage traveller purchases.'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('label editor hides private fields after sign-out', (t) async {
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(AuthFixture.new),
        esimGroupRepositoryProvider.overrideWithValue(GroupFixture()),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(
            body: EsimLabelEditor(
              profileId: 'p',
              label: 'Private traveller',
              group: 'Private trip',
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    (c.read(authControllerProvider.notifier) as AuthFixture).leave();
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Session changed'), findsOneWidget);
  });
}
