import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/failure.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/profile/domain/contract/profile_contract.dart';
import 'package:keep_sims/features/profile/domain/models/notification_email_status.dart';
import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';
import 'package:keep_sims/features/profile/presentation/ui/profile_screen.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _Store {
  UserProfile profile = const UserProfile(
    id: 'u',
    email: 'account@example.com',
    fullName: 'Test User',
    homeCountryCode: 'OM',
    preferredCurrency: 'OMR',
    onboardingCompleted: true,
  );
}

class _Auth extends AuthController {
  _Auth(this.store);
  final _Store store;
  @override
  Future<UserProfile?> build() async => store.profile;
}

class _Locale extends LocaleController {
  _Locale(this.locale);
  final Locale locale;
  @override
  Locale build() => locale;
  @override
  Future<void> setLocale(Locale locale) async => state = locale;
}

class _Channels extends NotificationChannelsController {
  @override
  Future<List<Map<String, dynamic>>> build() async => [
    {
      'channel_type': 'whatsapp',
      'config': {'phone_number': '+96891234567', 'phone': '+11111111111'},
    },
    {
      'channel_type': 'email',
      'config': {'email_address': 'not-verified@example.com'},
    },
  ];
}

class _Sims extends SimLinesController {
  @override
  Future<List<SimLine>> build() async => const [
    SimLine(id: '1', userId: 'u', phoneNumber: '+96891234567'),
    SimLine(id: '2', userId: 'u', phoneNumber: '+96892345678'),
  ];
}

class _Prefs extends UserPreferencesController {
  @override
  Future<UserPreferences> build() async =>
      const UserPreferences(id: 'p', userId: 'u');
  @override
  Future<void> updateLanguage(String code) async {
    state = AsyncData(state.requireValue.copyWith(language: code));
  }
}

class _Fx extends FxController {
  _Fx(this.store, {this.succeeds = true});
  final _Store store;
  final bool succeeds;
  final saved = <String>[];
  static const options = [
    FxCurrencyOption(code: 'USD', name: 'US Dollar', symbol: r'$'),
    FxCurrencyOption(
      code: 'OMR',
      name: 'Omani Rial',
      symbol: 'OMR',
      decimalDigits: 3,
    ),
    FxCurrencyOption(code: 'EUR', name: 'Euro', symbol: '€'),
  ];
  @override
  Future<FxContext> build() async => FxContext(
    requestedCurrency: store.profile.preferredCurrency,
    available: options,
  );
  @override
  Future<bool> setDisplayCurrency(String code) async {
    saved.add(code);
    if (!succeeds) return false;
    store.profile = store.profile.copyWith(preferredCurrency: code);
    ref.invalidate(authControllerProvider);
    state = AsyncData(FxContext(requestedCurrency: code, available: options));
    return true;
  }
}

class _Repo extends Mock implements ProfileContract {}

