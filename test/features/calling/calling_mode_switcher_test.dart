import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';

void main() {
  testWidgets('CallingModeSwitcher renders all 3 modes and badges',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CallingModeSwitcher(activeMode: CallingMode.international),
        ),
      ),
    );

    expect(find.text('Phone Calls'), findsOneWidget);
    expect(find.text('PAID'), findsOneWidget);

    expect(find.text('KeepSIMs Calls'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);

    expect(find.text('My Numbers'), findsOneWidget);
    expect(find.text('DID'), findsOneWidget);
  });

  testWidgets('CallingModeSwitcher highlights active mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CallingModeSwitcher(activeMode: CallingMode.myNumbers),
        ),
      ),
    );

    expect(find.text('My Numbers'), findsOneWidget);
    expect(find.text('DID'), findsOneWidget);
  });
}
