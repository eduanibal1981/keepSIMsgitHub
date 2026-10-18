import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_options_section.dart';

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
    final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Bold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File('$fonts/Roboto-$weight.ttf').readAsBytes(),
          ),
        ),
      );
    }
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/MaterialIcons-Regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    bool dark = false,
    double scale = 1,
    VoidCallback? onDialerTap,
    VoidCallback? onFreeCallTap,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final background = dark ? const Color(0xFF070E17) : const Color(0xFFF6FAFD);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'Roboto',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: background,
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: const ValueKey('calling-options-preview'),
              child: ColoredBox(
                color: background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                  child: CallingOptionsSection(
                    onDialerTap: onDialerTap ?? () {},
                    onFreeCallTap: onFreeCallTap ?? () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CallingOptionsSection));
      await precacheImage(
        const AssetImage('assets/icons/call_dialer.png'),
        context,
      );
      if (context.mounted) {
        await precacheImage(
          const AssetImage('assets/icons/free_app_call.png'),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('round call controls retain labels and separate actions', (
    tester,
  ) async {
    var dialerTaps = 0;
    var freeCallTaps = 0;
    final semantics = tester.ensureSemantics();
    try {
      await mount(
        tester,
        onDialerTap: () => dialerTaps++,
        onFreeCallTap: () => freeCallTaps++,
      );

      expect(find.bySemanticsLabel('Call with Dialer'), findsOneWidget);
      expect(find.bySemanticsLabel('Call free'), findsOneWidget);
      await tester.tap(find.byTooltip('Call with Dialer'));
      expect(dialerTaps, 1);
      expect(freeCallTaps, 0);
      await tester.tap(find.byTooltip('Call free'));
      expect(dialerTaps, 1);
      expect(freeCallTaps, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final dark in [false, true]) {
    testWidgets(
      'calling cards adapt to width and text size (${dark ? 'dark' : 'light'})',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 640.0]) {
          await mount(tester, width: width, dark: dark);
          expect(tester.takeException(), isNull);
        }
        await mount(tester, width: 320, dark: dark, scale: 2);
        await tester.scrollUntilVisible(find.byTooltip('Call free'), 250);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        debugDisableShadows = false;
        try {
          await mount(tester, dark: dark);
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('calling-options-preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'output/calling-options/implemented-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        } finally {
          debugDisableShadows = true;
        }
      },
    );
  }
}
