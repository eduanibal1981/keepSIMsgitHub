import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_recharge_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_recharge_screen.dart';
import 'esim_installation_fixtures.dart';

const offer = EsimRechargeOffer(
  id: 'TOPUP_A',
  title: 'Fixture recharge',
  total: 1.73,
  allowanceBytes: 1073741824,
  duration: 7,
  unit: 'DAY',
  addsAllowance: true,
  quoteSupported: true,
);
EsimRechargeQuote quote({
  bool enabled = true,
  String balance = 'sufficient',
  DateTime? expires,
}) => EsimRechargeQuote(
  status: 'QUOTED',
  id: 'quote',
  ownerId: 'fixture-owner',
  payerId: 'fixture-owner',
  profileId: 'fixture-profile',
  acceptanceKey: 'fixture-key',
  acceptanceEnabled: enabled,
  offer: offer,
  balanceState: balance,
  expiresAt: expires ?? DateTime.now().add(const Duration(minutes: 2)),
);

class _Bio extends Fake implements BiometricAuthService {}

class _Guard extends PaymentAuthGuard {
  _Guard() : super(_Bio());
  Completer<BiometricResult>? pending;
  int calls = 0;
  @override
  Future<BiometricResult> confirmPayment({
    required String reason,
    Duration gracePeriod = const Duration(seconds: 60),
  }) async {
    calls++;
    return pending?.future ?? BiometricResult.success;
  }
}

class _Repo extends Fake implements EsimRepository {
  int accepts = 0;
  Completer<EsimOperationAcceptance>? pending;
  Map<String, Object>? bought;
  @override
  Future<EsimOperationAcceptance> acceptTopup(String id, String key) async {
    accepts++;
    expect(id, 'quote');
    expect(key, 'fixture-key');
    return pending?.future ??
        const EsimOperationAcceptance('ACCEPTED', 'fixture-order');
  }

  @override
  Future<List<EsimOperation>> getOperationHistory(String id) async =>
      accepts == 0
      ? []
      : [
          const EsimOperation(
            id: 'fixture-order',
            kind: 'fixed_recharge',
            status: 'submitted',
            financialState: 'pending',
            total: 1.73,
            packageId: 'TOPUP_A',
            fundsReserved: true,
          ),
        ];
  @override
  Future<EsimRechargeDiscovery> discoverTopups(String id) async =>
      const EsimRechargeDiscovery(
        status: 'READY',
        offers: [offer],
        version: 'version',
      );
  @override
  Future<EsimRechargeQuote> quoteTopup(
    String a,
    String b,
    String c,
    double d,
  ) async => quote();
  @override
  Future<String> requestPurchaseIntent(
    String offerId, {
    int quantity = 1,
    required String requestKey,
    required double reviewedTotal,
    required String expectedUserId,
  }) async {
    bought = {
      'offer': offerId,
      'key': requestKey,
      'amount': reviewedTotal,
      'actor': expectedUserId,
    };
    return 'new-order';
  }
}

