/// The filter sheet, driven the way a thumb drives it.
///
/// The model tests already pin what a given [CompareFilters] sends. These pin
/// the step before that: that tapping a mode chip actually produces the filter
/// state the model tests assume, and that the query the repository receives
/// changes accordingly. A mode selector whose chips look right but write the
/// wrong field is invisible to a model test and obvious to a user.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/affiliate_click_result.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_plan.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_compare_controller.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_filter_sheet.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

/// Returns France's real ladders, so a chip the test taps is one the live
/// catalogue actually sells.
class _FakeEsimRepository implements EsimRepository {
  CompareFilters? lastFilters;

  @override
  Future<CompareBounds> compareFilterBounds(String countryIsoCode) async =>
      const CompareBounds(
        durations: [1, 3, 5, 7, 10, 15, 30, 60, 90, 180],
        dataMb: [1000, 2000, 3000, 5000, 10000, 20000, 50000, 100000],
        minPriceUsd: 1.52,
        maxPriceUsd: 336.34,
        hasUnlimited: true,
      );

  @override
  Future<List<CompareOffer>> compareOffers(
    String countryIsoCode, {
    CompareFilters filters = const CompareFilters(),
    int limit = 60,
    int offset = 0,
  }) async {
    lastFilters = filters;
    return const [];
  }

  @override
  Future<AffiliateClickResult> recordAffiliateClick(String offerId,
          {String? countryCode}) async =>
      const AffiliateClickResult(success: false);

  @override
  Future<List<EsimPlan>> getPlans(String countryIsoCode) async => const [];

  @override
  Future<bool> validatePlanPurchase(String planId, {int quantity = 1}) async =>
      false;

  @override
  Future<String> requestPurchase(String offerId, {int quantity = 1}) async => '';

  @override
  Future<List<UserEsim>> getUserEsims() async => const [];

  @override
  Future<List<EsimOrder>> getOrderHistory() async => const [];

  @override
  Stream<EsimOrder?> watchOrder(String orderId) => const Stream.empty();
}

