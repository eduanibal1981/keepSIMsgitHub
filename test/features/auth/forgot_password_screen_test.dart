import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/contract/password_recovery_contract.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/ui/email_auth_screen.dart';
import 'package:keep_sims/features/auth/ui/forgot_password_screen.dart';

class _SignedOut extends AuthController {
  @override
  FutureOr<UserProfile?> build() => null;
}

class _SplashReady extends SplashCompleted {
  @override
  bool build() => true;
}

class _Recovery implements PasswordRecoveryContract {
  final sentEmails = <String>[];
  final codes = <String>[];
  final passwords = <String>[];
  bool rejectCode = false;
  bool rejectPassword = false;
  Completer<Result<void>>? pendingSend;

  @override
  Future<Result<void>> sendCode(String email) async {
    sentEmails.add(email);
    return pendingSend == null
        ? const Success(null)
        : await pendingSend!.future;
  }

  @override
  Future<Result<void>> verifyCode(String email, String code) async {
    codes.add(code);
    return rejectCode
        ? const Failure(
            AppFailure.auth(message: 'This code is invalid or has expired.'),
          )
        : const Success(null);
  }

  @override
  Future<Result<void>> resetPassword(String password) async {
    passwords.add(password);
    return rejectPassword
        ? const Failure(
            AppFailure.auth(message: 'Choose a different password.'),
          )
        : const Success(null);
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Recovery recovery, {
  bool startAtSignIn = false,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: startAtSignIn
        ? AppRoutes.emailAuth
        : AppRoutes.forgotPassword,
    routes: [
      GoRoute(
        path: AppRoutes.emailAuth,
        builder: (_, _) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) =>
            ForgotPasswordScreen(initialEmail: state.extra as String? ?? ''),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        passwordRecoveryRepositoryProvider.overrideWith((ref) => recovery),
        authControllerProvider.overrideWith(_SignedOut.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.widgetWithText(ElevatedButton, text).evaluate().isNotEmpty
      ? find.widgetWithText(ElevatedButton, text)
      : find.widgetWithText(TextButton, text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _sendCode(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('recovery-email')),
    'owner@example.com',
  );
  await _tap(tester, 'Send reset code');
}

Future<void> _verifyCode(WidgetTester tester) async {
  await _sendCode(tester);
  await tester.enterText(
    find.byKey(const ValueKey('recovery-code')),
    '12345678',
  );
  await _tap(tester, 'Verify code');
}

void main() {
  testWidgets(
    'the app router permits recovery and stays there after OTP verification',
    (tester) async {
      final recovery = _Recovery();
      final container = ProviderContainer(
        overrides: [
          passwordRecoveryRepositoryProvider.overrideWith((ref) => recovery),
          authControllerProvider.overrideWith(_SignedOut.new),
          splashCompletedProvider.overrideWith(_SplashReady.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final router = container.read(appGoRouterProvider);
      router.go(AppRoutes.forgotPassword);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _verifyCode(tester);
      expect(find.text('Set a new password'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.forgotPassword,
      );
      expect(container.read(authControllerProvider).value, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('sign-in link carries the email and is hidden during sign-up', (
    tester,
  ) async {
    final recovery = _Recovery();
    await _mount(tester, recovery, startAtSignIn: true);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@example.com',
    );
    await _tap(tester, 'Forgot password?');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('recovery-email')))
          .controller!
          .text,
      'owner@example.com',
    );
    await tester.tap(find.byTooltip('Back to sign in'));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await _tap(tester, 'Sign Up');
    expect(find.text('Forgot password?'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('validates email and enforces resend cooldown', (tester) async {
    final recovery = _Recovery();
    await _mount(tester, recovery);
    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'invalid',
    );
    await _tap(tester, 'Send reset code');
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(recovery.sentEmails, isEmpty);
    await _sendCode(tester);
    expect(find.text('Check your email'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Resend code in 60s'),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 61));
    await _tap(tester, 'Resend code');
    expect(recovery.sentEmails, hasLength(2));
    expect(find.text('Resend code in 60s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'invalid code stays on verification, then a valid code advances',
    (tester) async {
      final recovery = _Recovery()..rejectCode = true;
      await _mount(tester, recovery);
      await _sendCode(tester);
      await tester.enterText(find.byKey(const ValueKey('recovery-code')), '12');
      await _tap(tester, 'Verify code');
      expect(recovery.codes, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        '000000',
      );
      await _tap(tester, 'Verify code');
      expect(find.text('This code is invalid or has expired.'), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
      recovery.rejectCode = false;
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        '123456',
      );
      await _tap(tester, 'Verify code');
      expect(find.text('Set a new password'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('validates passwords, allows retry, and returns to sign-in', (
    tester,
  ) async {
    final recovery = _Recovery()..rejectPassword = true;
    await _mount(tester, recovery, themeMode: ThemeMode.dark);
    await _verifyCode(tester);
    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'different',
    );
    await _tap(tester, 'Reset password');
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(recovery.passwords, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'new-password',
    );
    await _tap(tester, 'Reset password');
    expect(find.text('Choose a different password.'), findsOneWidget);
    recovery.rejectPassword = false;
    await _tap(tester, 'Reset password');
    expect(find.text('Password reset'), findsOneWidget);
    await _tap(tester, 'Back to sign in');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(recovery.passwords, ['new-password', 'new-password']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'disables repeated sends and safely handles leaving mid-request',
    (tester) async {
      final recovery = _Recovery()..pendingSend = Completer<Result<void>>();
      await _mount(tester, recovery);
      await _sendCode(tester);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Back to sign in',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      recovery.pendingSend!.complete(const Success(null));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(recovery.sentEmails, hasLength(1));
    },
  );

  testWidgets(
    'a reset session can be restarted without keeping passwords in the form',
    (tester) async {
      final recovery = _Recovery();
      await _mount(tester, recovery);
      await _verifyCode(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recovery-password')),
        'new-password',
      );
      await _tap(tester, 'Request a new code');
      expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
      await _tap(tester, 'Send reset code');
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        '123456',
      );
      await _tap(tester, 'Verify code');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('recovery-password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(recovery.sentEmails, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'switching to a different email clears cooldown and allows immediate send',
    (tester) async {
      final recovery = _Recovery();
      await _mount(tester, recovery);
      await _sendCode(tester);
      expect(find.text('Check your email'), findsOneWidget);
      await _tap(tester, 'Use a different email');
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Send reset code'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Send reset code'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-email')),
        'other@example.com',
      );
      await _tap(tester, 'Send reset code');
      expect(recovery.sentEmails, ['owner@example.com', 'other@example.com']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
