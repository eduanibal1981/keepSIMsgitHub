import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/floating_minimized_call_bar.dart';

class FakeVoipCallingController extends VoipCallingController {
  final VoipActiveCallState _initial;
  FakeVoipCallingController(this._initial);

  @override
  VoipActiveCallState build() => _initial;
}

void main() {
  testWidgets('FloatingMinimizedCallBar renders nothing when call is inactive', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voipCallingControllerProvider.overrideWith(
            () => FakeVoipCallingController(const VoipActiveCallState(status: 'idle')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FloatingMinimizedCallBar(),
          ),
        ),
      ),
    );

    expect(find.byType(FloatingMinimizedCallBar), findsOneWidget);
    expect(find.text('KeepSIMs Voice Call'), findsNothing);
  });

  testWidgets('FloatingMinimizedCallBar renders nothing when call is active but NOT minimized', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voipCallingControllerProvider.overrideWith(
            () => FakeVoipCallingController(
              const VoipActiveCallState(
                status: 'connected',
                peerName: 'Sarah Connor',
                isMinimized: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FloatingMinimizedCallBar(),
          ),
        ),
      ),
    );

    expect(find.text('Sarah Connor'), findsNothing);
  });

  testWidgets('FloatingMinimizedCallBar renders and does NOT throw RawTooltip Overlay exception even outside Overlay', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voipCallingControllerProvider.overrideWith(
            () => FakeVoipCallingController(
              const VoipActiveCallState(
                status: 'connected',
                peerName: 'Sarah Connor',
                isMinimized: true,
                durationSeconds: 65,
              ),
            ),
          ),
        ],
        // Render outside MaterialApp/Navigator/Overlay (like in main.dart Stack)
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              FloatingMinimizedCallBar(),
            ],
          ),
        ),
      ),
    );

    // Verify it rendered successfully without throwing No Overlay widget found
    expect(tester.takeException(), isNull);
    expect(find.text('Sarah Connor'), findsOneWidget);
    expect(find.text('Tap to return • 01:05'), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
  });
}