void main() {
  late _FakeEsimRepository repo;
  late ProviderContainer container;

  Future<void> pumpSheet(
    WidgetTester tester, {
    String countryIsoCode = 'FR',
    String? countryName,
  }) async {
    // The sheet is five sections tall. On the 800x600 default surface the
    // lower ones sit off-screen and a tap silently misses.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repo = _FakeEsimRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [esimRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return Scaffold(
                body: CompareFilterSheet(
                  countryIsoCode: countryIsoCode,
                  countryName: countryName,
                ),
              );
            },
          ),
        ),
      ),
    );
    // Let the bounds future resolve so the mode chips appear.
    await tester.pumpAndSettle();
  }

  CompareFilters filters() => container.read(esimCompareFiltersProvider);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('validity offers All, Range and Pick days', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Range'), findsWidgets);
    expect(find.text('Pick days'), findsOneWidget);

    await tap(tester, find.text('Pick days'));

    expect(filters().validityMode, RangeFilterMode.exact);
    // The chips are the catalogue's real durations, not a hard-coded ladder.
    expect(find.widgetWithText(ChoiceChip, '180 days'), findsOneWidget);

    await tap(tester, find.widgetWithText(ChoiceChip, '3 days'));
    await tap(tester, find.widgetWithText(ChoiceChip, '7 days'));

    expect(filters().daysExact, [3, 7]);
    expect(filters().wireDaysExact, [3, 7]);
    expect(filters().activeCount, 1);
  });

  testWidgets('switching validity mode drops the other mode\'s answers',
      (tester) async {
    await pumpSheet(tester);

    await tap(tester, find.text('Pick days'));
    await tap(tester, find.widgetWithText(ChoiceChip, '7 days'));
    expect(filters().daysExact, [7]);

    // Leaving the picks behind would let a hidden filter narrow the list while
    // the sheet shows a slider that says otherwise.
    await tap(tester, find.text('Range').first);

    expect(filters().daysExact, isEmpty);
    expect(filters().wireDaysExact, isNull);
    expect(filters().activeCount, 0);
  });

  testWidgets('data offers Unlimited as a mode, and no stray switch',
      (tester) async {
    await pumpSheet(tester);

    // The old ambiguous control was a SwitchListTile reading "Unlimited" while
    // sitting beside a Speed section listing Unlimited Lite/Essential/Plus.
    expect(find.byType(SwitchListTile), findsNothing);

    await tap(tester, find.text('Unlimited'));

    expect(filters().dataMode, DataFilterMode.unlimited);
    expect(filters().wireUnlimitedOnly, isTrue);
    expect(filters().wireMinDataMb, isNull);
  });

  testWidgets('data sizes are drawn from the catalogue in 1000-MB GB',
      (tester) async {
    await pumpSheet(tester);

    await tap(tester, find.text('Pick sizes'));

    // 1000 MB is the "1 GB" bundle. A 1024 divisor labelled it 0.98 GB and a
    // 1024 chip asked for a size the catalogue does not stock.
    expect(find.widgetWithText(ChoiceChip, '1 GB'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '100 GB'), findsOneWidget);

    await tap(tester, find.widgetWithText(ChoiceChip, '3 GB'));

    expect(filters().dataExactMb, [3000]);
    expect(filters().wireDataExactMb, [3000, 3072]);
  });

  testWidgets('an empty price box stays null and is not read as zero',
      (tester) async {
    await pumpSheet(tester);

    // Two "Range" chips on screen (validity and price); the price one is last.
    await tap(tester, find.text('Range').last);

    expect(filters().priceRangeOn, isTrue);
    // Selected but empty: no bound either side, and no badge on the pill.
    expect(filters().wireMinPriceUsd, isNull);
    expect(filters().wireMaxPriceUsd, isNull);
    expect(filters().activeCount, 0);

    await tester.enterText(find.byType(TextField).last, '25');
    // Typing is debounced so a three-digit price is one query, not three.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(filters().maxPriceUsd, 25);
    expect(filters().wireMaxPriceUsd, 25);
    // The minimum was left blank: still null, never 0.
    expect(filters().wireMinPriceUsd, isNull);
    expect(filters().activeCount, 1);
  });

  testWidgets(
      'speed choices are hidden until Unlimited is selected, explain exact speed, and clear on mode switch',
      (tester) async {
    await pumpSheet(tester);

    // 1. By default (dataMode == All), the SPEED section is not rendered.
    expect(find.text('SPEED'), findsNothing);
    expect(find.textContaining('512 kb/s'), findsNothing);
    expect(find.text('Fixed data'), findsNothing);

    // 2. Tapping "Unlimited" renders the SPEED section with direct explanations.
    await tap(tester, find.text('Unlimited'));
    expect(find.text('SPEED'), findsOneWidget);
    expect(
        find.widgetWithText(ChoiceChip, 'Lite – 1 GB at Max speed then throttle to 512 kb/s'),
        findsOneWidget);
    expect(
        find.widgetWithText(ChoiceChip, 'Essential – 2 GB at Max speed then throttle to 1 Mb/s'),
        findsOneWidget);
    expect(
        find.widgetWithText(ChoiceChip, 'Plus – 3 GB at Max speed then throttle to 1 Mb/s'),
        findsOneWidget);
    expect(find.text('Fixed data'), findsNothing);

    // 3. Selecting a speed tier applies the filter.
    await tap(tester,
        find.widgetWithText(ChoiceChip, 'Lite – 1 GB at Max speed then throttle to 512 kb/s'));
    expect(filters().speedTiers, ['lite']);
    expect(filters().wireSpeedTiers, ['lite']);

    // 4. Switching away from Unlimited hides the SPEED section and clears the filter.
    await tap(tester, find.text('Pick sizes'));
    expect(find.text('SPEED'), findsNothing);
    expect(filters().speedTiers, isNull);
    expect(filters().wireSpeedTiers, isNull);
  });

  testWidgets(
      'replaces Local coverage label with selected country only (e.g. Egypt only)',
      (tester) async {
    await pumpSheet(tester, countryIsoCode: 'EG', countryName: 'Egypt');

    expect(find.text('Egypt only'), findsOneWidget);
    expect(find.text('Local'), findsNothing);

    await tap(tester, find.text('Egypt only'));
    expect(filters().coverage, 'local');
  });

  testWidgets(
      'resolves country name from ISO code when countryName is omitted',
      (tester) async {
    await pumpSheet(tester, countryIsoCode: 'EG');

    expect(find.text('Egypt only'), findsOneWidget);
    expect(find.text('Local'), findsNothing);
  });
}
