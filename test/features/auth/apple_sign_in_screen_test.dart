import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/ui/login_screen.dart';

class _Auth extends AuthController {
  var appleAttempts = 0;
  final completion = Completer<void>();

  @override
  FutureOr<UserProfile?> build() => null;

  @override
  Future<void> signInWithApple() async {
    appleAttempts++;
    state = const AsyncValue.loading();
    await completion.future;
    state = const AsyncValue.data(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.cast<Map>().singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final sdk = Directory.fromUri(
      config.absolute.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final regular = ByteData.sublistView(
      await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ).readAsBytes(),
    );
    // Flutter's Ahem test font makes every letter a square; use realistic
    // glyph metrics for the narrow phone screen, including the Inter styles.
    for (final family in ['Roboto', 'Inter_regular']) {
      await (FontLoader(family)..addFont(Future.value(regular))).load();
    }
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> mount(WidgetTester tester, _Auth auth) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => auth)],
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'iPhone button starts Apple, blocks duplicate taps, and quietly returns after cancellation',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final auth = _Auth();
      await mount(tester, auth);
      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      expect(auth.appleAttempts, 1);
      final buttons = tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(buttons.length, 2);
      expect(buttons.every((button) => button.onPressed == null), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      auth.completion.complete();
      await tester.pump();
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'Android does not advertise an Apple flow that needs OAuth setup',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await mount(tester, _Auth());
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
