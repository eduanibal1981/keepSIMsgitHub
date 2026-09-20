import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/widgets/rate_savings_calculator_widget.dart';

void main() {
  testWidgets('RateSavingsCalculatorWidget computes accurate carrier vs KeepSIMs savings', (tester) async {
    const rate = CallRate(
      id: 'rate-uk-001',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      phonePrefix: '+44',
      costPerMinute: 0.07,
      ratePerMinute: 0.10,
      billingIncrementSeconds: 60,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RateSavingsCalculatorWidget(rate: rate),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Defaults to 15 minutes:
    // Carrier: 15 * 2.50 = $37.50
    // KeepSIMs: 15 * 0.10 = $1.50
    // Savings: $36.00 (96%)
    expect(find.text('Roaming Savings: United Kingdom'), findsOneWidget);
    expect(find.text('\$37.50'), findsOneWidget);
    expect(find.text('\$1.50'), findsOneWidget);
    expect(find.text('Save \$36.00 (96%)'), findsOneWidget);
    expect(find.text('15 Minutes'), findsOneWidget);

    // Tap 30 min choice chip
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    // 30 minutes:
    // Carrier: 30 * 2.50 = $75.00
    // KeepSIMs: 30 * 0.10 = $3.00
    // Savings: $72.00 (96%)
    expect(find.text('\$75.00'), findsOneWidget);
    expect(find.text('\$3.00'), findsOneWidget);
    expect(find.text('Save \$72.00 (96%)'), findsOneWidget);
    expect(find.text('30 Minutes'), findsOneWidget);
  });
}
