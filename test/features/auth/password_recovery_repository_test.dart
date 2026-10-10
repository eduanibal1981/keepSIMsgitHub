import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/features/auth/repository/password_recovery_repository.dart';

Map<String, dynamic> _session({
  String email = 'owner@example.com',
  bool expired = false,
}) {
  final exp =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600);
  final payload = base64Url.encode(utf8.encode(jsonEncode({'exp': exp})));
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
    'refresh_token': 'recovery-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 'recovery-user',
      'email': email,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

void main() {
  late PasswordRecoveryRepository repository;
  late List<http.Request> requests;
  late Map<String, dynamic> sessionData;
  late Future<http.Response> Function(http.Request) handler;

  setUp(() {
    requests = [];
    sessionData = _session();
    handler = (request) async => switch (request.url.path) {
      '/auth/v1/verify' => http.Response(jsonEncode(sessionData), 200),
      '/auth/v1/user' => http.Response(jsonEncode(sessionData['user']), 200),
      '/auth/v1/logout' => http.Response('', 204),
      _ => http.Response('{}', 200),
    };
    repository = PasswordRecoveryRepository(
      authUrl: Uri.parse('https://example.supabase.co/auth/v1'),
      apiKey: 'public-key',
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  });

  tearDown(() => repository.dispose());

  Future<void> verify() async {
    expect(
      await repository.sendCode('owner@example.com'),
      isA<Success<void>>(),
    );
    expect(
      await repository.verifyCode('owner@example.com', '12345678'),
      isA<Success<void>>(),
    );
  }

  test(
    'uses recovery OTP, updates with verified token, and discards session',
    () async {
      expect(
        await repository.sendCode(' Owner@Example.com '),
        isA<Success<void>>(),
      );
      expect(jsonDecode(requests.single.body), {'email': 'owner@example.com'});
      expect(requests.single.headers['apikey'], 'public-key');
      expect(
        await repository.verifyCode('owner@example.com', ' 12345678 '),
        isA<Success<void>>(),
      );
      expect(jsonDecode(requests.last.body), {
        'email': 'owner@example.com',
        'token': '12345678',
        'type': 'recovery',
      });
      expect(
        await repository.resetPassword(' new password '),
        isA<Success<void>>(),
      );
      final update = requests.singleWhere((request) => request.method == 'PUT');
      expect(jsonDecode(update.body), {'password': ' new password '});
      expect(
        update.headers['authorization'],
        'Bearer ${sessionData['access_token']}',
      );
      expect(requests.last.url.queryParameters['scope'], 'local');
      final count = requests.length;
      expect(
        await repository.resetPassword('another-password'),
        isA<Failure<void>>(),
      );
      expect(requests.length, count);
    },
  );

  test('cannot update a password before verification', () async {
    expect(
      await repository.resetPassword('new-password'),
      isA<Failure<void>>(),
    );
    expect(requests, isEmpty);
    await repository.sendCode('owner@example.com');
    expect(
      await repository.resetPassword('new-password'),
      isA<Failure<void>>(),
    );
    expect(requests, hasLength(1));
  });

  test('invalid or expired code never authorizes a password update', () async {
    await repository.sendCode('owner@example.com');
    handler = (_) async => http.Response(
      jsonEncode({'code': 'otp_expired', 'msg': 'Token expired'}),
      403,
    );
    final result = await repository.verifyCode('owner@example.com', '000000');
    expect(result, isA<Failure<void>>());
    expect(
      (result as Failure<void>).error.message,
      contains('invalid or has expired'),
    );
    expect(
      await repository.resetPassword('new-password'),
      isA<Failure<void>>(),
    );
    expect(requests.any((request) => request.method == 'PUT'), isFalse);
  });

  test('verification requires the email used to request the code', () async {
    await repository.sendCode('owner@example.com');
    expect(
      await repository.verifyCode('other@example.com', '123456'),
      isA<Failure<void>>(),
    );
    expect(requests, hasLength(1));
  });

  test('rejects a verification response without a recovery session', () async {
    await repository.sendCode('owner@example.com');
    handler = (_) async =>
        http.Response(jsonEncode({'user': _session()['user']}), 200);
    expect(
      await repository.verifyCode('owner@example.com', '123456'),
      isA<Failure<void>>(),
    );
    expect(
      await repository.resetPassword('new-password'),
      isA<Failure<void>>(),
    );
  });

  test('rejects a session belonging to another email', () async {
    await repository.sendCode('owner@example.com');
    handler = (_) async =>
        http.Response(jsonEncode(_session(email: 'other@example.com')), 200);
    expect(
      await repository.verifyCode('owner@example.com', '123456'),
      isA<Failure<void>>(),
    );
    expect(
      await repository.resetPassword('new-password'),
      isA<Failure<void>>(),
    );
  });

  test(
    'rejects an expired recovery session without sending the password',
    () async {
      await repository.sendCode('owner@example.com');
      handler = (_) async =>
          http.Response(jsonEncode(_session(expired: true)), 200);
      await repository.verifyCode('owner@example.com', '123456');
      expect(
        await repository.resetPassword('new-password'),
        isA<Failure<void>>(),
      );
      expect(requests.any((request) => request.method == 'PUT'), isFalse);
    },
  );

  test(
    'a failed password update can be retried with the verified session',
    () async {
      await verify();
      var attempts = 0;
      handler = (request) async {
        if (request.method == 'PUT' && attempts++ == 0) {
          return http.Response(
            jsonEncode({
              'msg': 'Password should be different from the old password.',
            }),
            422,
          );
        }
        return http.Response('{}', 200);
      };
      expect(
        await repository.resetPassword('old-password'),
        isA<Failure<void>>(),
      );
      expect(
        await repository.resetPassword('different-password'),
        isA<Success<void>>(),
      );
      expect(attempts, 2);
    },
  );

  test(
    'requesting a new code removes previous authorization even on failure',
    () async {
      await verify();
      handler = (_) async =>
          http.Response(jsonEncode({'msg': 'Rate limit exceeded'}), 429);
      expect(
        await repository.sendCode('owner@example.com'),
        isA<Failure<void>>(),
      );
      expect(
        await repository.resetPassword('new-password'),
        isA<Failure<void>>(),
      );
      expect(requests.any((request) => request.method == 'PUT'), isFalse);
    },
  );

  test('network errors give a readable failure', () async {
    handler = (_) async => throw http.ClientException('Offline');
    final result = await repository.sendCode('owner@example.com');
    expect(result, isA<Failure<void>>());
    expect(
      (result as Failure<void>).error.message,
      contains('internet connection'),
    );
  });

  test(
    'logout failure does not turn a successful reset into a failure',
    () async {
      await verify();
      handler = (request) async => request.url.path.endsWith('/logout')
          ? http.Response('{"msg":"Unavailable"}', 500)
          : http.Response('{}', 200);
      expect(
        await repository.resetPassword('new-password'),
        isA<Success<void>>(),
      );
      expect(
        await repository.resetPassword('another-password'),
        isA<Failure<void>>(),
      );
    },
  );

  test('correctly parses real Supabase GoTrue otp_expired error format', () async {
    await repository.sendCode('owner@example.com');
    // Real Supabase GoTrue returns integer code 403, error_code string, and msg
    handler = (_) async => http.Response(
      jsonEncode({
        'code': 403,
        'error_code': 'otp_expired',
        'msg': 'Token has expired or is invalid',
      }),
      403,
    );
    final result = await repository.verifyCode('owner@example.com', '999999');
    expect(result, isA<Failure<void>>());
    expect(
      (result as Failure<void>).error.message,
      'This code is invalid or has expired. Please try again or request a new code.',
    );
  });

  test('recognizes over_email_send_rate_limit from Supabase', () async {
    handler = (_) async => http.Response(
      jsonEncode({
        'code': 429,
        'error_code': 'over_email_send_rate_limit',
        'msg':
            'For security purposes, you can only request this once every 60 seconds',
      }),
      429,
    );
    final result = await repository.sendCode('owner@example.com');
    expect(result, isA<Failure<void>>());
    expect(
      (result as Failure<void>).error.message,
      'Too many requests. Please wait a minute before trying again.',
    );
  });

  test('supports nested session format from GoTrue response', () async {
    await repository.sendCode('owner@example.com');
    handler = (_) async => http.Response(
      jsonEncode({'session': sessionData, 'user': sessionData['user']}),
      200,
    );
    final result = await repository.verifyCode('owner@example.com', '123456');
    expect(result, isA<Success<void>>());
    expect(
      await repository.resetPassword('new-valid-password'),
      isA<Success<void>>(),
    );
  });
}
