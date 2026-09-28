import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/screens/internet_calling_screen.dart';

void main() {
  testWidgets('InternetCallingScreen renders Smart Calling headers and tabs without duplicate switcher', (tester) async {
    final mockSimLine = SimLine(
      id: 'test-sim-1',
      userId: 'test-user',
      phoneNumber: '+96891234567',
      nickname: 'Personal eSIM',
      avatarIcon: 'esim',
      countryId: 'OM',
      status: 'active',
      planType: 'free',
      protectionTier: 'standard',
      isAutoDetected: false,
      isHomeMode: false,
      protectionPaused: false,
      requiresProtectionAtHome: false,
      isCarrierVerified: true,
      carrierStatus: 'verified',
      detectedOperatorName: 'Omantel',
      healthScore: 100,
      verificationStatus: 'verified',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simLinesControllerProvider.overrideWith(
            () => _FakeSimLinesController([mockSimLine]),
          ),
        ],
        child: const MaterialApp(
          home: InternetCallingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Badges
    expect(find.text('KeepSIMs Smart Calling'), findsOneWidget);
    expect(find.text('Free Call (App-to-App)'), findsOneWidget);
    expect(find.text('100% FREE'), findsOneWidget);

    // Verify info card
    expect(find.text('Free Internet Audio Calls'), findsOneWidget);
    expect(
      find.text('Call other KeepSIMs users over Wi-Fi or travel eSIM mobile data with no Smart Call wallet deduction.'),
      findsOneWidget,
    );

    // Verify tabs
    expect(find.text('Household Lines (1)'), findsOneWidget);
    expect(find.text('User Search'), findsOneWidget);

    // Verify household line row
    expect(find.text('Personal eSIM'), findsOneWidget);
    expect(find.text('+96891234567'), findsOneWidget);
    expect(find.text('eSIM'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    // Verify duplicate CallingModeSwitcher is NOT present
    expect(find.byType(CallingModeSwitcher), findsNothing);
  });
}

class _FakeSimLinesController extends SimLinesController {
  final List<SimLine> initialLines;
  _FakeSimLinesController(this.initialLines);

  @override
  Future<List<SimLine>> build() async => initialLines;
}
