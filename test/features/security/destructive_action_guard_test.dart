import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/services/destructive_action_guard.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'fake_biometric_auth_service.dart';

/// Pumps a button that runs the guard and records its verdict.
Future<void> _pumpGuard(
  WidgetTester tester,
  DestructiveActionGuard guard,
  List<bool> results, {
  String token = '0142',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              results.add(
                await guard.confirmDestructiveAction(
                  context,
                  reason: 'Authenticate to delete',
                  confirmationToken: token,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('destructiveConfirmationToken', () {
    test('takes the last four digits of a formatted number', () {
      expect(destructiveConfirmationToken('+1 (555) 018-0142'), '0142');
    });

    test('keeps every digit when there are fewer than four', () {
      expect(destructiveConfirmationToken('+1-23'), '123');
    });

    test('falls back to a literal word when there are no digits', () {
      expect(destructiveConfirmationToken('unknown'), 'DELETE');
    });
  });

  group('DestructiveActionGuard', () {
    late FakeBiometricAuthService fakeService;
    late DestructiveActionGuard guard;
    late List<bool> results;

    setUp(() {
      fakeService = FakeBiometricAuthService(isAvailable: true);
      guard = DestructiveActionGuard(fakeService);
      results = [];
    });

    testWidgets('confirms when biometric auth succeeds', (tester) async {
      fakeService.nextResult = BiometricResult.success;
      await _pumpGuard(tester, guard, results);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(fakeService.authCount, 1);
      expect(fakeService.lastReason, 'Authenticate to delete');
    });

    testWidgets('refuses when the user cancels the prompt', (tester) async {
      fakeService.nextResult = BiometricResult.cancelled;
      await _pumpGuard(tester, guard, results);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('refuses on a failed fingerprint', (tester) async {
      fakeService.nextResult = BiometricResult.failed;
      await _pumpGuard(tester, guard, results);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('refuses when biometrics are locked out', (tester) async {
      fakeService.nextResult = BiometricResult.lockedOut;
      await _pumpGuard(tester, guard, results);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    // The reason this guard exists instead of reusing PaymentAuthGuard, which
    // suppresses its prompt for 60s after any success. A refill followed by a
    // mistaken delete tap must still prompt.
    testWidgets('prompts on every call - no grace window', (tester) async {
      fakeService.nextResult = BiometricResult.success;
      await _pumpGuard(tester, guard, results);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(results, [true, true]);
      expect(fakeService.authCount, 2);
    });

    group('no device lock enrolled', () {
      setUp(() => fakeService.nextResult = BiometricResult.unavailable);

      testWidgets('falls back to typed confirmation instead of passing',
          (tester) async {
        await _pumpGuard(tester, guard, results);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Nothing decided yet: the fallback dialog is waiting for input.
        expect(results, isEmpty);
        expect(find.text('Confirm deletion'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('keeps delete disabled until the token matches',
          (tester) async {
        await _pumpGuard(tester, guard, results);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        ElevatedButton deleteButton() => tester.widget<ElevatedButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(ElevatedButton),
              ),
            );

        expect(deleteButton().onPressed, isNull);

        await tester.enterText(find.byType(TextField), '9999');
        await tester.pumpAndSettle();
        expect(deleteButton().onPressed, isNull);

        await tester.enterText(find.byType(TextField), '0142');
        await tester.pumpAndSettle();
        expect(deleteButton().onPressed, isNotNull);
      });

      testWidgets('confirms once the correct token is typed', (tester) async {
        await _pumpGuard(tester, guard, results);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '0142');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ElevatedButton),
          ),
        );
        await tester.pumpAndSettle();

        expect(results, [true]);
      });

      testWidgets('refuses when the fallback is cancelled', (tester) async {
        await _pumpGuard(tester, guard, results);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(results, [false]);
      });

      testWidgets('accepts the literal token case-insensitively',
          (tester) async {
        await _pumpGuard(tester, guard, results, token: 'DELETE');
        await tester.tap(find.text('Delete').first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'delete');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ElevatedButton),
          ),
        );
        await tester.pumpAndSettle();

        expect(results, [true]);
      });
    });
  });
}
