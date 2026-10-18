import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/core/widgets/glass_card.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

const line = SimLine(
  id: 'fixture',
  userId: 'fixture-owner',
  nickname: 'SIM Line',
  phoneNumber: '+966555555552',
  planType: 'standard',
);

ScheduledTopup schedule(String type, {bool active = true}) => ScheduledTopup(
  id: type,
  simLineId: line.id,
  userId: line.userId,
  amount: 0,
  frequencyDays: 30,
  nextExecutionAt: DateTime(2027),
  scheduleType: type,
  isActive: active,
  status: active ? 'active' : 'paused',
);

Future<void> loadFonts() async {
  final config = File('.dart_tool/package_config.json');
  final packages = jsonDecode(await config.readAsString())['packages'] as List;
  final flutter = packages.cast<Map>().firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    config.absolute.uri.resolve(flutter['rootUri']),
  ).parent.parent;
  final fonts = '${sdk.path}/bin/cache/artifacts/material_fonts';
  final interPath = Platform.environment['DASHBOARD_INTER_FONT'];
  final inter = await File(
    interPath ?? '$fonts/roboto-regular.ttf',
  ).readAsBytes();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = const StringCodec().decodeMessage(message);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        'fonts/Inter-Regular.ttf': [
          {'asset': 'fonts/Inter-Regular.ttf'},
        ],
      });
    }
    if (key == 'fonts/Inter-Regular.ttf') return ByteData.sublistView(inter);
    if (key != null && key.startsWith('assets/')) {
      final file = File(key);
      if (file.existsSync()) {
        return ByteData.sublistView(file.readAsBytesSync());
      }
    }
    return null;
  });
  for (final family in ['Roboto']) {
    final bytes = await File('$fonts/roboto-regular.ttf').readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  final bytes = await File('$fonts/materialicons-regular.otf').readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  // Headless Flutter has no platform Arabic fallback. Use a local font without
  // introducing a font dependency into the app or fetching during tests.
  for (final path in [
    if (Platform.environment['DASHBOARD_ARABIC_FONT'] case final String path)
      path,
    '/System/Library/Fonts/SFArabic.ttf',
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
  ]) {
    if (await File(path).exists()) {
      final arabic = await File(path).readAsBytes();
      await (FontLoader(
        'DashboardArabic',
      )..addFont(Future.value(ByteData.sublistView(arabic)))).load();
      break;
    }
  }
}

ThemeData fixtureTheme(bool dark) {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: ['DashboardArabic']),
  );
}

