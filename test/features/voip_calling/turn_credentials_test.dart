import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/features/voip_calling/data/models/ice_server_model.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/webrtc_audio_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late VoipCallingRepository repository;
  late Map<String, dynamic> response;
  late int status;
  const relay = {
    'urls': ['turn:relay.test:3478'],
    'username': 'test-only-ephemeral-user',
    'credential': 'test-only-ephemeral-password',
  };
  setUp(() {
    status = 200;
    response = {
      'ok': true,
      'call_id': 'call-1',
      'ice_servers': [relay],
    };
    client = SupabaseClient(
      'https://example.test',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    repository = VoipCallingRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'uses only relay credentials returned by the authorized backend',
    () async {
      final servers = await repository.getCallIceServers('call-1');
      expect(servers, hasLength(1));
      expect(servers.single.username, relay['username']);
      expect(servers.single.credential, relay['credential']);
      expect(servers.single.urls, relay['urls']);
      final call = await repository.initiateCall(calleeId: 'callee');
      expect(call.iceServers.single.credential, relay['credential']);
    },
  );

  test(
    'an unavailable backend never supplies bundled relay credentials',
    () async {
      status = 503;
      response = {'code': 'PROVIDER_NOT_CONFIGURED'};
      await expectLater(
        repository.getCallIceServers('call-1'),
        throwsException,
      );
      await expectLater(
        repository.initiateCall(calleeId: 'callee'),
        throwsException,
      );
    },
  );

  test('STUN-only and unauthenticated relay responses fail closed', () async {
    for (final servers in [
      <Map<String, dynamic>>[],
      [
        {
          'urls': ['stun:stun.test'],
        },
      ],
      [
        {
          'urls': ['turn:relay.test:3478'],
          'username': 'test-only-user',
        },
      ],
    ]) {
      response['ice_servers'] = servers;
      await expectLater(
        repository.getCallIceServers('call-1'),
        throwsStateError,
      );
      await expectLater(
        repository.initiateCall(calleeId: 'callee'),
        throwsException,
      );
    }
  });

  test(
    'WebRTC refuses absent relay configuration before opening native media',
    () async {
      final service = WebRTCAudioService();
      await expectLater(
        service.initialize(
          iceServers: [
            const IceServerModel(urls: ['stun:stun.test']),
          ],
        ),
        throwsStateError,
      );
      expect(service.peerConnection, isNull);
    },
  );
}
