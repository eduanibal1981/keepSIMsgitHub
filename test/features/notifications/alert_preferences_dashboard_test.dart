import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/alert_alarm/model/device_alarm_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/notifications/data/models/alert_setting_model.dart';
import 'package:keep_sims/features/notifications/data/models/channel_destination.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/data/services/notification_permission_service.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';
import 'package:keep_sims/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:keep_sims/features/notifications/presentation/widgets/alert_preferences_dashboard.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_alert_clock_state.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';

final channels = <Map<String, dynamic>>[
  {'channel_type': 'push', 'is_enabled': true, 'config': <String, dynamic>{}},
  {
    'channel_type': 'email',
    'is_enabled': true,
    'config': {'email': 'owner@example.com'},
  },
  {
    'channel_type': 'whatsapp',
    'is_enabled': true,
    'config': {'phone': '+96879527567'},
  },
  {
    'channel_type': 'telegram',
    'is_enabled': true,
    'config': <String, dynamic>{},
  },
];

void main() {
  test(
    'overview recipient matches delivery key precedence and legacy fallback',
    () {
      expect(
        channelDestination('whatsapp', {
          'phone_number': '+96891111111',
          'phone': '+96892222222',
        }),
        '+96891111111',
      );
      expect(
        channelDestination('whatsapp', {
          'phone_number': '',
          'phone': '+96892222222',
        }),
        '+96892222222',
      );
      expect(
        channelDestination('email', {
          'email_address': 'recipient@example.com',
          'email': 'legacy@example.com',
        }, accountEmail: 'account@example.com'),
        'recipient@example.com',
      );
      expect(
        channelDestination('email', {
          'email_address': '',
          'email': '',
        }, accountEmail: 'account@example.com'),
        'account@example.com',
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutter = (config['packages'] as List).cast<Map>().firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final packageUri = configFile.absolute.uri.resolve(
      flutter['rootUri'] as String,
    );
    final sdk = Directory.fromUri(packageUri).parent.parent;
    final fonts = Directory('${sdk.path}/bin/cache/artifacts/material_fonts');
    for (final family in ['Roboto', 'Inter_regular']) {
      final regular = await File(
        '${fonts.path}/roboto-regular.ttf',
      ).readAsBytes();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(regular)));
      await loader.load();
    }
    final icons = await File(
      '${fonts.path}/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
  test(
    'Telegram needs a verified binding and status respects platform pause',
    () {
      expect(
        channelOverviewState('telegram', channels.last, null, null),
        'Setup required',
      );
      expect(
        channelOverviewState(
          'telegram',
          {
            'is_enabled': true,
            'config': {'chat_id': 12345, 'binding_verified_at': 'now'},
          },
          null,
          null,
        ),
        'On',
      );
      expect(
        channelOverviewState('push', channels.first, {
          'is_globally_enabled': false,
        }, null),
        'Unavailable',
      );
      expect(
        channelOverviewState(
          'whatsapp',
          {
            'is_enabled': true,
            'config': {'phone_number': '79527567'},
          },
          null,
          null,
        ),
        'Setup required',
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    _Channels controller, {
    bool dark = false,
    double scale = 1,
    double width = 390,
    _NotificationAccess? access,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationChannelsControllerProvider.overrideWith(() => controller),
          notificationPermissionServiceProvider.overrideWithValue(
            access ?? _NotificationAccess(),
          ),
          userPreferencesControllerProvider.overrideWith(() => _Preferences()),
          alertSettingsControllerProvider.overrideWith(() => _Categories()),
          authControllerProvider.overrideWith(() => _Auth()),
          deviceAlarmControllerProvider.overrideWith(() => _Alarm()),
          simLinesControllerProvider.overrideWith(() => _Lines()),
          simLineAlertClockForLineProvider.overrideWith(
            (ref, id) async =>
                SimLineAlertClockState(simLineId: id, userId: 'owner'),
          ),
          notificationChannelCatalogProvider.overrideWith((ref) async => {}),
          weeklyDigestConsentProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          key: ValueKey('$dark:$scale:$width'),
          theme: dark ? AppTheme.dark : AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: ValueKey('preview'),
            child: NotificationSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'overview exposes all channels, destination, alarm, and timing navigation',
    (tester) async {
      await mount(tester, _Channels());
      expect(find.text('Sends to +96879527567'), findsOneWidget);
      expect(find.text('Setup required'), findsOneWidget);
      expect(find.text('Alarm Clock'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quiet hours'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Quiet hours'), findsOneWidget);
      expect(find.text('Weekly summary'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WhatsApp editor refuses guessed country code and saves international destination',
    (tester) async {
      final controller = _Channels();
      await mount(tester, controller);
      await tester.tap(find.text('WhatsApp alerts'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '79527567');
      await tester.tap(find.text('Save Settings'));
      await tester.pumpAndSettle();
      expect(controller.saves, 0);
      expect(
        find.text(
          'Enter the full international number, including + and country code.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '00968 9123 4567');
      await tester.tap(find.text('Save Settings'));
      await tester.pumpAndSettle();
      expect(controller.saved?['phone'], '+96891234567');
      expect(controller.saved?['phone_number'], '+96891234567');
      expect(find.text('Sends to +96891234567'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed switch save restores the previous value', (tester) async {
    final controller = _Channels()..fail = true;
    await mount(tester, controller);
    await tester.tap(find.text('WhatsApp alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      find.text('Could not save your preference. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'push permissions can be enabled later without prompting on open',
    (tester) async {
      final access = _NotificationAccess();
      await mount(tester, _Channels(), access: access);
      await tester.tap(find.text('Push notifications'));
      await tester.pumpAndSettle();
      expect(access.requests, 0);
      expect(find.text('Not enabled'), findsOneWidget);
      final action = find.byKey(
        const ValueKey('notification-permission-action'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(access.requests, 1);
      expect(find.text('Allowed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('alarm editor explains the schedule and missing recharge data', (
    tester,
  ) async {
    await mount(tester, _Channels());
    await tester.tap(find.text('Alarm Clock'));
    await tester.pumpAndSettle();
    expect(find.text('Enable on this device'), findsOneWidget);
    expect(find.text('Last recharge date needed'), findsOneWidget);
    expect(find.text('Record last recharge'), findsOneWidget);
    expect(find.textContaining('at least 48 hours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing an unsaved destination survives switching the channel', (
    tester,
  ) async {
    await mount(tester, _Channels());
    await tester.tap(find.text('WhatsApp alerts'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+96899999999');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '+96899999999',
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'compact and large text layouts stay usable (${dark ? 'dark' : 'light'})',
      (tester) async {
        await mount(tester, _Channels(), dark: dark, scale: 2, width: 320);
        await tester.scrollUntilVisible(
          find.text('Weekly summary'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await mount(tester, _Channels(), dark: dark);
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'output/alert-preferences-concepts/implemented-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Channels extends NotificationChannelsController {
  int saves = 0;
  bool fail = false;
  Map<String, dynamic>? saved;
  @override
  FutureOr<List<Map<String, dynamic>>> build() =>
      channels.map((c) => Map<String, dynamic>.from(c)).toList();
  @override
  Future<void> toggleChannel(String type, bool enabled) async {
    if (fail) throw StateError('Save failed');
    state = AsyncData(
      state.value!
          .map(
            (c) =>
                c['channel_type'] == type ? {...c, 'is_enabled': enabled} : c,
          )
          .toList(),
    );
  }

  @override
  Future<void> updateChannelConfig(
    String type,
    Map<String, dynamic> config,
  ) async {
    saves++;
    saved = config;
    state = AsyncData(
      state.value!
          .map((c) => c['channel_type'] == type ? {...c, 'config': config} : c)
          .toList(),
    );
  }
}

class _NotificationAccess implements NotificationPermissionService {
  bool granted = false;
  int requests = 0;

  @override
  Future<NotificationPermissionAccess> status() async =>
      NotificationPermissionAccess(
        supported: true,
        granted: granted,
        canRequest: !granted,
      );

  @override
  Future<void> request() async {
    requests++;
    granted = true;
  }

  @override
  Future<bool> openSettings() async => true;
}

class _Preferences extends UserPreferencesController {
  @override
  FutureOr<UserPreferences> build() => const UserPreferences(
    id: 'prefs',
    userId: 'owner',
    weeklyDigestEnabled: false,
  );
}

class _Categories extends AlertSettingsController {
  @override
  FutureOr<List<AlertSetting>> build() => [];
}

class _Auth extends AuthController {
  @override
  FutureOr<UserProfile?> build() => null;
}

class _Alarm extends DeviceAlarmController {
  @override
  Future<DeviceAlarmStatus> build() async => const DeviceAlarmStatus(
    supported: true,
    exactAlarmAllowed: true,
    notificationsAllowed: true,
    timeZone: 'Asia/Muscat',
  );
}

class _Lines extends SimLinesController {
  @override
  FutureOr<List<SimLine>> build() => const [
    SimLine(id: 'fixture-line', userId: 'owner', phoneNumber: '+96891111111'),
  ];
}
