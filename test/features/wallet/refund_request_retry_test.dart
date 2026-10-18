import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/wallet/repository/wallet_repository.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

class _Functions extends Mock implements FunctionsClient {}

class _Connectivity extends Mock implements ConnectivityService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Auth auth;
  late _Functions functions;
  late _Connectivity connectivity;
  late LocalCacheService cache;
  late List<Map<String, dynamic>> requests;
  var failing = true;
  var validReceipt = true;
  const owner = '10000000-0000-4000-8000-000000000001';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCacheService(await SharedPreferences.getInstance());
    client = _Client();
    auth = _Auth();
    functions = _Functions();
    connectivity = _Connectivity();
    requests = [];
    failing = true;
    validReceipt = true;
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(functions);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.currentUser).thenReturn(
      const User(
        id: owner,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-17T00:00:00Z',
      ),
    );
    when(() => connectivity.isOffline).thenReturn(false);
    when(
      () => functions.invoke('wallet_transact', body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      requests.add(
        Map<String, dynamic>.from(invocation.namedArguments[#body] as Map),
      );
      if (failing) {
        throw const FunctionException(
          status: 500,
          details: 'Lost request response',
        );
      }
      return FunctionResponse(
        status: 200,
        data: {
          'success': true,
          'result': validReceipt
              ? {
                  'refund_request_id': '20000000-0000-4000-8000-000000000001',
                  'already_requested': true,
                }
              : <String, dynamic>{},
        },
      );
    });
  });
  WalletRepository repository([LocalCacheService? localCache]) =>
      WalletRepository(client, localCache ?? cache, connectivity);

  test(
    'lost responses reuse the same persisted key after repository recreation',
    () async {
      expect(await repository().requestRefund(amount: 5), isA<Failure>());
      final original = requests.single['refund_request_key'];
      expect(original, matches(RegExp(r'^refund_[a-f0-9]{32}$')));
      failing = false;
      expect(await repository().requestRefund(amount: 5), isA<Success>());
      expect(requests.last['refund_request_key'], original);
      // An acknowledged request finishes this intent. A deliberate later request
      // gets a new key; server retries of the old key remain permanently safe.
      expect(await repository().requestRefund(amount: 5), isA<Success>());
      expect(requests.last['refund_request_key'], isNot(original));
    },
  );

  test(
    'concurrent retries and server refusal retain the same operation identity',
    () async {
      final repo = repository();
      await Future.wait([
        repo.requestRefund(amount: 5),
        repo.requestRefund(amount: 5),
      ]);
      expect(
        requests.map((request) => request['refund_request_key']).toSet(),
        hasLength(1),
      );
      await repo.requestRefund(amount: 5);
      expect(
        requests.map((request) => request['refund_request_key']).toSet(),
        hasLength(1),
      );
    },
  );

  test(
    'an account switch cannot reuse another accounts uncertain refund key',
    () async {
      await repository().requestRefund(amount: 5);
      final original = requests.single['refund_request_key'];
      when(() => auth.currentUser).thenReturn(
        const User(
          id: '10000000-0000-4000-8000-000000000002',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-10-17T00:00:00Z',
        ),
      );
      await repository().requestRefund(amount: 5);
      expect(requests.last['refund_request_key'], isNot(original));
    },
  );

  test(
    'failure to persist retry state prevents any withdrawal request',
    () async {
      expect(
        await repository(LocalCacheService(null)).requestRefund(amount: 5),
        isA<Failure>(),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'a malformed success response retains the uncertain operation key',
    () async {
      failing = false;
      validReceipt = false;
      expect(await repository().requestRefund(amount: 5), isA<Failure>());
      final original = requests.single['refund_request_key'];
      validReceipt = true;
      expect(await repository().requestRefund(amount: 5), isA<Success>());
      expect(requests.last['refund_request_key'], original);
    },
  );

  test(
    'invalid amounts are rejected before cache or network mutation',
    () async {
      for (final amount in [
        double.nan,
        double.infinity,
        1e308,
        -1.0,
        0.0,
        1.001,
      ]) {
        expect(
          await repository().requestRefund(amount: amount),
          isA<Failure>(),
        );
      }
      expect(requests, isEmpty);
    },
  );
}
