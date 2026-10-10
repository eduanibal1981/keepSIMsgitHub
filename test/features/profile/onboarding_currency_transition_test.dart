import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/profile/presentation/ui/onboarding_screen.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class OnboardingDisplayFx extends FxController {
  OnboardingDisplayFx({this.succeeds = true});
  final bool succeeds;
  final List<String> savedCodes = [];
  static const available = [
    FxCurrencyOption(code: 'USD', name: 'US Dollar', symbol: r'$'),
    FxCurrencyOption(
      code: 'OMR',
      name: 'Omani Rial',
      symbol: 'OMR',
      decimalDigits: 3,
    ),
  ];
  @override
  Future<FxContext> build() async => const FxContext(available: available);
  @override
  Future<bool> setDisplayCurrency(String code) async {
    savedCodes.add(code);
    if (!succeeds) return false;
    state = AsyncData(
      FxContext(
        currency: code,
        requestedCurrency: code,
        rate: 0.385,
        symbol: 'OMR',
        decimalDigits: 3,
        available: available,
        ageHours: 0,
      ),
    );
    return true;
  }
}

class NoNotificationChannels extends NotificationChannelsController {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}

class NoSimLines extends SimLinesController {
  @override
  Future<List<SimLine>> build() async => [];
}

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'currency transition ${succeeds ? 'saves and previews' : 'shows retryable failure'}',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fx = OnboardingDisplayFx(succeeds: succeeds);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fxControllerProvider.overrideWith(() => fx),
              supportedCountriesProvider.overrideWith(
                (ref) async => const [
                  Country(
                    id: 'eg',
                    name: 'Egypt',
                    isoCode: 'EG',
                    dialingCode: '+20',
                    currencyCode: 'EGP',
                  ),
                ],
              ),
              carriersForCountryProvider('eg').overrideWith(
                (ref) async => const [
                  Carrier(
                    id: 'carrier',
                    countryId: 'eg',
                    name: 'Test Carrier',
                    isSupported: true,
                  ),
                ],
              ),
              carrierRuleProvider('carrier').overrideWith(
                (ref) async => const CarrierRule(
                  id: 'rule',
                  carrierId: 'carrier',
                  ruleType: 'recharge',
                  inactivityLimitDays: 365,
                  gracePeriodDays: 30,
                  minimumTopupAmount: 1,
                  topupValidityDays: 365,
                  inappPricing: 1,
                  inappPricingCurrency: 'USD',
                ),
              ),
              paymentGatewayProvider(
                'paypal',
              ).overrideWith((ref) async => null),
              appFeePercentProvider.overrideWith((ref) async => 0),
              premiumMarginPercentProvider.overrideWith((ref) async => 0),
              premiumMarginPerRefillUsdProvider.overrideWith((ref) async => 0),
              baseServiceFeeUsdProvider.overrideWith((ref) async => 7.5),
              notificationChannelsControllerProvider.overrideWith(
                NoNotificationChannels.new,
              ),
              simLinesControllerProvider.overrideWith(NoSimLines.new),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: OnboardingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('onboarding-terms-checkbox')),
        );
        await tester.tap(
          find.byKey(const ValueKey('onboarding-terms-checkbox')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Display Test');
        final dropdown = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButton<String> &&
              widget.items!.any((item) => item.value == 'OMR'),
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Omani Rial (OMR)').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(fx.savedCodes, ['OMR']);
        if (succeeds) {
          expect(find.text('Select Protection Plan'), findsOneWidget);
          expect(find.text('≈ OMR 2.888'), findsOneWidget);
          expect(find.text(r'$7.50/yr'), findsOneWidget);
          final carrierDropdown = find.byType(DropdownButton<Carrier>);
          await tester.ensureVisible(carrierDropdown);
          await tester.tap(carrierDropdown);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Test Carrier').last);
          await tester.pumpAndSettle();
          expect(find.text(r'$8.50 USD'), findsOneWidget);
          // Ordinary estimates retain the existing floating-point rounding.
          expect(find.text('≈ OMR 3.272'), findsOneWidget);
        } else {
          expect(
            find.text("Couldn't save your display currency. Please try again."),
            findsOneWidget,
          );
          expect(find.text('Preferred Currency'), findsOneWidget);
        }
      },
    );
  }
}