Future<void> _mount(
  WidgetTester tester,
  _Store store, {
  _Fx? fx,
  _Repo? repo,
  bool emailFails = false,
  Locale locale = const Locale('en'),
  double width = 430,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/sim-lines',
        builder: (_, _) => const Scaffold(body: Text('SIM list destination')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) =>
            const Scaffold(body: Text('Notifications destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _Auth(store)),
        localeControllerProvider.overrideWith(() => _Locale(locale)),
        fxControllerProvider.overrideWith(() => fx ?? _Fx(store)),
        notificationChannelsControllerProvider.overrideWith(_Channels.new),
        simLinesControllerProvider.overrideWith(_Sims.new),
        userPreferencesControllerProvider.overrideWith(_Prefs.new),
        unreadNotificationsCountProvider.overrideWith((ref) => 12),
        profileNotificationEmailStatusProvider.overrideWith((ref) async {
          if (emailFails) throw StateError('offline');
          return const NotificationEmailStatus(
            currentEmail: 'alerts@example.com',
            alternateEmail: 'alerts@example.com',
          );
        }),
        supportedCountriesProvider.overrideWith(
          (ref) async => const [
            Country(
              id: 'om',
              name: 'Oman',
              isoCode: 'OM',
              dialingCode: '+968',
              currencyCode: 'OMR',
            ),
            Country(
              id: 'eg',
              name: 'Egypt',
              isoCode: 'EG',
              dialingCode: '+20',
              currencyCode: 'EGP',
            ),
          ],
        ),
        if (repo != null) profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00647C)),
        ),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const UserProfile()));

  test(
    'identity edit payload cannot overwrite currency or notification phone',
    () {
      const profile = UserProfile(
        fullName: 'New Name',
        homeCountryCode: 'OM',
        preferredCurrency: 'EUR',
        phone: '+96891234567',
        isPowerUser: true,
      );
      expect(
        profile.toDetailsWritableJson().keys,
        unorderedEquals(['full_name', 'home_country_code', 'updated_at']),
      );
    },
  );

  testWidgets(
    'shows effective verified email and saved WhatsApp without inventing verification',
    (tester) async {
      await _mount(tester, _Store());
      expect(find.text('alerts@example.com'), findsOneWidget);
      expect(find.text('not-verified@example.com'), findsNothing);
      expect(find.text('+96891234567'), findsOneWidget);
      expect(find.text('+11111111111'), findsNothing);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Omani Rial (OMR)'), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
      await tester.ensureVisible(find.text('Saved SIMs'));
      await tester.tap(find.text('Saved SIMs'));
      await tester.pumpAndSettle();
      expect(find.text('SIM list destination'), findsOneWidget);
    },
  );

  for (final succeeds in [true, false]) {
    testWidgets(
      'currency ${succeeds ? 'saves across the profile' : 'failure leaves a retryable picker'}',
      (tester) async {
        final store = _Store();
        final fx = _Fx(store, succeeds: succeeds);
        await _mount(tester, store, fx: fx);
        await tester.ensureVisible(find.text('Currency'));
        await tester.tap(find.text('Currency'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Euro (EUR)'));
        await tester.pumpAndSettle();
        expect(fx.saved, ['EUR']);
        expect(store.profile.preferredCurrency, succeeds ? 'EUR' : 'OMR');
        expect(find.text('Euro (EUR)'), findsOneWidget);
        expect(
          find.text("Couldn't save your display currency. Please try again."),
          succeeds ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'profile editor validates name, keeps failed edits and saves through the details contract',
    (tester) async {
      final store = _Store();
      final repo = _Repo();
      var fails = true;
      when(() => repo.updateProfileDetails(any())).thenAnswer((
        invocation,
      ) async {
        if (fails) return const Failure(AppFailure.network());
        store.profile = invocation.positionalArguments.first as UserProfile;
        return Success(store.profile);
      });
      await _mount(tester, store, repo: repo);
      await tester.scrollUntilVisible(find.text('Edit profile'), 180);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);
      verifyNever(() => repo.updateProfileDetails(any()));
      await tester.enterText(find.byType(TextFormField), ' Updated Name ');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your changes. Please try again.'),
        findsOneWidget,
      );
      fails = false;
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(store.profile.fullName, 'Updated Name');
      expect(store.profile.preferredCurrency, 'OMR');
      expect(find.text('Updated Name'), findsOneWidget);
      verify(() => repo.updateProfileDetails(any())).called(2);
      verifyNever(() => repo.updateProfile(any()));
    },
  );

  testWidgets('failed email status does not claim verification', (
    tester,
  ) async {
    await _mount(tester, _Store(), emailFails: true);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Check status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic profile fits a narrow screen with larger text', (
    tester,
  ) async {
    await _mount(
      tester,
      _Store(),
      locale: const Locale('ar'),
      width: 320,
      textScale: 1.3,
    );
    expect(find.text('ملفي الشخصي'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تعديل الملف الشخصي'), 180);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
