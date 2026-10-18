import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

void main() {
  group('PayPalCheckoutScreen & Quote Parity Unit Tests', () {
    testWidgets('renders payment title and secure pay button correctly', (
      widgetTester,
    ) async {
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

    test(
      r'Standard plan PayPal grossUpTotal matches SQL calculation ($3.10)',
      () {
        final grossUp = RefillPricing.grossUpTotal(
          net: 2.50,
          gatewayFeePercentage: 3.4,
          gatewayFeeFixed: 0.49,
        );
        expect(grossUp, 3.10);
      },
    );

    test('Premium payment uses a validated server breakdown', () {
      final quote = PremiumInitialBreakdown.fromJson({
        'currency': 'USD',
        'annual_fee_usd': 7.50,
        'first_refill_cost_usd': 4.30,
        'total_charge_usd': 11.80,
        'upgrade_credit_usd': 0,
        'full_annual_fee_usd': 7.50,
        'refill_interval_days': 76,
        'is_upgrade': false,
      });
      expect(quote.totalDueNowUsd, 11.80);
      expect(quote.firstRefillUsd, 4.30);
      expect(
        RefillPricing.grossUpTotal(
          net: quote.totalDueNowUsd,
          gatewayFeePercentage: 3.4,
          gatewayFeeFixed: 0.49,
        ),
        12.72,
      );
    });
  });
}
