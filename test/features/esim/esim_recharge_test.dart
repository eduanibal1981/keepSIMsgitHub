import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_go_repository_impl.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_recharge.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/presentation/controllers/esim_recharge_controller.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_recharge_screen.dart';
import 'esim_installation_fixtures.dart';

Map<String, dynamic> offer([int type = 1]) => {
  'package_id': 'TOPUP_A',
  'title': 'Fixture recharge',
  'retail_total': 1.73,
  'allowance_bytes': '1073741824',
  'duration_value': 7,
  'duration_unit': 'DAY',
  'data_type': type,
  'effect': type == 1 ? 'allowance_and_validity' : 'validity_only',
  'quote_supported': type == 1,
};
Map<String, dynamic> quote({
  String balance = 'unknown',
  String owner = 'fixture-owner',
  DateTime? expiry,
}) => {
  'status': 'QUOTED',
  'quote_id': 'quote',
  'owner_id': owner,
  'payer_id': owner,
  'profile_id': 'fixture-profile',
  'expires_at': (expiry ?? DateTime.now().add(const Duration(minutes: 2)))
      .toUtc()
      .toIso8601String(),
  'offer': offer(),
  'balance_state': balance,
  'available_balance': balance == 'unknown' ? null : 1,
  'acceptance_enabled': false,
};

class Repo extends Fake implements EsimRepository {
  Completer<EsimRechargeQuote>? pending;
  @override
  Future<EsimRechargeDiscovery> discoverTopups(String id) async =>
      EsimRechargeDiscovery.fromJson({
        'status': 'READY',
        'offers': [offer(), offer(2)],
        'offer_version': 'version',
      });
  @override
  Future<EsimRechargeQuote> quoteTopup(
    String a,
    String b,
    String c,
    double d,
  ) async =>
      pending?.future ??
      EsimRechargeQuote.fromJson(quote(balance: 'insufficient'));
}

void main() {
  test(
    'fixed and daily effects preserve quantities and never invent confirmed expiry',
    () {
      expect(
        EsimRechargeOffer.fromJson(offer()).effectLabel,
        contains('allowance and validity'),
      );
      expect(
        EsimRechargeOffer.fromJson(offer(2)).behaviorLabel,
        contains('Speed reduces'),
      );
      expect(
        EsimRechargeOffer.fromJson(offer(3)).behaviorLabel,
        contains('Data stops'),
      );
      expect(
        EsimRechargeOffer.fromJson({
          ...offer(4),
          'allowance_bytes': '0',
        }).allowanceLabel,
        'Unlimited daily data',
      );
      expect(
        EsimRechargeQuote.fromJson(quote()).balanceLabel,
        contains('unknown'),
      );
      expect(
        EsimRechargeQuote.fromJson(quote(balance: 'insufficient')).balanceLabel,
        contains('Reserved funds'),
      );
      expect(
        EsimRechargeQuote.fromJson(
          quote(expiry: DateTime.now().subtract(const Duration(seconds: 1))),
        ).expired,
        isTrue,
      );
    },
  );
  test(
    'repository calls only discovery/quote Edge with exact reviewed identity and price',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/functions/v1/esim-recharge-discovery');
          final b = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          bodies.add(b);
          return http.Response(
            jsonEncode(
              b['action'] == 'discover'
                  ? {'status': 'NO_COMPATIBLE_OFFERS'}
                  : quote(),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = EsimGoRepositoryImpl(supabase: client);
      expect(
        (await repo.discoverTopups('exact')).status,
        'NO_COMPATIBLE_OFFERS',
      );
      await repo.quoteTopup('exact', 'TOPUP_A', 'version', 1.73);
      expect(bodies, [
        {'action': 'discover', 'profile_id': 'exact'},
        {
          'action': 'quote',
          'profile_id': 'exact',
          'package_id': 'TOPUP_A',
          'offer_version': 'version',
          'expected_total': 1.73,
        },
      ]);
    },
  );
  test(
    'provider/HTTP failure stays unavailable rather than an empty list or zero balance',
    () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((r) async => http.Response('PRIVATE', 503)),
      );
      addTearDown(client.dispose);
      final repo = EsimGoRepositoryImpl(supabase: client);
      expect(
        (await repo.discoverTopups('id')).status,
        'TEMPORARILY_UNAVAILABLE',
      );
      final q = await repo.quoteTopup('id', 'P', 'v', 1);
      expect(q.balanceState, 'unknown');
      expect(q.availableBalance, isNull);
    },
  );
  Future<(ProviderContainer, Repo)> screen(WidgetTester tester) async {
    final repo = Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => InstallationAuthFixture()),
          userEsimsControllerProvider.overrideWith(
            () => InstallationProfilesFixture(installationFixture()),
          ),
          esimRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: EsimRechargeScreen(profileId: 'fixture-profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      ProviderScope.containerOf(
        tester.element(find.byType(EsimRechargeScreen)),
      ),
      repo,
    );
  }

  testWidgets(
    'read-only screen displays effects, provisional expiry and reserved-balance refusal without a payment control',
    (tester) async {
      await screen(tester);
      expect(find.textContaining('Preview only.'), findsOneWidget);
      expect(find.text('Adds allowance and validity'), findsOneWidget);
      await tester.tap(find.text('Preview quote').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Insufficient available'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Reserved funds'), findsOneWidget);
      expect(
        find.text('Payment is unavailable until recharge is enabled.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Pay'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'account change hides a pending old-owner quote and cancels its provider authority',
    (tester) async {
      final (container, repo) = await screen(tester);
      repo.pending = Completer<EsimRechargeQuote>();
      await tester.tap(find.text('Preview quote').first);
      await tester.pump();
      (container.read(authControllerProvider.notifier)
              as InstallationAuthFixture)
          .signInAs('different-owner');
      await tester.pumpAndSettle();
      repo.pending!.complete(EsimRechargeQuote.fromJson(quote()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('unavailable for this account'),
        findsOneWidget,
      );
      expect(find.textContaining('Quote: USD'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'controller refuses a server quote bound to another owner or profile',
    () async {
      final repo = Repo();
      repo.pending = Completer<EsimRechargeQuote>()
        ..complete(EsimRechargeQuote.fromJson(quote(owner: 'other')));
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => InstallationAuthFixture()),
          esimRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final p = esimRechargeQuoteProvider((
        profileId: 'fixture-profile',
        packageId: 'TOPUP_A',
        version: 'version',
        total: 1.73,
      ));
      expect((await container.read(p.future)).status, 'QUOTE_UNAVAILABLE');
    },
  );
}
