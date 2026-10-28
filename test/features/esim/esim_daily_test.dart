import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_daily_selection.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_daily_controller.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_daily_quote_panel.dart';
import 'esim_installation_fixtures.dart';

EsimRechargeQuote dailyQuote({
  String owner = 'fixture-owner',
  String? profile,
  int days = 5,
  bool enabled = false,
}) => EsimRechargeQuote(
  status: 'QUOTED',
  id: 'daily-quote',
  ownerId: owner,
  payerId: owner,
  profileId: profile,
  action: profile == null ? 'daily_purchase' : 'daily_extension',
  acceptanceEnabled: enabled,
  balanceState: 'sufficient',
  expiresAt: DateTime.now().add(const Duration(minutes: 2)),
  offer: EsimRechargeOffer(
    id: 'DAY_A',
    title: 'Daily fixture',
    total: 3.7,
    allowanceBytes: 1073741824,
    duration: days,
    unit: 'DAY',
    addsAllowance: false,
    quoteSupported: true,
    dataType: 2,
  ),
);

class DailyRepo extends Fake implements EsimRepository {
  int calls = 0;
  EsimDailySelection? selection;
  Completer<EsimRechargeQuote>? pending;
  String status = 'DURATION_PRICE_UNAVAILABLE';
  @override
  Future<EsimRechargeQuote> quoteDaily(EsimDailySelection selection) async {
    calls++;
    this.selection = selection;
    return pending?.future ?? EsimRechargeQuote(status: status);
  }
}

void main() {
  test(
    'duration intent accepts contract endpoints and rejects fractional/out-of-range/unsupported quantity',
    () {
      expect(const EsimDailySelection(packageId: 'DAY_A', days: 1).valid, true);
      expect(
        const EsimDailySelection(packageId: 'DAY_A', days: 365).valid,
        true,
      );
      for (final n in [0, 366, -1]) {
        expect(EsimDailySelection(packageId: 'DAY_A', days: n).valid, false);
      }
      expect(
        const EsimDailySelection(
          packageId: 'DAY_A',
          days: 5,
          quantity: 4,
        ).valid,
        false,
      );
      expect(
        const EsimDailySelection(
          packageId: 'DAY_A',
          days: 5,
          profileId: 'profile',
        ).valid,
        false,
      );
    },
  );
  test(
    'daily profile shows daily allowance without treating aggregate byte totals as today’s balance',
    () {
      final profile = installationFixture({
        'catalogue_details': {
          'plan_type': 'daily_throttled',
          'allowance_bytes': '1073741824',
        },
        'data_total_bytes': 5368709120,
        'data_remaining_bytes': 2147483648,
      });
      expect(profile.usageLabel, contains('1 GB/day'));
      expect(profile.usageLabel, contains('not provided'));
      expect(profile.usageLabel, isNot(contains('2 GB / 5 GB')));
    },
  );
  test('daily slowing, cutoff and unlimited remain distinct', () {
    for (final (type, label) in [
      (2, 'Speed reduces'),
      (3, 'Data stops'),
      (4, 'Unlimited'),
    ]) {
      final o = EsimRechargeOffer.fromJson({
        'package_id': 'DAY_A',
        'title': 'Daily',
        'retail_total': 3.7,
        'allowance_bytes': '1073741824',
        'duration_value': 5,
        'duration_unit': 'DAY',
        'effect': 'validity_only',
        'data_type': type,
        'quote_supported': true,
      });
      expect(o.behaviorLabel, contains(label));
      expect(o.effectLabel, contains('does not stack'));
    }
  });
  test(
    'quote controller denies late cross-account and mismatched duration responses',
    () async {
      final repo = DailyRepo()..pending = Completer<EsimRechargeQuote>();
      final auth = InstallationAuthFixture();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          esimRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      const selection = EsimDailySelection(packageId: 'DAY_A', days: 5);
      final subscription = container.listen(
        esimDailyQuoteProvider(selection),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final future = container.read(esimDailyQuoteProvider(selection).future);
      repo.pending!.complete(dailyQuote(days: 7));
      expect((await future).status, 'QUOTE_UNAVAILABLE');
    },
  );
  Future<(ProviderContainer, DailyRepo)> panel(
    WidgetTester tester, {
    String? profile,
  }) async {
    final repo = DailyRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => InstallationAuthFixture()),
          esimRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EsimDailyQuotePanel(
                packageId: 'DAY_A',
                profileId: profile,
                offerVersion: profile == null ? null : 'version',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      ProviderScope.containerOf(
        tester.element(find.byType(EsimDailyQuotePanel)),
      ),
      repo,
    );
  }

  testWidgets(
    'invalid day input sends no quote and unavailable pricing is explicit',
    (tester) async {
      final (_, repo) = await panel(tester);
      await tester.enterText(
        find.byKey(const ValueKey('esim-daily-days')),
        '366',
      );
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Get total quote'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('esim-daily-days')),
        '5',
      );
      await tester.pump();
      await tester.tap(find.text('Get total quote'));
      await tester.pumpAndSettle();
      expect(repo.selection!.days, 5);
      expect(find.textContaining('Verified pricing'), findsOneWidget);
      expect(find.text('Confirm reviewed total'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'extension shows no-speed-restoration explanation and does not request funds by browsing',
    (tester) async {
      final (_, repo) = await panel(tester, profile: 'fixture-profile');
      expect(find.textContaining('Today’s high-speed'), findsOneWidget);
      expect(find.text('Daily reset time: Not provided'), findsOneWidget);
      expect(repo.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'full server quote is shown with payment disabled, then account switch hides it',
    (tester) async {
      final (container, repo) = await panel(tester);
      repo.pending = Completer<EsimRechargeQuote>();
      await tester.enterText(
        find.byKey(const ValueKey('esim-daily-days')),
        '5',
      );
      await tester.pump();
      await tester.tap(find.text('Get total quote'));
      await tester.pump();
      repo.pending!.complete(dailyQuote());
      await tester.pumpAndSettle();
      expect(find.text('5 days • Total USD 3.70'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm reviewed total'),
            )
            .onPressed,
        isNull,
      );
      (container.read(authControllerProvider.notifier)
              as InstallationAuthFixture)
          .signInAs('other');
      await tester.pumpAndSettle();
      expect(find.text('5 days • Total USD 3.70'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
