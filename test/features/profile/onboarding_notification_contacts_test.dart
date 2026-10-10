import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/alert_alarm/controller/device_alarm_controller.dart';
import 'package:keep_sims/features/alert_alarm/model/device_alarm_model.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/notifications/data/services/notification_permission_service.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_permission_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/profile/presentation/ui/onboarding_screen.dart';
import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import 'onboarding_currency_transition_test.dart';

const _simCountries = [
  Country(
    id: 'eg',
    name: 'Egypt',
    isoCode: 'EG',
    dialingCode: '+20',
    currencyCode: 'EGP',
  ),
];

class _Completion extends ProfileController {
  final tiers = <String?>[];
  final powerUserValues = <bool>[];

  @override
  Future<Result<UserProfile>> completeOnboarding({
    required String fullName,
    required String homeCountryCode,
    required String preferredCurrency,
    required bool isPowerUser,
    String? subscriptionTier,
  }) async {
    tiers.add(subscriptionTier);
    powerUserValues.add(isPowerUser);
    return const Success(
      UserProfile(id: 'new-account', onboardingCompleted: true),
    );
  }
}

class _ExistingFreeSim extends NoSimLines {
  @override
  Future<List<SimLine>> build() async => const [
    SimLine(id: 'existing', userId: 'new-account', phoneNumber: '+2010000000'),
  ];
}

class _Account extends AuthController {
  @override
  Future<UserProfile?> build() async => const UserProfile(
    id: 'new-account',
    email: 'owner@example.com',
    fullName: 'New Account',
  );
}

class _Contacts extends NotificationChannelsController {
  _Contacts({this.loaded});
  final Completer<void>? loaded;
  bool failSave = false;
  final saves = <Map<String, dynamic>>[];
  final toggles = <bool>[];

  @override
  Future<List<Map<String, dynamic>>> build() async {
    await loaded?.future;
    return [
      {
        'channel_type': 'push',
        'is_enabled': false,
        'config': <String, dynamic>{},
      },
      {
        'channel_type': 'email',
        'is_enabled': false,
        'config': {'email': 'owner@example.com'},
      },
      {
        'channel_type': 'whatsapp',
        'is_enabled': false,
        'config': {
          'phone_number': '+96890000000',
          'phone': '+11111111111',
          'notification_timezone': 'Asia/Muscat',
        },
      },
    ];
  }

  @override
  Future<void> updateChannelConfig(
    String channelType,
    Map<String, dynamic> config,
  ) async {
    if (failSave) throw StateError('Contact save unavailable');
    saves.add({'channel_type': channelType, 'config': config});
    state = AsyncData([
      for (final channel in state.requireValue)
        if (channel['channel_type'] == channelType)
          {...channel, 'config': config}
        else
          channel,
    ]);
  }

  @override
  Future<void> toggleChannel(String channelType, bool isEnabled) async {
    toggles.add(isEnabled);
    state = AsyncData([
      for (final channel in state.requireValue)
        if (channel['channel_type'] == channelType)
          {...channel, 'is_enabled': isEnabled}
        else
          channel,
    ]);
  }
}

class _NotificationAccess implements NotificationPermissionService {
  bool supported = true;
  bool granted = false;
  bool canRequest = true;
  bool grantOnRequest = false;
  bool failCheck = false;
  int requests = 0;
  int settingsOpened = 0;
  Completer<void>? pendingRequest;

  @override
  Future<NotificationPermissionAccess> status() async {
    if (failCheck) throw StateError('Device check failed');
    return NotificationPermissionAccess(
      supported: supported,
      granted: granted,
      canRequest: canRequest,
    );
  }

