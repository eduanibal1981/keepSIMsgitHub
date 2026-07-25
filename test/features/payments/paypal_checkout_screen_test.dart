import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/payments/presentation/screens/paypal_checkout_screen.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

void main() {
  group('PayPalCheckoutScreen Unit Tests', () {
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

      expect(find.text('PayPal Checkout'), findsOneWidget);
      expect(find.text('Manual Refill Top-up'), findsOneWidget);
      expect(find.text('\$15.00'), findsOneWidget);
      expect(find.text('Pay Securely with PayPal'), findsOneWidget);
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
              simLineId: 'line_123_abc',
            ),
          ),
        ),
      );

      await widgetTester.pump();

      expect(find.text('Annual Plan Renewal'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
    });
  });
}
