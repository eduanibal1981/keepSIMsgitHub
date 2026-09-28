import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/smart_call_savings_screen.dart';

void main() {
  testWidgets('SmartCallSavingsScreen renders destination rate and computes savings', (tester) async {
    const mockRate = CallRate(
      id: 'rate-om-01',
      countryCode: 'OM',
      countryName: 'Oman',
      phonePrefix: '+968',
      costPerMinute: 0.08,
      ratePerMinute: 0.12,
      billingIncrementSeconds: 1,
      connectionFee: 0.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callRatesProvider.overrideWith((ref) async => [mockRate]),
        ],
        child: const MaterialApp(
          home: SmartCallSavingsScreen(initialCountryCode: 'OM'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('KeepSIMs Smart Calling'), findsOneWidget);
    expect(find.text('KeepSIMs Smart Call Savings'), findsOneWidget);

    // Verify Destination
    expect(find.textContaining('OM  Oman'), findsOneWidget);

    // Initial state: No roaming rate set (null default — no fabricated comparison)
    // KeepSIMs cost: 12 * 0.12 = $1.44
    expect(find.text('\$1.44'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Enter rate above to compare.'), findsOneWidget);
    expect(find.text('Add a roaming rate to compare'), findsOneWidget);
    expect(find.text('95%'), findsNothing);

    // Select $2.00 roaming preset chip
    await tester.tap(find.text('\$2.00'));
    await tester.pumpAndSettle();

    // With $2.00: 12 * 2.00 = $24.00
    // Savings: $24.00 - $1.44 = $22.56 (94%)
    expect(find.text('\$24.00'), findsOneWidget);
    expect(find.textContaining('You save \$22.56 (94%)'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);

    // Tap $2.00 again to toggle off
    await tester.tap(find.text('\$2.00'));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Add a roaming rate to compare'), findsOneWidget);
    expect(find.text('94%'), findsNothing);

    // Enter rate manually via TextField
    await tester.enterText(find.byType(TextField), '3.00');
    await tester.pumpAndSettle();

    // With $3.00: 12 * 3.00 = $36.00
    // Savings: $36.00 - $1.44 = $34.56 (96%)
    expect(find.text('\$36.00'), findsOneWidget);
    expect(find.textContaining('You save \$34.56 (96%)'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
  });
}
