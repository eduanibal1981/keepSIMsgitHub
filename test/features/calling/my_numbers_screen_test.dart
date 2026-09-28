import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/data/models/virtual_did_model.dart';
import 'package:keep_sims/features/calling/presentation/screens/my_numbers_screen.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';

void main() {
  testWidgets('MyNumbersScreen renders virtual numbers and Smart Call Setup without duplicate switcher', (tester) async {
    final mockDid = VirtualDidNumber(
      id: 'did-us-01',
      phoneNumber: '+12025550192',
      countryCode: 'US',
      countryName: 'United States',
      status: 'active',
      monthlyFeeUsd: 1.50,
      forwardMode: 'app',
      renewsAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          virtualDidsProvider.overrideWith((ref) async => [mockDid]),
          simLinesControllerProvider.overrideWith(() => _FakeSimLinesController([])),
        ],
        child: const MaterialApp(
          home: MyNumbersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('KeepSIMs Smart Calling'), findsOneWidget);
    expect(find.text('Numbers & Smart Call Setup'), findsOneWidget);

    // Verify Virtual Number card
    expect(find.text('+12025550192'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('KeepSIMs In-App (VoIP)'), findsOneWidget);

    // Verify Smart Call Setup Card
    expect(find.text('KeepSIMs Smart Call Setup'), findsOneWidget);
    expect(find.text('**21*+12025550192#'), findsOneWidget);
    expect(find.text('##21#'), findsOneWidget);

    // Verify duplicate switcher is NOT present
    expect(find.byType(CallingModeSwitcher), findsNothing);
  });
}

class _FakeSimLinesController extends SimLinesController {
  final List<SimLine> initialLines;
  _FakeSimLinesController(this.initialLines);

  @override
  Future<List<SimLine>> build() async => initialLines;
}
