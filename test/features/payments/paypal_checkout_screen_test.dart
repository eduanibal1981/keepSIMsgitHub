import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

void main() {
  group('PayPalCheckoutScreen & Quote Parity Unit Tests', () {
    testWidgets('renders payment title and secure pay button correctly', (widgetTester) async {
      await widgetTester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PayPalCheckoutScreen(
              initialAmount: 15.00,
              paymentReason: 'Manual Refill Top-up',
              paymentKind: 'deposit',
            ),
          ),
        ),
      );

      await widgetTester.pump();

      expect(find.text('Refill Your Wallet'), findsWidgets);
      expect(find.textContaining('Manual Refill Top-up'), findsOneWidget);
      expect(find.text('Refill Wallet with PayPal'), findsOneWidget);
    });

    testWidgets('renders plan payment kind correctly', (widgetTester) async {
      await widgetTester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PayPalCheckoutScreen(
              initialAmount: 2.50,
              paymentReason: 'Annual Plan Renewal',
              paymentKind: 'plan',
              plan: 'standard',
              simLineId: 'line_123_abc',
            ),
          ),
        ),
      );

      await widgetTester.pump();

      expect(find.text('Annual Plan Renewal'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
    });

    test(r'Standard plan PayPal grossUpTotal matches SQL calculation ($3.10)', () {
      final grossUp = RefillPricing.grossUpTotal(
        net: 2.50,
        gatewayFeePercentage: 3.4,
        gatewayFeeFixed: 0.49,
      );
      expect(grossUp, 3.10);
    });

    // Under the Pay-Per-Refill architecture, Premium initial charge covers
    // 1st qualifying refill ($4.30) + $2.50 annual fee = $6.80 net,
    // grossed up to $7.55 for PayPal. Future refills are billed from wallet as due.
    test(r'Premium plan initial charge for Orange Egypt (override $4.30 + $2.50 fee) matches SQL ($7.55)', () {
      final perRefill = RefillPricing.premiumRefillPrice(
        minimumTopupAmount: 3.59,
        appFeePercent: 3.0,
        premiumMarginPercent: 5.0,
        premiumMarginPerRefillUsd: 0.324,
        inappPricingOverride: 4.30,
      );
      expect(perRefill, 4.30);

      final total = RefillPricing.premiumYearlyTotal(
        baseServiceFeeUsd: 2.50,
        minimumTopupAmount: 3.59,
        inactivityLimitDays: 90,
        appFeePercent: 3.0,
        premiumMarginPercent: 5.0,
        premiumMarginPerRefillUsd: 0.324,
        gatewayFeePercentage: 3.4,
        gatewayFeeFixed: 0.49,
        inappPricingOverride: 4.30,
      );
      expect(total, 7.55);
    });
  });
}
