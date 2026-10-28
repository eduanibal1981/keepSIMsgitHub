import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/esim/data/repositories/esim_go_repository_impl.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';

void main() {
  test(
    'comparison uses v2 server filtering and retains daily facts through the repository',
    () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/compare_esim_offers_v2');
          expect(jsonDecode(request.body)['p_plan_types'], ['daily_cutoff']);
          return http.Response(
            jsonEncode([
              {
                'source_code': 'esimaccess',
                'offer_id': 'code',
                'data_amount_mb': 1024,
                'is_unlimited': false,
                'price_usd': 4.4,
                'catalogue_details': {
                  'plan_type': 'daily_cutoff',
                  'allowance_bytes': '1073741824',
                  'product_alias': 'stable',
                  'supplier_product_id': 'code',
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final offers = await EsimGoRepositoryImpl(supabase: client).compareOffers(
        'OM',
        filters: const CompareFilters(planTypes: ['daily_cutoff']),
      );
      expect(offers.single.formattedData, '1 GB/day');
      expect(offers.single.facts.text('product_alias'), 'stable');
      expect(offers.single.exactSpeedDetail, contains('Data stops'));
    },
  );

  test(
    'legacy plan listing reads the retail view and preserves supplied facts',
    () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/esim_offers');
          expect(
            request.url.queryParameters['select'],
            contains('catalogue_details'),
          );
          expect(
            request.url.queryParameters['select'],
            isNot(contains('wholesale')),
          );
          return http.Response(
            jsonEncode([
              {
                'id': 'esimaccess_code',
                'provider': 'esimaccess',
                'bundle_name': 'code',
                'countries': ['OM'],
                'data_amount_mb': 1024,
                'duration_days': 1,
                'retail_price_usd': 4.4,
                'is_unlimited': false,
                'catalogue_details': {
                  'plan_type': 'daily_throttled',
                  'allowance_bytes': '1073741824',
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final plans = await EsimGoRepositoryImpl(supabase: client).getPlans('OM');
      expect(plans.single.formattedData, '1 GB/day');
      expect(plans.single.pricePerGb, isNull);
      expect(plans.single.isUnlimited, isFalse);
    },
  );
}
