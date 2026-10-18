import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/features/calling/data/models/second_number_models.dart';
import 'package:keep_sims/features/calling/data/models/available_virtual_number_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _missing() => _json({
  'code': 'PGRST202',
  'message': 'Could not find the function in the schema cache',
}, 404);

final _legacyNumber = {
  'id': 'did-1',
  'phone_number': '+12025550199',
  'country_code': 'US',
  'country_name': 'United States',
  'status': 'active',
  'monthly_fee_usd': 2.5,
  'forward_mode': 'app',
  'renews_at': '2026-11-17T00:00:00Z',
  'created_at': '2026-10-17T00:00:00Z',
};

CallingRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = SupabaseClient(
    'https://example.test',
    'test-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return CallingRepository(client);
}

void main() {
  test('retail quote parses without any supplier or margin fields', () {
    final quote = AvailableVirtualNumber.fromJson({
      'phone_number': '+12025550199',
      'country_code': 'US',
      'total_monthly_usd': 5,
      'setup_fee_usd': 2.3,
      'currency': 'USD',
      'quote_id': 'server-quote',
    });
    expect(quote.totalMonthlyUsd, 5);
    expect(quote.setupFeeUsd, 2.3);
    expect(quote.quoteId, 'server-quote');
  });
  test(
    'new backend retains pending status and verified capabilities',
    () async {
      final repository = _repository((request) async {
        expect(request.url.path, '/rest/v1/rpc/get_second_numbers');
        return _json([
          {
            ..._legacyNumber,
            'status': 'release_pending',
            'supports_sms': true,
            'lifecycle_managed': true,
            'unread_sms_count': 3,
          },
        ]);
      });
      final did = (await repository.getVirtualDids()).single;
      expect(did.status, 'release_pending');
      expect(did.supportsSms, isTrue);
      expect(did.unreadSmsCount, 3);
    },
  );

  test(
    'missing new RPC restores numbers through owner-scoped legacy RPC',
    () async {
      final paths = <String>[];
      final repository = _repository((request) async {
        paths.add(request.url.path);
        if (paths.length == 1) return _missing();
        expect(request.url.path, '/rest/v1/rpc/get_user_dids');
        expect(jsonDecode(request.body), isNull);
        return _json([_legacyNumber]);
      });
      final did = (await repository.getVirtualDids()).single;
      expect(paths.length, 2);
      expect(did.phoneNumber, '+12025550199');
      expect(did.monthlyFeeUsd, 2.5);
      expect(did.supportsSms, isFalse);
      expect(did.lifecycleManaged, isFalse);
    },
  );

  for (final failure in [
    ('42501', 403),
    ('PGRST301', 401),
    ('P0001', 400),
    ('42883', 404),
  ]) {
    test('${failure.$1} remains an error without legacy fallback', () async {
      var requests = 0;
      final repository = _repository((request) async {
        requests++;
        return _json({
          'code': failure.$1,
          'message': 'Unavailable',
        }, failure.$2);
      });
      await expectLater(
        repository.getVirtualDids(),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, 1);
    });
  }

  test('failed legacy read is not presented as no numbers', () async {
    final repository = _repository((request) async {
      if (request.url.path.endsWith('/get_second_numbers')) return _missing();
      return _json({'code': '42501', 'message': 'Denied'}, 403);
    });
    await expectLater(
      repository.getVirtualDids(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'missing optional order RPC is empty; permission failure still surfaces',
    () async {
      var missing = true;
      final repository = _repository((request) async {
        expect(
          request.url.path,
          '/rest/v1/rpc/get_pending_second_number_orders',
        );
        return missing
            ? _missing()
            : _json({'code': '42501', 'message': 'Denied'}, 403);
      });
      expect(await repository.getPendingSecondNumberOrders(), isEmpty);
      missing = false;
      await expectLater(
        repository.getPendingSecondNumberOrders(),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'old deployed Edge never receives inventory or purchase actions',
    () async {
      final actions = <String>[];
      final repository = _repository((request) async {
        final action = (jsonDecode(request.body) as Map)['action'] as String;
        actions.add(action);
        expect(action, 'get_countries');
        return _json({'error': "Unknown action 'get_countries'"}, 400);
      });
      expect(await repository.getSecondNumberCountries(), isEmpty);
      await expectLater(
        repository.searchAvailableNumbers(countryCode: 'US'),
        throwsA(isA<SecondNumberNotEnabled>()),
      );
      await expectLater(
        repository.purchaseSecondNumber(quoteId: 'quote-1', autoRenew: false),
        throwsA(isA<SecondNumberNotEnabled>()),
      );
      expect(actions, ['get_countries', 'get_countries', 'get_countries']);
    },
  );

  test('empty published coverage blocks purchases and inventory', () async {
    final repository = _repository((request) async {
      expect((jsonDecode(request.body) as Map)['action'], 'get_countries');
      return _json({'success': true, 'countries': []});
    });
    await expectLater(
      repository.searchAvailableNumbers(countryCode: 'GB'),
      throwsA(isA<SecondNumberNotEnabled>()),
    );
    await expectLater(
      repository.purchaseSecondNumber(quoteId: 'quote-1', autoRenew: false),
      throwsA(isA<SecondNumberNotEnabled>()),
    );
  });

  test(
    'forbidden, network and server errors do not become disabled coverage',
    () async {
      for (final status in [401, 403, 500]) {
        final repository = _repository(
          (_) async => _json({'error': 'Unavailable'}, status),
        );
        await expectLater(
          repository.getSecondNumberCountries(),
          throwsA(isA<SecondNumberFailure>()),
        );
      }
      final repository = _repository(
        (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        repository.getSecondNumberCountries(),
        throwsA(isA<http.ClientException>()),
      );
    },
  );

  test(
    'validated coverage permits quoted purchase with exact quote and consent',
    () async {
      final actions = <String>[];
      final repository = _repository((request) async {
        final body = jsonDecode(request.body) as Map;
        actions.add(body['action'] as String);
        if (body['action'] == 'get_countries') {
          return _json({
            'success': true,
            'countries': [
              {'country_code': 'US', 'country_name': 'United States'},
            ],
          });
        }
        expect(body, {
          'action': 'purchase_number',
          'quote_id': 'quote-1',
          'auto_renew': false,
        });
        return _json({
          'success': true,
          'order': {
            'id': 'quote-1',
            'state': 'provisioning',
            'phone_number': '+12025550199',
          },
        });
      });
      expect(
        (await repository.purchaseSecondNumber(
          quoteId: 'quote-1',
          autoRenew: false,
        )).isPending,
        isTrue,
      );
      expect(actions, ['get_countries', 'purchase_number']);
    },
  );
}