void main() {
  Future<(ProviderContainer, _Repo, _Guard)> setup() async {
    final r = _Repo(), g = _Guard();
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => InstallationAuthFixture()),
        esimRepositoryProvider.overrideWithValue(r),
        paymentAuthGuardProvider.overrideWithValue(g),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);
    final sub = c.listen(esimMoneyActionsProvider, (_, _) {});
    addTearDown(sub.close);
    return (c, r, g);
  }

  test(
    'disabled, expired and insufficient quotes never invoke payment or acceptance',
    () async {
      final (c, r, g) = await setup();
      final actions = c.read(esimMoneyActionsProvider);
      expect(
        (await actions.accept(quote(enabled: false))).status,
        'RECHARGE_DISABLED',
      );
      expect(
        (await actions.accept(quote(balance: 'unknown'))).status,
        'BALANCE_UNAVAILABLE',
      );
      expect(
        (await actions.accept(
          quote(expires: DateTime.now().subtract(const Duration(seconds: 1))),
        )).status,
        'STALE_QUOTE',
      );
      expect(r.accepts, 0);
      expect(g.calls, 0);
    },
  );
  test(
    'duplicate UI confirmations share one payment authorization and one acceptance request',
    () async {
      final (c, r, g) = await setup();
      g.pending = Completer<BiometricResult>();
      final actions = c.read(esimMoneyActionsProvider);
      final a = actions.accept(quote()), b = actions.accept(quote());
      await Future<void>.delayed(Duration.zero);
      g.pending!.complete(BiometricResult.success);
      expect((await a).orderId, 'fixture-order');
      expect((await b).orderId, 'fixture-order');
      expect(r.accepts, 1);
      expect(g.calls, 1);
    },
  );
  test(
    'account switch during payment authorization cannot spend the new account wallet',
    () async {
      final (c, r, g) = await setup();
      g.pending = Completer<BiometricResult>();
      final future = c.read(esimMoneyActionsProvider).accept(quote());
      (c.read(authControllerProvider.notifier) as InstallationAuthFixture)
          .signInAs('other');
      await Future<void>.delayed(Duration.zero);
      g.pending!.complete(BiometricResult.success);
      expect((await future).accepted, isFalse);
      expect(r.accepts, 0);
    },
  );
  test(
    'a pending old-owner server result is not exposed after an account change',
    () async {
      final (c, r, g) = await setup();
      r.pending = Completer<EsimOperationAcceptance>();
      final future = c.read(esimMoneyActionsProvider).accept(quote());
      await Future<void>.delayed(Duration.zero);
      expect(r.accepts, 1);
      (c.read(authControllerProvider.notifier) as InstallationAuthFixture)
          .signInAs('other');
      await Future<void>.delayed(Duration.zero);
      r.pending!.complete(
        const EsimOperationAcceptance('ACCEPTED', 'private-order'),
      );
      final result = await future;
      expect(result.orderId, isNull);
      expect(result.status, 'ACCOUNT_CHANGED');
    },
  );
  test(
    'new-profile checkout carries the stable retry key, actor and reviewed amount',
    () async {
      final (c, r, g) = await setup();
      expect(
        await c
            .read(esimMoneyActionsProvider)
            .purchase('BASE_FIXED', 'same-intent', 1.73),
        'new-order',
      );
      expect(r.bought, {
        'offer': 'BASE_FIXED',
        'key': 'same-intent',
        'amount': 1.73,
        'actor': 'fixture-owner',
      });
    },
  );
  test(
    'receipts distinguish a reservation release, a genuine refund and unresolved legacy money',
    () {
      EsimOperation row(String state, {bool held = false}) => EsimOperation(
        id: 'id',
        kind: 'fixed_recharge',
        status: 'failed',
        financialState: state,
        total: 1.73,
        packageId: 'P',
        fundsReserved: held,
      );
      expect(
        row('released').financialLabel,
        contains('No charge was captured'),
      );
      expect(row('refunded').financialLabel, contains('original payer'));
      expect(row('pending').financialLabel, contains('No refund is confirmed'));
      expect(
        row('pending', held: true).financialLabel,
        contains('remain reserved'),
      );
    },
  );
  testWidgets(
    'enabled quote still needs explicit confirmation and shows the reserved-operation receipt',
    (t) async {
      final r = _Repo(), g = _Guard();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => InstallationAuthFixture(),
            ),
            userEsimsControllerProvider.overrideWith(
              () => InstallationProfilesFixture(installationFixture()),
            ),
            esimRepositoryProvider.overrideWithValue(r),
            paymentAuthGuardProvider.overrideWithValue(g),
          ],
          child: const MaterialApp(
            home: EsimRechargeScreen(profileId: 'fixture-profile'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Preview quote'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Confirm recharge • USD 1.73'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(r.accepts, 0);
      await t.tap(find.text('Confirm recharge • USD 1.73'));
      await t.pumpAndSettle();
      expect(find.text('Confirm this recharge'), findsOneWidget);
      expect(r.accepts, 0);
      await t.tap(find.text('Confirm recharge'));
      await t.pumpAndSettle();
      expect(r.accepts, 1);
      await t.scrollUntilVisible(
        find.text('Receipt ID: fixture-order'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Funds remain reserved'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
}
