import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';

void main() {
  late SupabaseClient client;
  late CallingRepository repository;
  late Map<String, dynamic> response;
  late int status;
  late Map<String, dynamic> body;
  setUp(() {
    status = 200;
    response = {
      'success': true,
      'eligible': true,
      'effectiveCallerId': '+17543180369',
      'callerIdType': 'gateway',
      'walletBalance': 10,
      'destination': {
        'number': '+201012345678',
        'countryCode': 'EG',
        'countryName': 'Egypt',
        'ratePerMinute': .095,
        'connectionFee': .02,
        'billingIncrementSeconds': 60,
      },
    };
    client = SupabaseClient(
      'https://example.test',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = CallingRepository(client);
  });
  tearDown(() async => client.dispose());
  test(
    'preview submits canonical destination and the exact selected identity',
    () async {
      final result = await repository.previewCall(
        destinationNumber: '+201012345678',
        callerIdId: 'chosen-id',
        explicitGateway: false,
      );
      expect(body['action'], 'preview');
      expect(body['destinationNumber'], '+201012345678');
      expect(body['callerIdId'], 'chosen-id');
      expect(body['explicitGateway'], isFalse);
      expect(result.rate?.ratePerMinute, .095);
      expect(result.connectionFee, .02);
      expect(result.billingIncrementSeconds, 60);
    },
  );
  test('quote for a different destination is rejected', () async {
    (response['destination'] as Map)['number'] = '+96892312854';
    await expectLater(
      repository.previewCall(destinationNumber: '+201012345678'),
      throwsException,
    );
  });
  test('unavailable or malformed rates cannot appear free', () async {
    for (final value in [0, -1]) {
      (response['destination'] as Map)['ratePerMinute'] = value;
      await expectLater(
        repository.previewCall(destinationNumber: '+201012345678'),
        throwsException,
      );
    }
    response.remove('destination');
    await expectLater(
      repository.previewCall(destinationNumber: '+201012345678'),
      throwsException,
    );
  });
  test('caller ID loading failures never fabricate a gateway number', () async {
    status = 503;
    response = {};
    await expectLater(repository.getCallerIdList(), throwsException);
    status = 200;
    response = {'callerIds': []};
    await expectLater(repository.getCallerIdList(), throwsException);
  });
  test('caller ID list uses the gateway supplied by the backend', () async {
    response = {
      'callerIds': [],
      'defaultGatewayNumber': '+12025550199',
      'isGatewayActive': true,
    };
    expect(
      (await repository.getCallerIdList()).defaultGatewayNumber,
      '+12025550199',
    );
  });
}
