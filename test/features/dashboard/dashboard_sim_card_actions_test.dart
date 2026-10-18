import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/core/services/destructive_action_guard.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_card.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/dashboard_sim_line_carousel.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/line_upgrade_sheet.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/manual_refill_bottom_sheet.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import 'dashboard_sim_card_compact_test.dart' show line, schedule, loadFonts;

// Inspect dispatch without mounting provider/payment screens or performing any
// action inside them. Confirmation dialogs still render and receive real taps.
class _SheetRecorder extends NavigatorObserver {
  final sheets = <Widget>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) {
      sheets.add(route.builder(navigator!.context));
      scheduleMicrotask(() => navigator?.removeRoute(route));
    }
  }
}

class _Schedules extends ScheduledTopupController {
  final List<ScheduledTopup> initial;
  final changes = <(String, bool)>[];
  _Schedules(this.initial);
  @override
  FutureOr<List<ScheduledTopup>> build() => initial;
  @override
  Future<Result<ScheduledTopup>> toggleActive(String id, bool isActive) async {
    changes.add((id, isActive));
    final updated = state.requireValue
        .firstWhere((s) => s.id == id)
        .copyWith(isActive: isActive);
    state = AsyncData(
      state.requireValue.map((s) => s.id == id ? updated : s).toList(),
    );
    return Success(updated);
  }
}

class _Lines extends SimLinesController {
  final deleted = <String>[];
  @override
  FutureOr<List<SimLine>> build() => [line];
  @override
  Future<void> deleteSimLine(String id) async => deleted.add(id);
}

class _Biometrics implements BiometricAuthService {
  BiometricResult result = BiometricResult.cancelled;
  int requests = 0;
  @override
  Future<bool> isBiometricAvailable() async => true;
  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    requests++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  late _SheetRecorder observer;
  late _Schedules schedules;
  late _Lines lines;
  late _Biometrics biometrics;
  late GoRouter router;

  Future<void> mount(
    WidgetTester tester, {
    bool premium = false,
    bool configured = false,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    observer = _SheetRecorder();
    schedules = _Schedules(
      configured
          ? [
              schedule('notify'),
              schedule('refill_mini'),
              schedule('refill_custom'),
            ]
          : [],
    );
    lines = _Lines();
    biometrics = _Biometrics();
    final fixture = premium
        ? line.copyWith(planType: 'premium', protectionTier: 'premium')
        : line;
    router = GoRouter(
      observers: [observer],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: DashboardSimLineCarousel(lines: [fixture]),
            ),
          ),
        ),
        GoRoute(
          path: '/sim-lines/detail/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('Fixture details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduledTopupControllerProvider.overrideWith(() => schedules),
          simLinesControllerProvider.overrideWith(() => lines),
          hasRealLiveVerificationProvider.overrideWith((ref, id) async => true),
          destructiveActionGuardProvider.overrideWithValue(
            DestructiveActionGuard(biometrics),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(const ValueKey('sim-menu-fixture')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  testWidgets('card tap and menu Configuration retain details navigation', (
    tester,
  ) async {
    await mount(tester);
    await menu(tester, 'Configuration');
    expect(find.text('Fixture details'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIM 1'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture details'), findsOneWidget);
  });

  testWidgets('Configure, Upgrade and Recharge dispatch independently', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Set up').first);
    await tester.pumpAndSettle();
    expect(observer.sheets.last, isA<ScheduledTopupSheet>());
    expect((observer.sheets.last as ScheduledTopupSheet).configMode, 'notify');
    await tester.tap(find.text('Set up').last);
    await tester.pumpAndSettle();
    expect(observer.sheets.last, isA<LineUpgradeSheet>());
    await tester.tap(find.byKey(const ValueKey('sim-menu-fixture')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sim-upgrade-fixture')));
    await tester.pumpAndSettle();
    expect(observer.sheets.last, isA<LineUpgradeSheet>());
    await tester.tap(find.byKey(const ValueKey('sim-recharge-fixture')));
    await tester.pumpAndSettle();
    expect(observer.sheets.last, isA<ManualRefillBottomSheet>());
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(schedules.changes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium Configure opens refill configuration without Upgrade', (
    tester,
  ) async {
    await mount(tester, premium: true);
    expect(find.byKey(const ValueKey('sim-upgrade-fixture')), findsNothing);
    await tester.tap(find.text('Set up').last);
    await tester.pumpAndSettle();
    expect(
      (observer.sheets.single as ScheduledTopupSheet).configMode,
      'refill',
    );
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('44 dp switch targets toggle Notify and prefer custom refill', (
    tester,
  ) async {
    await mount(tester, premium: true, configured: true);
    for (final index in [0, 1]) {
      final target = find
          .descendant(
            of: find.byType(DashboardSimToggle).at(index),
            matching: find.byType(GestureDetector),
          )
          .first;
      final rect = tester.getRect(target);
      expect(rect.height, greaterThanOrEqualTo(44));
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();
    }
    expect(schedules.changes, [('notify', false), ('refill_custom', false)]);
    expect(observer.sheets, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('Standard refill switch retains premium gate', (tester) async {
    await mount(tester, configured: true);
    await tester.tap(
      find
          .descendant(
            of: find.byType(DashboardSimToggle).last,
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(observer.sheets.single, isA<LineUpgradeSheet>());
    expect(schedules.changes, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('Delete requires dialog confirmation and owner verification', (
    tester,
  ) async {
    await mount(tester);
    await menu(tester, 'Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(biometrics.requests, 0);
    expect(lines.deleted, isEmpty);
    await menu(tester, 'Delete');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(biometrics.requests, 1);
    expect(lines.deleted, isEmpty);
    biometrics.result = BiometricResult.success;
    await menu(tester, 'Delete');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(biometrics.requests, 2);
    expect(lines.deleted, ['fixture']);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });
}
