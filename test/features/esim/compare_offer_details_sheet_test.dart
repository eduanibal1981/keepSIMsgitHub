import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_card.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_details_sheet.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

void main() {
  const sampleOffer = CompareOffer(
    offerKind: 'resale',
    offerId: 'test-bundle-1',
    sourceCode: 'esimaccess',
    sourceName: 'eSIM Access',
    title: 'Global Explorer 1GB',
    countries: ['EG', 'FR', 'US', 'DE'],
    countryCount: 4,
    dataAmountMb: 1024,
    isUnlimited: false,
    durationDays: 30,
    priceUsd: 7.98,
    bundleGroup: 'Fixed Bundle',
    catalogueDetails: {'plan_type': 'total', 'allowance_bytes': '1073741824'},
    action: OfferAction.buyInApp,
    priceIsStale: false,
    disclosureRequired: false,
  );

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 380, child: child)),
        ),
      ),
    );
  }

  testWidgets('CompareOfferCard renders More details label and country count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool buyPressed = false;
    await tester.pumpWidget(
      createTestWidget(
        child: CompareOfferCard(
          offer: sampleOffer,
          onPressed: () => buyPressed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('More details'), findsOneWidget);
    expect(find.text('4 countries'), findsOneWidget);
    expect(find.text('Buy Plan • \$7.98'), findsOneWidget);

    // Tapping More details opens CompareOfferDetailsSheet
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();

    expect(find.byType(CompareOfferDetailsSheet), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Countries (4)'), findsOneWidget);

    // Bottom Buy Plan button inside the sheet
    final sheetBuyBtn = find.descendant(
      of: find.byType(CompareOfferDetailsSheet),
      matching: find.widgetWithText(ElevatedButton, 'Buy Plan • \$7.98'),
    );
    expect(sheetBuyBtn, findsOneWidget);
    await tester.tap(sheetBuyBtn);
    await tester.pumpAndSettle();

    expect(buyPressed, isTrue);
  });

  testWidgets(
    'CompareOfferDetailsSheet displays professional details and filters countries',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool buyPressed = false;
      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CompareOfferDetailsSheet.show(
                context,
                offer: sampleOffer,
                onBuyPressed: () => buyPressed = true,
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // 1. Header & Summary metric card
      expect(find.text('Global Explorer 1GB'), findsOneWidget);
      expect(find.text('eSIM Access'), findsOneWidget);
      expect(find.text('Total data bundle'), findsWidgets);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('1 GB'), findsOneWidget);
      expect(find.text('\$7.98'), findsOneWidget);

      // 2. Details tab content
      expect(find.text('Supported networks'), findsOneWidget);
      expect(find.text('Plan type'), findsOneWidget);
      expect(find.text('Allowance policy'), findsOneWidget);
      expect(find.text('Activation'), findsOneWidget);
      expect(find.text('Not provided'), findsWidgets);

      // 3. Switch to Countries tab
      await tester.tap(find.text('Countries (4)'));
      await tester.pumpAndSettle();

      // Verify countries are listed
      expect(find.text('Egypt'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('4G / 5G'), findsNothing);
      expect(find.text('Not provided'), findsWidgets);

      // 4. Test Search filter in Countries tab
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Egypt');
      await tester.pumpAndSettle();

      expect(find.text('EG'), findsOneWidget);
      expect(find.text('FR'), findsNothing);
      expect(find.text('DE'), findsNothing);

      // Search by code
      await tester.enterText(searchField, 'FR');
      await tester.pumpAndSettle();

      expect(find.text('France'), findsOneWidget);
      expect(find.text('EG'), findsNothing);
      expect(find.text('DE'), findsNothing);

      // Search with no results
      await tester.enterText(searchField, 'NonExistentPlace');
      await tester.pumpAndSettle();

      expect(find.text('No countries match your search.'), findsOneWidget);

      // 5. Test Buy Plan CTA inside sheet
      final sheetCta = find.descendant(
        of: find.byType(CompareOfferDetailsSheet),
        matching: find.widgetWithText(ElevatedButton, 'Buy Plan • \$7.98'),
      );
      expect(sheetCta, findsOneWidget);
      await tester.tap(sheetCta);
      await tester.pumpAndSettle();

      expect(buyPressed, isTrue);
    },
  );

  testWidgets(
    'CompareOfferCard omits speed line and speed badge, details sheet retains speed policy',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const dayPassOffer = CompareOffer(
        offerKind: 'resale',
        offerId: 'test-daypass-1',
        sourceCode: 'esimaccess',
        sourceName: 'eSIM Access',
        title: 'Oman 1GB/day DayPass',
        countries: ['OM'],
        countryCount: 1,
        dataAmountMb: 1024,
        isUnlimited: false,
        catalogueDetails: {
          'plan_type': 'daily_throttled',
          'allowance_bytes': '1073741824',
          'fup_text': '384 kbps',
        },
        speedTierRaw: 'high-384 kbps',
        durationDays: 1,
        priceUsd: 5.07,
        bundleGroup: 'DayPass',
        action: OfferAction.buyInApp,
        priceIsStale: false,
        disclosureRequired: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          child: CompareOfferCard(offer: dayPassOffer, onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Verify speed badge ('high-384 kbps') is NOT rendered on the card
      expect(find.text('high-384 kbps'), findsNothing);

      // Verify the speed line ('...then throttle to 384 kbps') is NOT rendered on the card
      expect(find.textContaining('then throttle to 384 kbps'), findsNothing);

      // Verify data amount and More details are rendered
      expect(find.text('1 GB/day'), findsOneWidget);
      expect(find.text('More details'), findsOneWidget);

      // Tapping More details opens the details sheet where speed policy is available
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();

      expect(find.byType(CompareOfferDetailsSheet), findsOneWidget);
      expect(find.text('Allowance policy'), findsOneWidget);
      expect(
        find.text('Speed slows after the daily allowance. FUP: 384 kbps'),
        findsOneWidget,
      );
    },
  );
}
