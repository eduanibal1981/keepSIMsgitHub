import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/auth/repository/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Connectivity extends Mock implements ConnectivityService {}

class _NameStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AuthRepository repository;
  late _NameStorage storage;
  late LocalCacheService cache;
  late Map<String, String> pendingNames;
  late List<http.Request> requests;
  late AuthorizationCredentialAppleID credential;
  late Map<String, dynamic> user;
  late String profileName;
  late String? appleNonce;
  late bool failExchange;
  late bool failNameSave;
  late bool failProfileFetch;
  Object? nativeError;

  AuthorizationCredentialAppleID appleCredential({
    String? token = 'apple-id-token',
    String? given = 'Ada',
    String? family = 'Lovelace',
  }) => AuthorizationCredentialAppleID(
    userIdentifier: 'apple-user',
    givenName: given,
    familyName: family,
    email: null, // Returning Apple users often do not receive email again.
    identityToken: token,
    authorizationCode: 'unused-auth-code',
    state: null,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCacheService(await SharedPreferences.getInstance());
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    pendingNames = {};
    requests = [];
    nativeError = null;
    appleNonce = null;
    failExchange = false;
    failNameSave = false;
    failProfileFetch = false;
    profileName = '';
    credential = appleCredential();
    user = {
      'id': 'user-id',
      'email': 'relay@privaterelay.appleid.com',
      'aud': 'authenticated',
      'app_metadata': {'provider': 'apple'},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-10-01T00:00:00Z',
    };
    storage = _NameStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      pendingNames[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => pendingNames[call.namedArguments[#key]]);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((call) async {
      pendingNames.remove(call.namedArguments[#key]);
    });
    final connectivity = _Connectivity();
    when(() => connectivity.isOffline).thenReturn(false);
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body = {};
        var status = 200;
        if (request.url.path == '/auth/v1/token') {
          if (failExchange) {
            body = {
              'msg': 'Provider is not enabled',
              'error_code': 'provider_disabled',
            };
            status = 400;
          } else {
            final payload = base64Url.encode(
              utf8.encode(
                jsonEncode({
                  'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                }),
              ),
            );
            body = {
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user,
            };
          }
        } else if (request.url.path == '/auth/v1/user') {
          if (failNameSave) {
            body = {'msg': 'Temporary failure'};
            status = 503;
          } else {
            user['user_metadata'] = jsonDecode(request.body)['data'];
            body = user;
          }
        } else if (request.url.path == '/rest/v1/profiles') {
          if (request.method == 'PATCH') {
            if (profileName.isEmpty) {
              profileName = jsonDecode(request.body)['full_name'] as String;
            }
            body = <Object>[];
          } else {
            body = {
              'id': user['id'],
              'email': user['email'],
              'full_name': profileName,
            };
            if (failProfileFetch) {
              body = {'message': 'Profile unavailable', 'code': 'test_failure'};
              status = 400;
            }
          }
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = AuthRepository(
      client,
      cache,
      connectivity,
      appleNameStorage: storage,
      appleCredential: (nonce) async {
        appleNonce = nonce;
        if (nativeError != null) throw nativeError!;
        return credential;
      },
    );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await client.dispose();
  });

  test(
    'exchanges the token with the raw nonce and saves the one-time name',
    () async {
      final result = await repository.signInWithApple();
      expect(
        result,
        isA<Success<UserProfile>>(),
        reason: result is Failure<UserProfile> ? result.error.message : null,
      );
      final exchange = requests.firstWhere(
        (r) => r.url.path == '/auth/v1/token',
      );
      final body = jsonDecode(exchange.body);
      expect(body['provider'], 'apple');
      expect(body['id_token'], 'apple-id-token');
      expect(
        sha256.convert(utf8.encode(body['nonce'] as String)).toString(),
        appleNonce,
      );
      expect(appleNonce, isNot(body['nonce']));
      expect(user['user_metadata']['full_name'], 'Ada Lovelace');
      expect((result as Success<UserProfile>).data.fullName, 'Ada Lovelace');
      final update = requests.singleWhere((r) => r.method == 'PATCH');
      expect(update.url.queryParameters['id'], 'eq.user-id');
      expect(
        update.url.queryParameters['or'],
        '(full_name.is.null,full_name.eq.)',
      );
      expect(jsonDecode(update.body), {'full_name': 'Ada Lovelace'});
      expect(pendingNames, isEmpty);
    },
  );

  test('uses a fresh nonce for every attempt', () async {
    await repository.signInWithApple();
    final first = appleNonce;
    await repository.signInWithApple();
    expect(appleNonce, isNot(first));
  });

  test(
    'returning user without name/email keeps their existing profile',
    () async {
      credential = appleCredential(given: null, family: null);
      profileName = 'Chosen name';
      final result = await repository.signInWithApple();
      expect((result as Success<UserProfile>).data.fullName, 'Chosen name');
      expect(
        requests.where((r) => r.method == 'PUT' || r.method == 'PATCH'),
        isEmpty,
      );
    },
  );

  test(
    'does not overwrite an existing profile name on reauthorization',
    () async {
      profileName = 'Chosen name';
      final result = await repository.signInWithApple();
      expect((result as Success<UserProfile>).data.fullName, 'Chosen name');
    },
  );

  test('handles a partial name without storing null fields', () async {
    credential = appleCredential(given: '  Ada  ', family: null);
    await repository.signInWithApple();
    expect(user['user_metadata'], {'full_name': 'Ada', 'given_name': 'Ada'});
  });

  test(
    'cancellation makes no Supabase request and returns the cancellation result',
    () async {
      nativeError = const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'Canceled',
      );
      final result = await repository.signInWithApple();
      expect(
        (result as Failure<UserProfile>).error.message,
        'Sign-in canceled.',
      );
      expect(requests, isEmpty);
      expect(pendingNames, isEmpty);
    },
  );

  test('rejects a missing identity token before contacting Supabase', () async {
    credential = appleCredential(token: null);
    expect(await repository.signInWithApple(), isA<Failure<UserProfile>>());
    expect(requests, isEmpty);
  });

  test(
    'keeps the one-time name when exchange fails and recovers it next login',
    () async {
      failExchange = true;
      expect(await repository.signInWithApple(), isA<Failure<UserProfile>>());
      expect(pendingNames, hasLength(1));
      expect(pendingNames.values.single, isNot(contains('apple-id-token')));
      failExchange = false;
      credential = appleCredential(given: null, family: null);
      final result = await repository.signInWithApple();
      expect((result as Success<UserProfile>).data.fullName, 'Ada Lovelace');
      expect(pendingNames, isEmpty);
    },
  );

  test(
    'name-save failure preserves the session and retries next login',
    () async {
      failNameSave = true;
      expect(await repository.signInWithApple(), isA<Success<UserProfile>>());
      expect(client.auth.currentUser?.id, 'user-id');
      expect(pendingNames, hasLength(1));
      failNameSave = false;
      credential = appleCredential(given: null, family: null);
      final result = await repository.signInWithApple();
      expect((result as Success<UserProfile>).data.fullName, 'Ada Lovelace');
      expect(pendingNames, isEmpty);
    },
  );

  test(
    'unsupported platforms do not launch Apple or contact Supabase',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await repository.signInWithApple(), isA<Failure<UserProfile>>());
      expect(appleNonce, isNull);
      expect(requests, isEmpty);
    },
  );

  test(
    'a failed profile fetch cannot restore another account from cache',
    () async {
      await cache.writeJson('cached_user_profile', {
        'id': 'previous-user',
        'email': 'previous@example.com',
      });
      failProfileFetch = true;
      expect(await repository.signInWithApple(), isA<Failure<UserProfile>>());
      expect(cache.readJson('cached_user_profile'), isNull);
    },
  );

  test('native errors do not expose provider payloads to the UI', () async {
    nativeError = const SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.failed,
      message: 'private-provider-details',
    );
    final result = await repository.signInWithApple();
    expect(
      (result as Failure<UserProfile>).error.message,
      isNot(contains('private-provider-details')),
    );
    expect(requests, isEmpty);
  });
}
