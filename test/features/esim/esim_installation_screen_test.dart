import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/services/esim_capability_service.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/services/esim_installation_service.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_installation_policy.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_installation_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_delivery_screen.dart';
import 'esim_installation_fixtures.dart';

class _UnsupportedDevice extends EsimCapabilityService {
  @override
  Future<bool> build() async => false;
}

void main() {
  Future<void> bring(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  const ios = EsimInstallationEnvironment(
    platform: EsimInstallPlatform.ios,
    major: 17,
    minor: 4,
    physicalDevice: true,
  );
  Future<ProviderContainer> screen(
    WidgetTester tester,
    UserEsim profile, {
    String? owner = 'fixture-owner',
    EsimInstallationEnvironment? environment,
    Future<EsimInstallationEnvironment>? environmentResult,
    Future<bool> Function(Uri)? launch,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => InstallationAuthFixture(owner),
          ),
          userEsimsControllerProvider.overrideWith(
            () => InstallationProfilesFixture(profile),
          ),
          esimInstallationEnvironmentProvider.overrideWith(
            (ref) =>
                environmentResult ??
                Future.value(
                  environment ??
                      const EsimInstallationEnvironment(
                        platform: EsimInstallPlatform.android,
                      ),
                ),
          ),
          esimInstallationServiceProvider.overrideWith(
            (ref) => EsimInstallationService(launch: launch),
          ),
        ],
        child: MaterialApp(home: EsimDeliveryScreen(esim: profile)),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(EsimDeliveryScreen)),
    );
  }

  testWidgets(
    'non-owners and signed-out users cannot see QR, manual details or install actions',
    (tester) async {
      for (final owner in <String?>['other', null]) {
        await screen(tester, installationFixture(), owner: owner);
        expect(find.byType(QrImageView), findsNothing);
        expect(find.text('private-code'), findsNothing);
        expect(find.text('Open Apple eSIM setup'), findsNothing);
      }
    },
  );
  testWidgets(
    'owned QR renders locally with manual entry and an honest offline distinction',
    (tester) async {
      var launched = false;
      await screen(
        tester,
        installationFixture(),
        launch: (_) async {
          launched = true;
          return true;
        },
      );
      await bring(tester, find.byType(QrImageView));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(launched, false);
      expect(find.byType(Image), findsNothing);
      await bring(tester, find.text('Copy SM-DP+ address'));
      expect(find.text('fixture.invalid'), findsOneWidget);
      expect(find.text('private-code'), findsOneWidget);
    },
  );
  testWidgets(
    'installed profiles show help instead of another QR or install button',
    (tester) async {
      await screen(
        tester,
        installationFixture({
          'installation_state': 'enabled',
          'profile_state': 'active',
        }),
        environment: ios,
      );
      expect(
        find.textContaining('already been downloaded or installed'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Open Apple eSIM setup'), findsNothing);
    },
  );
  testWidgets(
    'expired and missing activation data have useful fallback with no code',
    (tester) async {
      await screen(tester, installationFixture({'profile_state': 'expired'}));
      expect(
        find.textContaining('expired, cancelled or revoked'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await screen(tester, installationFixture({'issuance_verified': false}));
      expect(
        find.textContaining('awaiting provider verification'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
    },
  );
  testWidgets(
    'same-device recovery code stays hidden until the owner confirms the original device',
    (tester) async {
      await screen(
        tester,
        installationFixture({
          'installation_state': 'deleted',
          'profile_state': 'active',
          'bundle_state': 'active',
          'expires_at': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
        }),
      );
      expect(find.byType(QrImageView), findsNothing);
      await bring(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await bring(tester, find.byType(QrImageView));
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );
  testWidgets(
    'opening Apple setup is a user action and never confirms installation',
    (tester) async {
      final urls = <Uri>[];
      await screen(
        tester,
        installationFixture(),
        environment: ios,
        launch: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      expect(urls, isEmpty);
      await bring(tester, find.text('Open Apple eSIM setup'));
      await tester.tap(find.text('Open Apple eSIM setup'));
      await tester.pumpAndSettle();
      expect(urls.length, 1);
      await bring(tester, find.byKey(const ValueKey('installation-notice')));
      expect(
        find.textContaining('does not confirm installation'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'account switch while checking native support prevents the queued launch',
    (tester) async {
      final ready = Completer<EsimInstallationEnvironment>();
      var launches = 0;
      final container = await screen(
        tester,
        installationFixture(),
        environmentResult: ready.future,
        launch: (_) async {
          launches++;
          return true;
        },
      );
      final action = container
          .read(esimInstallationControllerProvider)
          .openApple(installationFixture());
      (container.read(authControllerProvider.notifier)
              as InstallationAuthFixture)
          .signInAs('other');
      ready.complete(ios);
      expect(await action, EsimInstallLaunchResult.unavailable);
      expect(launches, 0);
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
    },
  );
  testWidgets(
    'installation and recovery layout remains usable on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await screen(tester, installationFixture());
      await bring(tester, find.text('Contact KeepSIMs support'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'owned profiles remain accessible when the display device cannot provision eSIMs',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/esim',
        routes: [GoRoute(path: '/esim', builder: (_, _) => const EsimScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => InstallationAuthFixture(),
            ),
            userEsimsControllerProvider.overrideWith(
              () => InstallationProfilesFixture(installationFixture()),
            ),
            esimCapabilityServiceProvider.overrideWith(_UnsupportedDevice.new),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await bring(tester, find.text('Fixture travel plan'));
      expect(find.text('My eSIMs'), findsOneWidget);
      expect(find.text('Installation & recovery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
