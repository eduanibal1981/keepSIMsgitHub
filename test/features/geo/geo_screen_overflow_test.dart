import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/geo/controller/geo_controller.dart';
import 'package:keep_sims/features/geo/model/geo_state.dart';
import 'package:keep_sims/features/geo/ui/geo_screen.dart';
import 'package:keep_sims/features/notifications/data/models/user_preferences_model.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/sim_lines/data/models/country_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class _FakeGeoController extends GeoController {
  @override
  GeoState build() {
    return const GeoState(
      currentCountry: 'Oman',
      currentIsoCode: 'OM',
      travelModeEnabled: true,
      promptFreeze: false,
      promptResume: false,
      logs: [],
    );
  }
}

class _FakeSimLinesController extends SimLinesController {
  final List<SimLine> lines;
  _FakeSimLinesController(this.lines);

  @override
  Future<List<SimLine>> build() async => lines;
}

class _FakeAuthController extends AuthController {
  @override
  Future<UserProfile?> build() async {
    return const UserProfile(
      id: 'test-user',
      email: 'test@example.com',
      homeCountryCode: 'US',
    );
  }
}

class _FakeUserPreferencesController extends UserPreferencesController {
  @override
  Future<UserPreferences> build() async {
    return const UserPreferences(
      id: 'pref-1',
      userId: 'test-user',
      travelModeEnabled: true,
    );
  }
}

void main() {
  testWidgets('GeoScreen renders without overflow on 360px mobile screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockCountries = [
      Country(id: 'c-om', name: 'Oman', isoCode: 'OM', dialingCode: '+968', currencyCode: 'OMR'),
      Country(id: 'c-us', name: 'United States', isoCode: 'US', dialingCode: '+1', currencyCode: 'USD'),
    ];

    final mockLines = [
      const SimLine(id: 'l-1', userId: 'u-1', phoneNumber: '+96893990492', countryId: 'c-om', status: 'active'),
      const SimLine(id: 'l-2', userId: 'u-1', phoneNumber: '+96893990494', countryId: 'c-om', status: 'active'),
      const SimLine(id: 'l-3', userId: 'u-1', phoneNumber: '+96893990496', countryId: 'c-om', status: 'active'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geoControllerProvider.overrideWith(() => _FakeGeoController()),
          authControllerProvider.overrideWith(() => _FakeAuthController()),
          userPreferencesControllerProvider.overrideWith(() => _FakeUserPreferencesController()),
          simLinesControllerProvider.overrideWith(() => _FakeSimLinesController(mockLines)),
          supportedCountriesProvider.overrideWith((ref) async => mockCountries),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GeoScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify sections rendered without layout overflow exception
    expect(find.text('International SIM Lines'), findsOneWidget);
    expect(find.text('Freeze International Lines'), findsOneWidget);
    expect(find.text('Resume International Lines'), findsOneWidget);
    expect(find.text('+96893990492'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
