import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/fx/money.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/widgets/country_rate_chip.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_card.dart';
import 'package:keep_sims/features/esim/presentation/widgets/compare_offer_details_sheet.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/features/wallet/model/wallet_model.dart';
import 'package:keep_sims/features/wallet/ui/gift_credit_sheet.dart';
import 'package:keep_sims/features/wallet/ui/refund_funds_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_liveness_result.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';

import 'rate_precision_test.dart' show omrDisplay;

class FixedDisplayFx extends FxController {
  FixedDisplayFx(this.context);
  final FxContext context;
  @override
  Future<FxContext> build() async => context;
}

class DisplayTestWallet extends WalletController {
  @override
  Future<WalletState> build() async =>
      const WalletState(wallet: Wallet(balance: 25), transactions: []);

  @override
  Future<Map<String, dynamic>> quoteRefund() async => {
    'eligible_amount': 25.0,
    'available_balance': 25.0,
  };
}

class DisplayTestHousehold extends HouseholdController {
  @override
  Future<HouseholdState> build() async =>
      const HouseholdState(members: [], invitations: [], memberships: []);
}

Widget displayApp(
  Widget child, {
  FxContext fx = omrDisplay,
  bool dark = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => ProviderScope(
  overrides: [fxControllerProvider.overrideWith(() => FixedDisplayFx(fx))],
  child: MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets(
    'upgrade displays the configured USD fee on the plan and action',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseServiceFeeUsdProvider.overrideWith((ref) async => 7.5),
            simLivenessValidationProvider(
              phoneNumber: '+96812345678',
            ).overrideWith(
              (ref) async => const SimLivenessResult(
                isActive: true,
                carrierStatus: 'active',
              ),
            ),
          ],
          child: displayApp(
            const LineUpgradeSheet(
              simLine: SimLine(
                id: 'line',
                userId: 'user',
                phoneNumber: '+96812345678',
                protectionTier: 'free',
              ),
              initialPlan: 'standard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$7.50'), findsNWidgets(2));
      expect(find.text('≈ OMR 2.888'), findsOneWidget);
      expect(find.text(r'Continue to Payment • $7.50 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final refund in [false, true]) {
    testWidgets(
      '${refund ? 'refund' : 'gift'} previews preserve USD typing and commit labels',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              walletControllerProvider.overrideWith(DisplayTestWallet.new),
              householdControllerProvider.overrideWith(
                DisplayTestHousehold.new,
              ),
            ],
            child: displayApp(
              refund ? const RefundFundsSheet() : const GiftCreditSheet(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final input = find.byType(TextField).at(refund ? 0 : 1);
        await tester.enterText(input, '10');
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).controller!.text, '10');
        expect(find.text('≈ OMR 3.850'), findsOneWidget);
        expect(
          find.text(refund ? r'Request $10.00 USD refund' : r'Send $10.00 USD'),
          findsOneWidget,
        );
        if (refund) {
          await tester.tap(find.text('MAX'));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(input).controller!.text, '25.00');
          expect(find.text('≈ OMR 9.625'), findsOneWidget);
          expect(find.text(r'Request $25.00 USD refund'), findsOneWidget);
        }
        await tester.enterText(input, '');
        await tester.pumpAndSettle();
        expect(find.textContaining('≈'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('eSIM details wrap a long currency code at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const offer = CompareOffer(
      offerKind: 'affiliate',
      offerId: 'offer',
      sourceCode: 'partner',
      sourceName: 'Partner',
      title: 'Data offer',
      countries: ['OM'],
      countryCount: 1,
      dataAmountMb: 1024,
      isUnlimited: false,
      durationDays: 30,
      priceUsd: 3,
      action: OfferAction.openPartner,
      priceIsStale: false,
      disclosureRequired: false,
    );
    await tester.pumpWidget(
      displayApp(
        CompareOfferDetailsSheet(offer: offer, onBuyPressed: () {}),
        fx: omrDisplay.copyWith(symbol: 'LONGCURRENCY'),
        scale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$3.00'), findsOneWidget);
    expect(find.text('≈ LONGCURRENCY 1.155'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final stale in [false, true]) {
    testWidgets(
      'eSIM ${stale ? 'stale price hides estimates' : 'USD and local price components match'}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final offer = CompareOffer(
          offerKind: 'affiliate',
          offerId: 'offer',
          sourceCode: 'partner',
          sourceName: 'Partner',
          title: 'Data offer',
          countries: const ['OM'],
          countryCount: 1,
          dataAmountMb: 1024,
          isUnlimited: false,
          durationDays: 30,
          priceUsd: 3,
          listPriceUsd: 6,
          pricePerGbUsd: 0.04,
          action: OfferAction.openPartner,
          priceIsStale: stale,
          disclosureRequired: false,
        );
        await tester.pumpWidget(
          displayApp(CompareOfferCard(offer: offer, onPressed: () {})),
        );
        await tester.pumpAndSettle();
        if (stale) {
          expect(find.textContaining('≈'), findsNothing);
          expect(find.text(r'$3.00'), findsNothing);
        } else {
          expect(find.text(r'$3.00'), findsOneWidget);
          expect(find.text('≈ OMR 1.155'), findsOneWidget);
          expect(find.text('≈ OMR 2.310'), findsOneWidget);
          expect(find.textContaining('≈ OMR 0.015'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'USD amount previews react to typing, clearing and programmatic MAX',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        displayApp(
          Column(
            children: [
              TextField(controller: controller),
              ApproxLocalAmountPreview(controller),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10');
      await tester.pumpAndSettle();
      expect(find.text('≈ OMR 3.850'), findsOneWidget);
      controller.text = '25.00';
      await tester.pump();
      expect(find.text('≈ OMR 9.625'), findsOneWidget);
      expect(controller.text, '25.00');
      for (final text in ['', 'abc', '-1', 'NaN', 'Infinity', '0']) {
        controller.text = text;
        await tester.pump();
        expect(find.byType(ApproxLocalText), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'PayPal presets keep USD selection and input with local estimates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        displayApp(const PayPalCheckoutScreen(paymentKind: 'deposit')),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$5'), findsOneWidget);
      expect(find.text('≈ OMR 1.925'), findsOneWidget);
      await tester.tap(find.text(r'$20'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '20.00');
      expect(find.text('≈ OMR 7.700'), findsNWidgets(2));
      expect(find.text('Refill Wallet with PayPal'), findsOneWidget);
      expect(find.text(r'$20.00 USD'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '2');
      await tester.pumpAndSettle();
      expect(field.controller!.text, '2');
      expect(find.text(r'$5.00 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  const rate = CallRate(
    id: 'micro',
    countryCode: 'OM',
    countryName: 'Oman',
    phonePrefix: '+968',
    costPerMinute: 0.01,
    ratePerMinute: 0.012,
  );
  for (final dark in [false, true]) {
    testWidgets(
      'rate chip preserves both USD units at narrow width (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          displayApp(
            CountryRateChip(rate: rate, isSelected: false, onTap: () {}),
            dark: dark,
            scale: 1.5,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(r'$0.012/min • $0.0002/s'), findsOneWidget);
        expect(find.text('≈ OMR 0.0046/min'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('RTL estimates and charge explanation fit without hiding USD', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      displayApp(
        const Column(
          children: [Text(r'$10.00'), ApproxLocalText(10), FxChargeNotice()],
        ),
        locale: const Locale('ar'),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'$10.00'), findsOneWidget);
    expect(find.text('≈ OMR 3.850'), findsOneWidget);
    expect(find.textContaining('بالدولار الأمريكي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
