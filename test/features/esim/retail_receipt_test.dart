import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_go_repository_impl.dart';
import 'package:keep_sims/features/esim/domain/entities/esim_order.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';

final receipt = {
  'id': 'order',
  'user_id': 'owner',
  'provider': 'fixture',
  'bundle_name': 'bundle',
  'quantity': 1,
  'retail_price_usd': 2.2,
  'status': 'completed',
  'created_at': '2026-10-18T00:00:00Z',
  'updated_at': '2026-10-18T00:00:00Z',
};
SupabaseClient client(Future<http.Response> Function(http.Request) handler) {
  final c = SupabaseClient(
    'https://example.test',
    'test-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((r) async {
      final response = await handler(r);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: r,
      );
    }),
  );
  addTearDown(c.dispose);
  return c;
}

http.Response json(Object v) => http.Response(
  jsonEncode(v),
  200,
  headers: {'content-type': 'application/json'},
);
void main() {
  test(
    'history queries the safe receipt projection with explicit retail columns',
    () async {
      final r = EsimGoRepositoryImpl(
        supabase: client((q) async {
          expect(q.url.path, '/rest/v1/customer_esim_orders');
          expect(q.url.queryParameters['select'], isNot(contains('wholesale')));
          expect(q.url.queryParameters['select'], isNot('*'));
          return json([receipt]);
        }),
      );
      expect((await r.getOrderHistory()).single.retailPriceUsd, 2.2);
    },
  );
  test(
    'order stream immediately polls a retail receipt and keeps the total',
    () async {
      final r = EsimGoRepositoryImpl(
        supabase: client((q) async {
          expect(q.url.path, '/rest/v1/customer_esim_orders');
          expect(q.url.queryParameters['id'], 'eq.order');
          return json([receipt]);
        }),
      );
      expect((await r.watchOrder('order').first)!.status, 'completed');
    },
  );
  test(
    'receipt model does not serialize supplier cost, markup or references',
    () {
      final order = EsimOrder.fromJson({
        'id': 'order',
        'userId': 'owner',
        'provider': 'fixture',
        'bundleName': 'bundle',
        'quantity': 1,
        'retailPriceUsd': 2.2,
        'status': 'completed',
        'createdAt': '2026-10-18T00:00:00Z',
        'updatedAt': '2026-10-18T00:00:00Z',
        'wholesalePriceUsd': 2,
        'markupPercent': 10,
        'providerOrderRef': 'private',
      });
      expect(order.toJson().keys, isNot(contains('wholesalePriceUsd')));
      expect(order.toJson().keys, isNot(contains('markupPercent')));
      expect(order.toJson().keys, isNot(contains('providerOrderRef')));
    },
  );
  test(
    'catalogue keeps the composite offer identity and retail price',
    () async {
      final r = EsimGoRepositoryImpl(
        supabase: client((q) async {
          expect(q.url.path, '/rest/v1/esim_offers');
          return json([
            {
              'id': 'fixture_bundle',
              'provider': 'fixture',
              'bundle_name': 'bundle',
              'countries': ['ZZ'],
              'roaming_enabled': [],
              'data_amount_mb': 1024,
              'duration_days': 7,
              'retail_price_usd': 2.2,
            },
          ]);
        }),
      );
      final plan = (await r.getPlans('ZZ')).single;
      expect(plan.id, 'fixture_bundle');
      expect(plan.priceUsd, 2.2);
    },
  );
  test('call status reads the retail call projection', () async {
    final r = CallingRepository(
      client((q) async {
        expect(q.url.path, '/rest/v1/customer_call_records');
        return json({
          'id': 'call',
          'user_id': 'owner',
          'started_at': '2026-10-18T00:00:00Z',
          'caller_number': '+10000000001',
          'destination_number': '+10000000002',
          'rate_per_minute_usd': .02,
        });
      }),
    );
    expect((await r.getCallRecord('call'))!.ratePerMinute, .02);
  });
}
