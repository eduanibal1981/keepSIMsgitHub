import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import 'package:keep_sims/features/scheduled_topups/model/schedule_mutation_request.dart';
import 'package:keep_sims/features/scheduled_topups/model/scheduled_topup_model.dart';
import 'package:keep_sims/features/scheduled_topups/repository/scheduled_topup_repository.dart';
import 'package:keep_sims/features/sim_lines/data/repositories/sim_lines_repository_impl.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

class _Network extends ConnectivityService {
  @override
  NetworkStatus build() => NetworkStatus.offline;
}

class _Connection extends Mock implements ConnectivityService {}

class _Queue extends Mock implements SyncQueue {}

const user = '10000000-0000-4000-8000-000000000001';
const sid = '90000000-0000-4000-8000-000000000001';
const line = '20000000-0000-4000-8000-000000000001';
Future<void> session(SupabaseClient client) => client.auth.setInitialSession(
  jsonEncode({
    'access_token': 'synthetic-token',
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': user,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  }),
);
ScheduledTopup schedule({String type = 'refill_custom'}) => ScheduledTopup(
  id: sid,
  simLineId: line,
  userId: 'forged-owner',
  amount: .01,
  frequencyDays: 14,
  nextExecutionAt: DateTime.utc(2027),
  scheduleType: type,
  offerId: 'fixed',
  maxAuthorizedUsd: 3,
  engineVersion: 99,
  pricingTier: 'forged',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'mutation input allows intent and controls but excludes cached authority',
    () {
      final input = {
        ...schedule().toJson(),
        'base_cost_usd': .01,
        'app_fee_usd': 0,
        'schedule_contract_version': 99,
      };
      final body = ScheduleMutationRequest.fromJson(input);
      expect(
        body.keys,
        unorderedEquals([
          'p_sim_line_id',
          'p_schedule_type',
          'p_frequency_days',
          'p_next_execution_at',
          'p_is_active',
          'p_schedule_id',
          'p_offer_id',
          'p_offer_value',
          'p_max_authorized_usd',
        ]),
      );
      expect(body['p_max_authorized_usd'], 3);
      expect(body['p_schedule_id'], sid);
    },
  );
  test('legacy reminder inputs drop offline IDs and paid intent', () {
    final body = ScheduleMutationRequest.fromJson({
      ...schedule().toJson(),
      'id': 'offline_sched_123',
      'schedule_type': null,
    });
    expect(body['p_schedule_type'], 'notify');
    expect(body['p_schedule_id'], isNull);
    expect(body['p_max_authorized_usd'], isNull);
    expect(body['p_offer_id'], isNull);
  });
  for (final update in [false, true]) {
    test(
      '${update ? 'update' : 'create'} sends only validated RPC inputs and accepts server price',
      () async {
        var calls = 0;
        final client = SupabaseClient(
          'https://test.supabase.co',
          'test-key',
          httpClient: MockClient((r) async {
            expect(r.url.path, '/rest/v1/rpc/save_customer_schedule');
            expect(r.method, 'POST');
            final body = jsonDecode(r.body) as Map;
            expect(body.containsKey('amount'), isFalse);
            expect(body.containsKey('user_id'), isFalse);
            expect(body.containsKey('engine_version'), isFalse);
            calls++;
            return http.Response(
              jsonEncode({
                ...schedule().toJson(),
                'amount': 2.1,
                'user_id': user,
                'engine_version': 2,
                'pricing_tier': 'premium',
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        await session(client);
        final connection = _Connection();
        when(() => connection.isOffline).thenReturn(false);
        final repo = ScheduledTopupRepository(
          client,
          LocalCacheService(null),
          connection,
          _Queue(),
        );
        final result = update
            ? await repo.updateSchedule(schedule())
            : await repo.createSchedule(schedule());
        expect(result, isA<Success<ScheduledTopup>>());
        final saved = (result as Success<ScheduledTopup>).data;
        expect(saved.amount, 2.1);
        expect(saved.userId, user);
        expect(saved.engineVersion, 2);
        expect(calls, 1);
      },
    );
  }
  test('toggle and delete use ownership-checked RPCs', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'test-key',
      httpClient: MockClient((r) async {
        paths.add(r.url.path);
        return http.Response(
          r.url.path.endsWith('delete_customer_schedule')
              ? 'null'
              : jsonEncode(schedule(type: 'notify').toJson()),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    await session(client);
    final repo = ScheduledTopupRepository(
      client,
      LocalCacheService(null),
      _Connection(),
      _Queue(),
    );
    expect(
      await repo.toggleSchedule(id: sid, isActive: false),
      isA<Success<ScheduledTopup>>(),
    );
    expect(await repo.deleteSchedule(sid), isA<Success<void>>());
    expect(paths, [
      '/rest/v1/rpc/set_customer_schedule_active',
      '/rest/v1/rpc/delete_customer_schedule',
    ]);
  });
  test(
    'offline reminders stay queued while paid schedule edits are rejected',
    () async {
      final client = SupabaseClient('https://test.supabase.co', 'test-key');
      addTearDown(client.dispose);
      await session(client);
      final connection = _Connection();
      when(() => connection.isOffline).thenReturn(true);
      final queue = _Queue();
      when(() => queue.addToQueue(any(), any())).thenAnswer((_) async {});
      final repo = ScheduledTopupRepository(
        client,
        LocalCacheService(await SharedPreferences.getInstance()),
        connection,
        queue,
      );
      expect(
        await repo.updateSchedule(schedule(type: 'notify')),
        isA<Success<ScheduledTopup>>(),
      );
      expect(
        await repo.updateSchedule(schedule()),
        isA<Failure<ScheduledTopup>>(),
      );
      verify(() => queue.addToQueue('topup_schedule_save', any())).called(1);
    },
  );
  test(
    'offline replay uses reminder RPC and preserves operations for another account',
    () async {
      final calls = <Map>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/rest/v1/rpc/save_customer_schedule');
          calls.add(jsonDecode(r.body) as Map);
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      await session(client);
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWith(_Network.new),
          localCacheServiceProvider.overrideWith(
            (_) => LocalCacheService(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(syncQueueProvider.notifier);
      await queue.addToQueue('topup_schedule_save', {
        ...schedule(type: 'notify').toJson(),
        'schedule_type': null,
        'user_id': user,
      });
      await queue.addToQueue('topup_schedule_save', {
        ...schedule().toJson(),
        'user_id': user,
      });
      await queue.addToQueue('topup_schedule_save', {
        ...schedule(type: 'notify').toJson(),
        'user_id': 'other-account',
      });
      await queue.processQueue(client);
      expect(calls, hasLength(1));
      expect(calls.single['p_schedule_type'], 'notify');
      expect(calls.single['p_max_authorized_usd'], isNull);
      expect(container.read(syncQueueProvider), hasLength(1));
      expect(
        container.read(syncQueueProvider).single.payload['user_id'],
        'other-account',
      );
    },
  );
  test(
    'initialization uses the current API and reports authorization still required',
    () async {
      var needsReview = false;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/rest/v1/rpc/initialize_line_schedules');
          expect(jsonDecode(r.body), {'p_sim_line_id': line});
          return http.Response(
            jsonEncode({'success': true, 'needs_authorization': needsReview}),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final connection = _Connection();
      when(() => connection.isOffline).thenReturn(false);
      final repo = SimLinesRepositoryImpl(
        supabase: client,
        cache: LocalCacheService(null),
        connectivity: connection,
        syncQueue: _Queue(),
      );
      await repo.initializeLineSchedules(line);
      needsReview = true;
      await expectLater(
        repo.initializeLineSchedules(line),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Review the current refill price'),
          ),
        ),
      );
    },
  );
  test(
    'free offline creation retains a stable line identity and deferred initialization',
    () async {
      final client = SupabaseClient('https://test.supabase.co', 'test-key');
      addTearDown(client.dispose);
      await session(client);
      final connection = _Connection();
      when(() => connection.isOffline).thenReturn(true);
      final queue = _Queue();
      when(() => queue.addToQueue(any(), any())).thenAnswer((_) async {});
      final repo = SimLinesRepositoryImpl(
        supabase: client,
        cache: LocalCacheService(null),
        connectivity: connection,
        syncQueue: queue,
      );
      final saved = await repo.addSimLine(
        const SimLine(
          id: '',
          userId: user,
          phoneNumber: '+15550001001',
          planType: 'free',
        ),
      );
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(saved.id), isTrue);
      await repo.initializeLineSchedules(saved.id);
      final insert =
          verify(
                () => queue.addToQueue('sim_line_add', captureAny()),
              ).captured.single
              as Map;
      expect(insert['id'], saved.id);
      verify(
        () => queue.addToQueue('line_schedule_initialize', {
          'sim_line_id': saved.id,
          'user_id': user,
        }),
      ).called(1);
    },
  );

  test(
    'reconnect inserts the stable free line before initializing its schedules',
    () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          final payload = jsonDecode(r.body) as Map;
          if (r.url.path.endsWith('/sim_lines')) {
            expect(payload['id'], line);
            expect(payload.containsKey('is_carrier_verified'), isFalse);
          } else {
            expect(r.url.path, '/rest/v1/rpc/initialize_line_schedules');
            expect(payload, {'p_sim_line_id': line});
          }
          return http.Response(
            '{"success":true}',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      await session(client);
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWith(_Network.new),
          localCacheServiceProvider.overrideWith(
            (_) => LocalCacheService(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(syncQueueProvider.notifier);
      await queue.addToQueue('sim_line_add', {
        'id': line,
        'user_id': user,
        'phone_number': '+15550001001',
        'is_carrier_verified': true,
      });
      await queue.addToQueue('line_schedule_initialize', {
        'sim_line_id': line,
        'user_id': user,
      });
      await queue.processQueue(client);
      expect(paths, [
        '/rest/v1/sim_lines',
        '/rest/v1/rpc/initialize_line_schedules',
      ]);
      expect(container.read(syncQueueProvider), isEmpty);
    },
  );
}