  @override
  Future<void> request() async {
    requests++;
    await pendingRequest?.future;
    granted = grantOnRequest;
    canRequest = false;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class _DeviceAlarms extends DeviceAlarmController {
  _DeviceAlarms(this.access);
  final _NotificationAccess access;
  bool enabled = false;
  bool exactAlarmAllowed = false;
  int settingsOpened = 0;
  final toggles = <bool>[];

  @override
  Future<DeviceAlarmStatus> build() async => DeviceAlarmStatus(
    supported: access.supported,
    enabled: enabled,
    exactAlarmAllowed: exactAlarmAllowed,
    notificationsAllowed: access.granted,
  );

  @override
  Future<void> setEnabled(bool value) async {
    toggles.add(value);
    enabled = value;
    ref.invalidateSelf();
  }

  @override
  Future<void> openPermissionSettings() async => settingsOpened++;
}

final _whatsapp = find.byKey(const ValueKey('onboarding-whatsapp-number'));
final _email = find.byKey(const ValueKey('onboarding-notification-email'));

Future<OnboardingDisplayFx> _mount(
  WidgetTester tester,
  _Contacts contacts, {
  bool startSetup = true,
  bool dark = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  ValueNotifier<double>? scale,
  _NotificationAccess? access,
  _DeviceAlarms? alarms,
  List<Country> countries = const [],
  SimLinesController? lines,
  _Completion? completion,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fx = OnboardingDisplayFx();
  final textScaleValue = scale ?? ValueNotifier(textScale);
  if (scale == null) addTearDown(textScaleValue.dispose);
  final notificationAccess = access ?? _NotificationAccess();
  final deviceAlarms = alarms ?? _DeviceAlarms(notificationAccess);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Account.new),
        fxControllerProvider.overrideWith(() => fx),
        notificationChannelsControllerProvider.overrideWith(() => contacts),
        notificationPermissionServiceProvider.overrideWithValue(
          notificationAccess,
        ),
        deviceAlarmControllerProvider.overrideWith(() => deviceAlarms),
        simLinesControllerProvider.overrideWith(() => lines ?? NoSimLines()),
        supportedCountriesProvider.overrideWith((ref) async => countries),
        carriersForCountryProvider('eg').overrideWith(
          (ref) async => const [
            Carrier(
              id: 'carrier',
              countryId: 'eg',
              name: 'Test Carrier',
              isSupported: true,
            ),
          ],
        ),
        carrierRuleProvider('carrier').overrideWith((ref) async => null),
        if (completion != null)
          profileControllerProvider.overrideWith(() => completion),
        paymentGatewayProvider('paypal').overrideWith((ref) async => null),
        appFeePercentProvider.overrideWith((ref) async => 0),
        premiumMarginPercentProvider.overrideWith((ref) async => 0),
        premiumMarginPerRefillUsdProvider.overrideWith((ref) async => 0),
        baseServiceFeeUsdProvider.overrideWith((ref) async => 7.5),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: textScaleValue,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(value)),
            child: child!,
          ),
        ),
        home: const RepaintBoundary(
          key: ValueKey('onboarding-preview'),
          child: OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!startSetup) return fx;
  await tester.ensureVisible(
    find.byKey(const ValueKey('onboarding-terms-checkbox')),
  );
  await tester.tap(find.byKey(const ValueKey('onboarding-terms-checkbox')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
  await tester.pumpAndSettle();
  return fx;
}

Future<void> _enterWhatsApp(WidgetTester tester, String value) async {
  await tester.ensureVisible(_whatsapp);
  await tester.enterText(_whatsapp, value);
}

Future<void> _goToAlerts(WidgetTester tester) async {
  for (var step = 0; step < 2; step++) {
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
  }
  expect(find.text('Step 4 of 5'), findsOneWidget);
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData regularFont;
  late ByteData testManifest;
  setUpAll(() async {
    // Use readable fonts rather than the square test font for phone-size layout.
    final configFile = File('.dart_tool/package_config.json');
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutter = (config['packages'] as List).cast<Map>().firstWhere(
      (package) => package['name'] == 'flutter',
    );
    final packageUri = configFile.absolute.uri.resolve(
      flutter['rootUri'] as String,
    );
    final sdk = Directory.fromUri(packageUri).parent.parent;
    final fonts = Directory('${sdk.path}/bin/cache/artifacts/material_fonts');
    final regular = await File(
      '${fonts.path}/roboto-regular.ttf',
    ).readAsBytes();
    regularFont = ByteData.sublistView(regular);
    const codec = StandardMessageCodec();
    final manifest = Map<Object?, Object?>.from(
      codec.decodeMessage(await rootBundle.load('AssetManifest.bin')) as Map,
    );
    manifest['test-fonts/Inter-Regular.ttf'] = [
      {'asset': 'test-fonts/Inter-Regular.ttf'},
    ];
    testManifest = codec.encodeMessage(manifest)!;
    for (final family in ['Roboto', 'Inter_regular']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(regular)))).load();
    }
    final icons = await File(
      '${fonts.path}/materialicons-regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.allMessagesHandler = (channel, handler, message) {
      if (channel == 'flutter/assets') {
        final asset = utf8.decode(message!.buffer.asUint8List());
        if (asset == 'AssetManifest.bin') return Future.value(testManifest);
        if (asset == 'test-fonts/Inter-Regular.ttf') {
          return Future.value(regularFont);
        }
      }
      return handler != null
          ? handler(message)
          : messenger.delegate.send(channel, message);
    };
    addTearDown(() => messenger.allMessagesHandler = null);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'first SIM skip is at the top right (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _mount(tester, _Contacts(), dark: dark, countries: _simCountries);
        await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
        await tester.pumpAndSettle();
        final skip = find.byKey(const ValueKey('onboarding-first-sim-skip'));
        expect(skip.hitTestable(), findsOneWidget);
        expect(tester.getTopRight(skip).dx, closeTo(366, 1));
        expect(tester.takeException(), isNull);
        final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('onboarding-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'output/onboarding-permissions/first-sim-skip-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(skip);
        await tester.pumpAndSettle();
        expect(find.text('Step 4 of 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('skip bypasses incomplete SIM validation and retains the draft', (
    tester,
  ) async {
    await _mount(tester, _Contacts());
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    final phone = find.widgetWithText(TextField, 'e.g. 91234567');
    await tester.enterText(phone, '91234567');
    await tester.tap(find.byKey(const ValueKey('onboarding-first-sim-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Step 4 of 5'), findsOneWidget);
    expect(
      find.text('Please select a country for your first SIM card.'),
      findsNothing,
    );
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(phone).controller!.text, '91234567');
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(
      find.text('Please select a country for your first SIM card.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('skipping a filled SIM excludes enrollment and paid activation', (
    tester,
  ) async {
    final completion = _Completion();
    await _mount(
      tester,
      _Contacts(),
      countries: _simCountries,
      lines: _ExistingFreeSim(),
      completion: completion,
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. 91234567'),
      '91234567',
    );
    final carrier = find.byType(DropdownButton<Carrier>);
    await tester.ensureVisible(carrier);
    await tester.tap(carrier);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Carrier').last);
    await tester.pumpAndSettle();
    final skip = find.byKey(const ValueKey('onboarding-first-sim-skip'));
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-alerts-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Free Plan (\$0)'), findsOneWidget);
    expect(find.text('First Protected SIM'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(completion.tiers, ['basic']);
    expect(completion.powerUserValues, [false]);
    expect(find.textContaining('Failed to protect SIM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permissions are optional and set up later advances without prompts',
    (tester) async {
      final access = _NotificationAccess();
      await _mount(tester, _Contacts(), access: access);
      await _goToAlerts(tester);
      expect(find.text('Device permissions'), findsOneWidget);
      expect(
        find.text('Requested when you make or answer a call.'),
        findsOneWidget,
      );
      expect(access.requests, 0);
      expect(access.settingsOpened, 0);
      await tester.tap(find.byKey(const ValueKey('onboarding-alerts-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(access.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'denied access stays optional and settings refresh after returning',
    (tester) async {
      final access = _NotificationAccess();
      await _mount(tester, _Contacts(), access: access);
      await _goToAlerts(tester);
      final action = find.byKey(
        const ValueKey('notification-permission-action'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(access.requests, 1);
      expect(access.settingsOpened, 0);
      expect(find.text('Open settings'), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(access.settingsOpened, 1);
      access.granted = true;
      await _resume(tester);
      expect(find.text('Allowed'), findsOneWidget);
      access.granted = false;
      await _resume(tester);
      expect(find.text('Allowed'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(access.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a pending request stays single and survives app resume', (
    tester,
  ) async {
    final pending = Completer<void>();
    final access = _NotificationAccess()
      ..grantOnRequest = true
      ..pendingRequest = pending;
    final contacts = _Contacts();
    await _mount(tester, contacts, access: access);
    await _goToAlerts(tester);
    final push = find.byKey(const ValueKey('onboarding-channel-push'));
    await tester.ensureVisible(push);
    await tester.tap(push);
    await tester.pump();
    expect(access.requests, 1);
    await _resume(tester);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Allowed'), findsOneWidget);
    expect(contacts.toggles, [true]);
    expect(tester.widget<SwitchListTile>(push).value, isTrue);
    await tester.tap(push);
    await tester.pumpAndSettle();
    expect(contacts.toggles, [true, false]);
    expect(access.requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denying push access does not enable the delivery preference', (
    tester,
  ) async {
    final access = _NotificationAccess();
    final contacts = _Contacts();
    await _mount(tester, contacts, access: access);
    await _goToAlerts(tester);
    final push = find.byKey(const ValueKey('onboarding-channel-push'));
    await tester.ensureVisible(push);
    await tester.tap(push);
    await tester.pumpAndSettle();
    expect(access.requests, 1);
    expect(contacts.toggles, isEmpty);
    expect(tester.widget<SwitchListTile>(push).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable device access does not block setup', (tester) async {
    final access = _NotificationAccess()..supported = false;
    await _mount(tester, _Contacts(), access: access);
    await _goToAlerts(tester);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-permission-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('onboarding-alarm-setup')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Step 5 of 5'), findsOneWidget);
    expect(access.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed access checks are retryable without a prompt', (
    tester,
  ) async {
    final access = _NotificationAccess()..failCheck = true;
    await _mount(tester, _Contacts(), access: access);
    await _goToAlerts(tester);
    expect(find.text('Could not check notification access.'), findsOneWidget);
    access.failCheck = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Enable'), findsOneWidget);
    expect(access.requests, 0);
    access.failCheck = true;
    await _resume(tester);
    expect(find.text('Could not check notification access.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alarm access is requested only after enabling alarms', (
    tester,
  ) async {
    final access = _NotificationAccess();
    final alarms = _DeviceAlarms(access);
    await _mount(tester, _Contacts(), access: access, alarms: alarms);
    await _goToAlerts(tester);
    final action = find.byKey(const ValueKey('onboarding-alarm-setup'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(access.requests, 0);
    expect(alarms.settingsOpened, 0);
    final toggle = find.widgetWithText(SwitchListTile, 'Enable on this device');
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(access.requests, 1);
    expect(alarms.toggles, isEmpty);
    expect(alarms.settingsOpened, 0);
    expect(
      find.text('Allow notifications to enable SIM alarm reminders.'),
      findsOneWidget,
    );
    access.granted = true;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(alarms.toggles, [true]);
    expect(alarms.settingsOpened, 1);
    alarms.exactAlarmAllowed = true;
    await _resume(tester);
    expect(find.text('Open device settings'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(alarms.toggles, [true, false]);
    expect(access.requests, 1);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('permissions layout and preview (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await _mount(tester, _Contacts(), dark: dark);
      await _goToAlerts(tester);
      expect(tester.takeException(), isNull);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('onboarding-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'output/onboarding-permissions/permissions-${dark ? 'dark' : 'light'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      await _mount(tester, _Contacts(), dark: dark, scale: scale);
      await _goToAlerts(tester);
      tester.view.physicalSize = const Size(320, 568);
      scale.value = 1.8;
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('notification-permission-action')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-channel-push')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('welcome requires agreement and retains it when going back', (
    tester,
  ) async {
    await _mount(tester, _Contacts(), startSetup: false);
    final next = find.byKey(const ValueKey('onboarding-continue'));
    final agreement = find.byKey(const ValueKey('onboarding-terms-checkbox'));
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('onboarding-brand-artwork')));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 5'), findsOneWidget);
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 5'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(agreement).value, isTrue);
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('policy links open the correct pages without accepting terms', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <Map<Object?, Object?>>[];
    var succeeds = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launches.add(Map<Object?, Object?>.from(call.arguments as Map));
        return succeeds;
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _mount(tester, _Contacts(), startSetup: false);
    for (final title in ['Terms of Service', 'Privacy Policy']) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(launches.map((call) => call['url']), [
      'https://keepsims.com/terms',
      'https://keepsims.com/privacy',
    ]);
    expect(launches.every((call) => call['useWebView'] == false), isTrue);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('onboarding-terms-checkbox')),
          )
          .value,
      isFalse,
    );
    succeeds = false;
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open this page. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('welcome layout and preview (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await _mount(tester, _Contacts(), startSetup: false, dark: dark);
      await tester.runAsync(() async {
        final context = tester.element(
          find.byKey(const ValueKey('onboarding-brand-artwork')),
        );
        await precacheImage(
          const AssetImage('assets/images/launcher-foreground.png'),
          context,
        );
      });
      await tester.pumpAndSettle();
      final agreement = find.byKey(const ValueKey('onboarding-terms-checkbox'));
      expect(agreement.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('onboarding-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'output/onboarding-consent/welcome-${dark ? 'dark' : 'light'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(agreement);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'output/onboarding-consent/welcome-${dark ? 'dark' : 'light'}-accepted.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(agreement);
      await tester.pumpAndSettle();
      await _mount(
        tester,
        _Contacts(),
        startSetup: false,
        dark: dark,
        size: const Size(320, 568),
        textScale: 1.8,
      );
      await tester.ensureVisible(agreement);
      await tester.pumpAndSettle();
      await tester.tap(agreement);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('onboarding-continue')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('prefills account email and saved canonical WhatsApp number', (
    tester,
  ) async {
    final contacts = _Contacts();
    await _mount(tester, contacts);
    await tester.ensureVisible(_email);
    final email = tester.widget<TextField>(_email);
    expect(email.controller!.text, 'owner@example.com');
    expect(email.readOnly, isTrue);
    expect(
      tester.widget<TextField>(_whatsapp).controller!.text,
      '+96890000000',
    );
    expect(
      find.text('For Standard and Premium SIM subscriptions'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves international WhatsApp number and preserves settings', (
    tester,
  ) async {
    final contacts = _Contacts();
    await _mount(tester, contacts);
    await _enterWhatsApp(tester, '00968 (9123) 4567');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(contacts.saves, hasLength(1));
    final config = contacts.saves.single['config'] as Map<String, dynamic>;
    expect(config['phone_number'], '+96891234567');
    expect(config['phone'], '+96891234567');
    expect(config['notification_timezone'], 'Asia/Muscat');
    expect(contacts.state.requireValue.last['is_enabled'], isFalse);
    expect(find.text('Protect First SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects a local number before saving or advancing', (
    tester,
  ) async {
    final contacts = _Contacts();
    final fx = await _mount(tester, contacts);
    await _enterWhatsApp(tester, '91234567');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Add + and the country code before your number, e.g. +96891234567.',
      ),
      findsOneWidget,
    );
    expect(fx.savedCodes, isEmpty);
    expect(contacts.saves, isEmpty);
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save retains the number and supports retry', (
    tester,
  ) async {
    final contacts = _Contacts()..failSave = true;
    await _mount(tester, contacts);
    await _enterWhatsApp(tester, '+96891234567');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 5'), findsOneWidget);
    expect(
      find.text('Could not save your WhatsApp number. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_whatsapp).controller!.text,
      '+96891234567',
    );
    contacts.failSave = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(contacts.saves, hasLength(1));
    expect(find.text('Protect First SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional WhatsApp contact can be cleared', (tester) async {
    final contacts = _Contacts();
    await _mount(tester, contacts);
    await _enterWhatsApp(tester, '');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final config = contacts.saves.single['config'] as Map<String, dynamic>;
    expect(config['phone'], isEmpty);
    expect(config['phone_number'], isEmpty);
    expect(find.text('Protect First SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unchanged WhatsApp contact does not require a save', (
    tester,
  ) async {
    final contacts = _Contacts();
    await _mount(tester, contacts);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(contacts.saves, isEmpty);
    expect(find.text('Protect First SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading settings does not overwrite a number being typed', (
    tester,
  ) async {
    final loaded = Completer<void>();
    final contacts = _Contacts(loaded: loaded);
    await _mount(tester, contacts);
    await _enterWhatsApp(tester, '+96891234567');
    loaded.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_whatsapp).controller!.text,
      '+96891234567',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(contacts.saves, hasLength(1));
    expect(find.text('Protect First SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
