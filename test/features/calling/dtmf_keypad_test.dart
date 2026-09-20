import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/screens/active_call_screen.dart';

void main() {
  testWidgets('ActiveCallScreen renders Keypad button and opens DTMF dialpad', (tester) async {
    final container = ProviderContainer(
      overrides: [
        callingControllerProvider.overrideWith(() => _MockCallingController()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ActiveCallScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Mute and Keypad buttons are present
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Keypad'), findsOneWidget);
    expect(find.byIcon(Icons.dialpad), findsOneWidget);

    // Tap Keypad button
    await tester.tap(find.byIcon(Icons.dialpad));
    await tester.pumpAndSettle();

    // Verify DTMF dialpad sheet opens
    expect(find.text('Keypad'), findsNWidgets(2)); // Button label + sheet title
    expect(find.text('Touch-tone dialpad'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('*'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);

    // Tap a digit
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    // Digit should now appear in the display
    expect(find.text('5'), findsNWidgets(2)); // Keypad key + entered digits display
  });
}

class _MockCallingController extends CallingController {
  @override
  ActiveCallState build() {
    return const ActiveCallState(
      callId: 'test-call-123',
      destinationNumber: '+96891234567',
      status: 'in_progress',
    );
  }

  @override
  void sendDtmf(String tone) {
    // Mock DTMF tone receiver
  }
}