Future<void> capture(
  WidgetTester tester,
  String name, {
  String boundaryKey = 'capture',
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(ValueKey(boundaryKey)),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/dashboard-sim-card-compact/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> mount(
  WidgetTester tester, {
  bool dark = false,
  double width = 390,
  double scale = 1,
  bool arabic = false,
  SimLine fixture = line,
  ScheduledTopup? notify,
  ScheduledTopup? refill,
  List<SimLine>? lines,
  ValueNotifier<double>? scaleNotifier,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  final textScale = scaleNotifier ?? ValueNotifier(scale);
  if (scaleNotifier == null) addTearDown(textScale.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(
        '$width:$scale:$dark:$arabic:${fixture.planType}:${notify?.status}:${refill?.status}',
      ),
      overrides: [
        scheduledNotifyForLineProvider.overrideWith((ref, id) => notify),
        scheduledMiniRefillForLineProvider.overrideWith((ref, id) => refill),
        scheduledCustomRefillForLineProvider.overrideWith((ref, id) => null),
        hasRealLiveVerificationProvider.overrideWith((ref, id) async => true),
      ],
      child: MaterialApp(
        key: ValueKey(
          '$width:$scale:$dark:$arabic:${fixture.planType}:${notify?.id}:${refill?.id}',
        ),
        theme: fixtureTheme(dark),
        locale: Locale(arabic ? 'ar' : 'en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: textScale,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(value)),
            child: child!,
          ),
        ),
        home: RepaintBoundary(
          key: const ValueKey('capture'),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lines to protect'),
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      key: const ValueKey('carousel-capture'),
                      child: DashboardSimLineCarousel(
                        lines: lines ?? [fixture],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  final measurements = <Map<String, Object>>[];
  tearDownAll(() async {
    if (measurements.isEmpty) return;
    await File(
      'output/dashboard-sim-card-compact/layout-measurements.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(measurements));
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });
  for (final dark in [false, true]) {
    testWidgets('reference capture ${dark ? 'dark' : 'light'}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, dark: dark, notify: schedule('notify'));
      expect(tester.takeException(), isNull);
      await capture(tester, 'after-${dark ? 'dark' : 'light'}');
      await capture(
        tester,
        'after-card-${dark ? 'dark' : 'light'}',
        boundaryKey: 'carousel-capture',
      );
      expect(tester.getSize(find.byType(DashboardSimLineCard)).height, 229);
    });
  }

  testWidgets(
    'paused schedules keep inactive controls and neutral card styling',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final premium in [false, true]) {
        await mount(
          tester,
          fixture: line.copyWith(
            protectionPaused: true,
            planType: premium ? 'premium' : 'standard',
            protectionTier: premium ? 'premium' : 'standard',
          ),
          notify: schedule('notify', active: false),
          refill: schedule('refill_mini', active: false),
        );
        expect(find.byType(DashboardSimToggle), findsNWidgets(2));
        expect(
          tester
              .widgetList<DashboardSimToggle>(find.byType(DashboardSimToggle))
              .every((toggle) => !toggle.value),
          isTrue,
        );
        expect(find.byTooltip('Protection inactive'), findsOneWidget);
        expect(
          tester.widget<GlassCard>(find.byType(GlassCard)).isActive,
          isFalse,
        );
        expect(
          tester.widget<GlassCard>(find.byType(GlassCard)).customBorder,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final arabic in [false, true]) {
        for (final dark in [false, true]) {
          testWidgets('layout $width / $scale / ar=$arabic / dark=$dark', (
            tester,
          ) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            for (final premium in [false, true]) {
              for (final active in [false, true]) {
                final fixture = line.copyWith(
                  nickname: arabic
                      ? 'شريحة العمل والسفر ذات الاسم الطويل جدًا'
                      : 'A very long work and travel SIM nickname',
                  phoneNumber: '+123456789012345',
                  planType: premium ? 'premium' : 'standard',
                  protectionTier: premium ? 'premium' : 'standard',
                );
                await mount(
                  tester,
                  width: width,
                  scale: scale,
                  arabic: arabic,
                  dark: dark,
                  fixture: fixture,
                  notify: active ? schedule('notify') : null,
                  refill: active ? schedule('refill_mini') : null,
                );
                expect(tester.takeException(), isNull);
                final phone = tester.widget<Text>(
                  find.text(fixture.phoneNumber),
                );
                expect(phone.textDirection, TextDirection.ltr);
                final card = tester.getRect(find.byType(DashboardSimLineCard));
                final recharge = tester.getRect(
                  find.byKey(const ValueKey('sim-recharge-fixture')),
                );
                measurements.add({
                  'width': width,
                  'textScale': scale,
                  'arabic': arabic,
                  'dark': dark,
                  'premium': premium,
                  'active': active,
                  'cardWidth': card.width,
                  'cardHeight': card.height,
                });
                if (width == 320 &&
                    scale == 2 &&
                    arabic &&
                    dark &&
                    !premium &&
                    active) {
                  await capture(tester, 'after-arabic-320-2x-dark');
                }
                expect(card.bottom - recharge.bottom, closeTo(13, .1));
                expect(recharge.height, greaterThanOrEqualTo(44));
                expect(
                  find.byTooltip(
                    active ? 'Protection active' : 'Protection inactive',
                  ),
                  arabic ? findsNothing : findsOneWidget,
                );
              }
            }
          });
        }
      }
    }
  }

  testWidgets(
    'SIM labels follow addition order and preserve custom nicknames',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = line.copyWith(
        id: 'first',
        nickname: null,
        createdAt: DateTime(2026, 1, 1),
      );
      final second = line.copyWith(
        id: 'second',
        createdAt: DateTime(2026, 1, 2),
      );
      final third = line.copyWith(
        id: 'third',
        nickname: ' ',
        createdAt: DateTime(2026, 1, 3),
      );
      final custom = line.copyWith(
        id: 'custom',
        nickname: 'Travel',
        createdAt: DateTime(2026, 1, 4),
      );
      final input = [custom, third, second, first];
      await mount(tester, lines: input);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      for (final entry in ['SIM 1', 'SIM 2', 'SIM 3', 'Travel'].indexed) {
        controller.jumpToPage(entry.$1);
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.byTooltip(entry.$2), findsOneWidget);
      }
      expect(input.map((line) => line.id), [
        'custom',
        'third',
        'second',
        'first',
      ]);
      await mount(
        tester,
        lines: [
          line.copyWith(
            id: 'new',
            nickname: null,
            createdAt: DateTime(2026, 1, 5),
          ),
          ...input,
        ],
      );
      controller.jumpToPage(4);
      await tester.pumpAndSettle();
      expect(find.text('SIM 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mixed pages keep position and indicators when text scale changes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lines = [
        line,
        line.copyWith(
          id: 'premium',
          planType: 'premium',
          protectionTier: 'premium',
        ),
      ];
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      await mount(tester, lines: lines, scaleNotifier: scale);
      final page = find.byType(PageView);
      await tester.drag(page, const Offset(-350, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(page).controller!.page, closeTo(1, .01));
      final carouselContext = tester.element(
        find.byType(DashboardSimLineCarousel),
      );
      final state = tester.state(find.byType(DashboardSimLineCarousel));
      // Resize through the existing MediaQuery, keeping the carousel's state.
      final media = tester.widget<MediaQuery>(
        find
            .ancestor(
              of: find.byType(DashboardSimLineCarousel),
              matching: find.byType(MediaQuery),
            )
            .first,
      );
      expect(media.data.textScaler.scale(14), 14);
      expect(
        DashboardSimCardLayout.of(carouselContext, 310.2, line).height,
        229,
      );
      scale.value = 2;
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(DashboardSimLineCarousel)), same(state));
      expect(tester.widget<PageView>(page).controller!.page, closeTo(1, .01));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard-sim-page-1')))
            .width,
        20,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
