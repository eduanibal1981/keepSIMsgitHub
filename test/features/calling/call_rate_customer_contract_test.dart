import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/features/calling/data/models/call_rate_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('customer rate serialization retains retail pricing only', () {
    final rate = CallRate.fromJson({
      'id': 'rate',
      'country_code': 'OM',
      'cost_per_minute_usd': 0.01,
      'effective_rate_per_minute_usd': 0.02,
    });
    expect(rate.ratePerMinute, 0.02);
    expect(rate.toJson().containsKey('cost_per_minute_usd'), isFalse);
  });

  test('legacy catalogue fallback requests explicit retail columns', () async {
    var fallbackRead = false;
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/get_user_calling_rates')) {
          return http.Response(
            '{"message":"RPC unavailable"}',
            404,
            request: request,
          );
        }
        expect(request.url.path, '/rest/v1/call_rates');
        final columns = request.url.queryParameters['select']!;
        expect(columns.contains('*'), isFalse);
        expect(columns.contains('cost_per_minute_usd'), isFalse);
        expect(columns.contains('rate_per_minute_usd'), isTrue);
        fallbackRead = true;
        return http.Response(
          jsonEncode([
            {
              'id': 'rate',
              'country_code': 'OM',
              'country_name': 'Oman',
              'phone_prefix': '+968',
              'rate_per_minute_usd': 0.02,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final rates = await CallingRepository(client).getActiveCallRates();
    expect(fallbackRead, isTrue);
    expect(rates.single.ratePerMinute, 0.02);
  });
}
