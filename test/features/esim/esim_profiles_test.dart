import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/esim/domain/repositories/esim_repository.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_go_repository_impl.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_provider_factory.dart';
import 'package:keep_sims/features/esim/presentation/controllers/user_esims_controller.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_delivery_screen.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_profile_card.dart';
import 'package:keep_sims/features/esim/presentation/widgets/esim_order_status_modal.dart';

Map<String, dynamic> record() => {
  'id': 'fixture-profile',
  'user_id': 'fixture-owner',
  'order_id': 'fixture-order',
  'iccid': '8900000000000000001',
  'lpa_string': 'LPA:1\$fixture.invalid\$private-code',
  'bundle_name': 'Fixture plan',
  'provider': 'esimaccess',
  'status': 'active',
  'profile_state': 'issued',
  'installation_state': 'released',
  'bundle_state': 'not_started',
  'issuance_verified': true,
  'activation_trigger': 'first_network_connection',
  'purchased_at': '2026-10-28T00:00:00Z',
};

class EmptyRepo extends Fake implements EsimRepository {
  @override
  Future<List<UserEsim>> getUserEsims({bool requestRefresh = false}) async =>
      [];
}

void main() {
  test(
    'one mapper reads deployed and captured legacy names without guessed dates',
    () {
      final model = UserEsim.fromRecord(record());
      expect(model.esimOrderId, 'fixture-order');
      expect(model.hasActivationPayload, true);
      final legacy = UserEsim.fromRecord({
        'esim_order_id': 'legacy',
        'lpa_activation_code': 'LPA:1\$fixture.invalid\$legacy-code',
        'last_synced_at': '2026-10-28T00:00:00Z',
      });
      expect(legacy.esimOrderId, 'legacy');
      expect(legacy.lastSyncedAt, isNotNull);
      expect(legacy.purchasedAt, isNull);
      expect(legacy.expiresAt, isNull);
      expect(legacy.issuanceVerified, false);
      expect(legacy.hasActivationPayload, false);
    },
  );
  test(
    'purchase is not installation and missing activation data has no fallback',
    () {
      final model = UserEsim.fromRecord(record());
      expect(model.statusLabel, 'Ready to install');
      expect(model.installationLabel, 'Not installed');
      final missing = UserEsim.fromRecord({'iccid': '8900000000000000001'});
      expect(missing.smdpAddress, '');
      expect(missing.matchingId, '');
      expect(missing.hasActivationPayload, false);
      expect(model.firstActivatedAt, isNull);
      expect(model.expiresAt, isNull);
    },
  );
  test(
    'unknown and zero allowance are distinct; refresh errors preserve values',
    () {
      final unknown = UserEsim.fromRecord(record());
      expect(unknown.usageLabel, 'Usage not provided');
      expect(unknown.hasKnownUsage, false);
      final zero = UserEsim.fromRecord({
        ...record(),
        'data_total_bytes': 1073741824,
        'data_remaining_bytes': 0,
        'data_used_bytes': 1073741824,
      });
      expect(zero.usageLabel, '0 MB / 1 GB');
      expect(zero.hasKnownUsage, true);
      final failed = zero.copyWith(usageErrorCode: 'REFRESH_FAILED');
      expect(failed.usageLabel, zero.usageLabel);
      expect(failed.usageIsStale, true);
    },
  );
  test('default diagnostics never print activation material or ICCID', () {
    final model = UserEsim.fromRecord(record());
    expect(model.toString(), isNot(contains('private-code')));
    expect(model.toString(), isNot(contains(model.iccid)));
    expect(UserEsim.fromJson(model.toJson()), model);
  });
  test(
    'one batched refresh RPC precedes the owner projection with no per-profile requests',
    () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((request) async {
          calls.add(request.url.path);
          final body =
              request.url.path.endsWith('/request_esim_profile_refresh')
              ? {'queued': 2}
              : [
                  record(),
                  {...record(), 'id': 'second'},
                ];
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final profiles = await EsimGoRepositoryImpl(
        supabase: client,
      ).getUserEsims(requestRefresh: true);
      expect(profiles.length, 2);
      expect(calls, [
        '/rest/v1/rpc/request_esim_profile_refresh',
        '/rest/v1/customer_esim_profiles',
      ]);
    },
  );
  testWidgets(
    'profile card fits a narrow screen and shows honest freshness/validity',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EsimProfileCard(
                profile: UserEsim.fromRecord(record()),
                onInstall: () {},
                onBuyNew: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ready to install'), findsOneWidget);
      expect(find.text('Installation: Not installed'), findsOneWidget);
      expect(find.text('Usage not provided'), findsOneWidget);
      expect(find.text('Expiry not confirmed'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unverified legacy credentials cannot render a QR or guessed manual code',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EsimDeliveryScreen(
            esim: UserEsim.fromRecord({
              ...record(),
              'issuance_verified': false,
            }),
          ),
        ),
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.textContaining('awaiting provider verification'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'a completed order with no owned profile never fabricates delivery',
    (tester) async {
      final order = EsimOrder(
        id: 'fixture-order',
        userId: 'owner',
        provider: 'esimaccess',
        bundleName: 'fixture',
        quantity: 1,
        retailPriceUsd: 1,
        status: 'completed',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            esimRepositoryProvider.overrideWithValue(EmptyRepo()),
            esimOrderLiveProvider(
              'fixture-order',
            ).overrideWith((ref) => Stream.value(order)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EsimOrderStatusModal(
                orderId: 'fixture-order',
                bundleName: 'fixture',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View installation'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('still being verified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
