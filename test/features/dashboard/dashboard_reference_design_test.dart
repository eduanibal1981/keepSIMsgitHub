import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/router/placeholder_screens.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/dashboard_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/perspective_drawer_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/providers/promo_provider.dart';
import 'package:keep_sims/features/dashboard/presentation/ui/dashboard_screen.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_feature_cards.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart';
import 'package:keep_sims/features/geo/controller/geo_controller.dart';
import 'package:keep_sims/features/geo/model/geo_state.dart';
import 'package:keep_sims/features/notifications/data/models/notification_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import 'dashboard_sim_card_compact_test.dart' show fixtureTheme, loadFonts;

class _Auth extends AuthController {
  @override
  FutureOr<UserProfile?> build() => const UserProfile(
    id: 'fixture-owner',
    fullName: 'Abdalla',
    homeCountryCode: 'OM',
    onboardingCompleted: true,
  );
}

class _Dashboard extends DashboardController {
  @override
  FutureOr<DashboardState> build() => const DashboardState(
    totalLines: 2,
    walletBalance: 0,
    nextTopUpDays: 10,
    nextTopUpTotalDays: 30,
    overallHealthScore: 75,
    recentActivities: [],
  );
}

class _Lines extends SimLinesController {
  final bool empty;
  _Lines(this.empty);
  @override
  FutureOr<List<SimLine>> build() => empty
      ? []
      : [
          SimLine(
            id: 'first',
            userId: 'fixture-owner',
            phoneNumber: '+96893990499',
            planType: 'standard',
            createdAt: DateTime(2026, 1, 1),
          ),
          SimLine(
            id: 'second',
            userId: 'fixture-owner',
            phoneNumber: '+966555555552',
            planType: 'premium',
            protectionTier: 'premium',
            createdAt: DateTime(2026, 1, 2),
          ),
        ];
}

class _Geo extends GeoController {
  @override
  GeoState build() =>
      const GeoState(currentCountry: 'Oman', currentIsoCode: 'OM');
  @override
  Future<void> checkCurrentLocationOnAppOpen() async {}
}

class _Connectivity extends ConnectivityService {
  @override
  NetworkStatus build() => NetworkStatus.online;
}

class _Notifications extends NotificationsController {
  @override
  FutureOr<List<AppNotification>> build() => [];
}

class _Locale extends LocaleController {
  @override
  Locale build() => const Locale('en');
  @override
  Future<void> setLocale(Locale value) async {
    state = value;
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('dashboard-reference-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/dashboard-reference-20261016/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<GoRouter> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool arabic = false,
    bool dark = false,
    bool empty = false,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (_, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, state) => const DashboardScreen(),
            ),
            for (final path in [
              AppRoutes.calling,
              AppRoutes.myNumbers,
              AppRoutes.esim,
              AppRoutes.simLines,
              '${AppRoutes.simLines}/add',
              AppRoutes.wallet,
              AppRoutes.notifications,
            ])
              GoRoute(
                path: path,
                builder: (_, state) =>
                    Scaffold(body: Text('Destination: $path')),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey('$width:$scale:$arabic:$dark:$empty'),
        overrides: [
          authControllerProvider.overrideWith(_Auth.new),
          dashboardControllerProvider.overrideWith(_Dashboard.new),
          simLinesControllerProvider.overrideWith(() => _Lines(empty)),
          geoControllerProvider.overrideWith(_Geo.new),
          connectivityServiceProvider.overrideWith(_Connectivity.new),
          notificationsControllerProvider.overrideWith(_Notifications.new),
          localeControllerProvider.overrideWith(_Locale.new),
          activePromosProvider.overrideWith((ref) async => []),
          scheduledNotifyForLineProvider.overrideWith(
            (ref, id) => ScheduledTopup(
              id: 'notify-$id',
              simLineId: id,
              userId: 'fixture-owner',
              amount: 0,
              frequencyDays: 30,
              nextExecutionAt: DateTime(2027),
            ),
          ),
          scheduledMiniRefillForLineProvider.overrideWith((ref, id) => null),
          scheduledCustomRefillForLineProvider.overrideWith((ref, id) => null),
          hasRealLiveVerificationProvider.overrideWith((ref, id) async => true),
        ],
        child: MaterialApp.router(
          theme: fixtureTheme(dark),
          locale: Locale(arabic ? 'ar' : 'en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: const ValueKey('dashboard-reference-capture'),
              child: child!,
            ),
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final dark in [false, true]) {
    testWidgets('complete dashboard reference ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await mount(tester, dark: dark);
      expect(
        find.descendant(
          of: find.byType(DashboardFeatureCards),
          matching: find.text('Second Number'),
        ),
        findsOneWidget,
      );
      final vertical = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(DashboardScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      vertical.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(vertical.position.pixels, 0);

      expect(find.text('Explore KeepSIMs'), findsOneWidget);
      expect(find.text('Your SIM lines'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('NEW'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'implemented-${dark ? 'dark' : 'light'}');
    });
  }

  testWidgets(
    'feature cards, header actions, Manage SIMs and Add SIM retain routing',
    (tester) async {
      final router = await mount(tester);
      for (final entry in {
        'Smart Call': AppRoutes.calling,
        'Second Number': AppRoutes.myNumbers,
        'Worldwide eSIMs': AppRoutes.esim,
      }.entries) {
        final action = find.descendant(
          of: find.byType(DashboardFeatureCards),
          matching: find.text(entry.key),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Destination: ${entry.value}'), findsOneWidget);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
      }
      for (final entry in {
        'Wallet': AppRoutes.wallet,
        'Notifications': AppRoutes.notifications,
      }.entries) {
        await tester.ensureVisible(find.byTooltip(entry.key));
        await tester.tap(find.byTooltip(entry.key));
        await tester.pumpAndSettle();
        expect(find.text('Destination: ${entry.value}'), findsOneWidget);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Manage SIMs'));
      await tester.tap(find.text('Manage SIMs'));
      await tester.pumpAndSettle();
      expect(find.text('Destination: ${AppRoutes.simLines}'), findsOneWidget);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add SIM'));
      await tester.tap(find.text('Add SIM'));
      await tester.pumpAndSettle();
      expect(
        find.text('Destination: ${AppRoutes.simLines}/add'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'avatar retains language and location access; flat More opens drawer',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current location'));
      await tester.pumpAndSettle();
      expect(find.text('Current Location'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select App Language'));
      await tester.pumpAndSettle();
      expect(find.text('English (US)'), findsOneWidget);
      Navigator.of(tester.element(find.text('English (US)'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      expect(container.read(perspectiveDrawerControllerProvider), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty dashboard hero opens Add SIM', (tester) async {
    await mount(tester, empty: true);
    await tester.tap(find.text('Add SIMs'));
    await tester.pumpAndSettle();
    expect(find.text('Destination: ${AppRoutes.simLines}/add'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final arabic in [false, true]) {
        testWidgets('dashboard layout $width / $scale / ar=$arabic', (
          tester,
        ) async {
          await mount(
            tester,
            width: width,
            scale: scale,
            arabic: arabic,
            dark: arabic,
          );
          final sim = find.byType(DashboardSimLineCard).first;
          await tester.ensureVisible(sim);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width == 320 && scale == 2 && arabic) {
            await capture(tester, 'implemented-arabic-320-2x');
          }
        });
      }
    }
  }
}
