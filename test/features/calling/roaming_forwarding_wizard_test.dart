import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/presentation/widgets/roaming_forwarding_wizard_sheet.dart';

void main() {
  testWidgets('RoamingForwardingWizardSheet renders correct GSM MMI codes and DID', (tester) async {
    final did = VirtualDidNumber(
      id: 'did-om-001',
      phoneNumber: '+96899887766',
      countryCode: 'OM',
      countryName: 'Oman',
      status: 'active',
      monthlyFeeUsd: 1.50,
      forwardMode: 'app',
      renewsAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoamingForwardingWizardSheet(did: did),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Zero-Roaming Forwarding'), findsOneWidget);
    expect(find.textContaining('+96899887766'), findsNWidgets(2)); // DID summary + activation code
    expect(find.text('**21*+96899887766#'), findsOneWidget);
    expect(find.text('##21#'), findsOneWidget);
    expect(find.text('Got It, Ready to Travel'), findsOneWidget);
  });
}
