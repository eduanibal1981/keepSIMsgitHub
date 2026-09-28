import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSession mockSession;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockSession = MockSession();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });

  group('AuthSessionManager — isJwtExpiredError', () {
    test('identifies PostgrestException with JWT expired message', () {
      const ex = PostgrestException(message: 'JWT expired');
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('identifies PostgrestException with token in message', () {
      const ex = PostgrestException(message: 'Invalid auth token provided');
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('identifies PostgrestException with PGRST301 code', () {
      const ex = PostgrestException(message: 'Unauthorized', code: 'PGRST301');
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('identifies PostgrestException with 401 code', () {
      const ex = PostgrestException(message: 'Unauthorized', code: '401');
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('identifies FunctionException with jwt in reasonPhrase', () {
      final ex = FunctionException(
        status: 401,
        reasonPhrase: 'JWT expired or invalid',
      );
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('identifies generic Exception with JWT expired text', () {
      final ex = Exception('JWT expired');
      expect(AuthSessionManager.isJwtExpiredError(ex), isTrue);
    });

    test('returns false for unrelated errors', () {
      const ex = PostgrestException(message: 'Row not found', code: 'PGRST116');
      expect(AuthSessionManager.isJwtExpiredError(ex), isFalse);
      expect(
        AuthSessionManager.isJwtExpiredError(Exception('Network disconnected')),
        isFalse,
      );
    });
  });

  group('AuthSessionManager — isSessionExpiredOrExpiring', () {
    test('returns false when currentSession is null', () {
      when(() => mockAuth.currentSession).thenReturn(null);
      expect(
        AuthSessionManager.isSessionExpiredOrExpiring(mockSupabase),
        isFalse,
      );
    });

    test('returns true when session.isExpired is true', () {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(true);
      when(() => mockSession.expiresAt).thenReturn(null);

      expect(
        AuthSessionManager.isSessionExpiredOrExpiring(mockSupabase),
        isTrue,
      );
    });

    test('returns true when expiresAt is within buffer (e.g. 30 seconds)', () {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(false);
      final in30Seconds =
          DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch ~/
          1000;
      when(() => mockSession.expiresAt).thenReturn(in30Seconds);

      expect(
        AuthSessionManager.isSessionExpiredOrExpiring(
          mockSupabase,
          const Duration(minutes: 2),
        ),
        isTrue,
      );
    });

    test('returns false when expiresAt is far in the future', () {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(false);
      final in1Hour =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      when(() => mockSession.expiresAt).thenReturn(in1Hour);

      expect(
        AuthSessionManager.isSessionExpiredOrExpiring(
          mockSupabase,
          const Duration(minutes: 2),
        ),
        isFalse,
      );
    });
  });

  group('AuthSessionManager — ensureFreshSession', () {
    test('returns false when session is null without refreshing', () async {
      when(() => mockAuth.currentSession).thenReturn(null);

      final result = await AuthSessionManager.ensureFreshSession(mockSupabase);
      expect(result, isFalse);
      verifyNever(() => mockAuth.refreshSession());
    });

    test('returns true when session is fresh and force is false', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(false);
      final in1Hour =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      when(() => mockSession.expiresAt).thenReturn(in1Hour);

      final result = await AuthSessionManager.ensureFreshSession(mockSupabase);
      expect(result, isTrue);
      verifyNever(() => mockAuth.refreshSession());
    });

    test('calls refreshSession and returns true when session is expired', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(true);
      when(() => mockSession.expiresAt).thenReturn(null);

      final newSession = MockSession();
      when(() => mockAuth.refreshSession()).thenAnswer(
        (_) async => AuthResponse(session: newSession, user: mockUser),
      );

      final result = await AuthSessionManager.ensureFreshSession(mockSupabase);
      expect(result, isTrue);
      verify(() => mockAuth.refreshSession()).called(1);
    });

    test('de-duplicates concurrent refresh calls (mutex single-flight)', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(true);
      when(() => mockSession.expiresAt).thenReturn(null);

      final completer = Completer<AuthResponse>();
      when(() => mockAuth.refreshSession()).thenAnswer((_) => completer.future);

      // Launch 3 concurrent refreshes
      final f1 = AuthSessionManager.ensureFreshSession(mockSupabase);
      final f2 = AuthSessionManager.ensureFreshSession(mockSupabase);
      final f3 = AuthSessionManager.ensureFreshSession(mockSupabase);

      // Complete the single in-flight call
      final newSession = MockSession();
      completer.complete(AuthResponse(session: newSession, user: mockUser));

      final results = await Future.wait([f1, f2, f3]);
      expect(results, [true, true, true]);
      // Verify exactly ONE call was made to Supabase Gotrue!
      verify(() => mockAuth.refreshSession()).called(1);
    });

    test('signs out and returns false when refresh token is invalid or revoked', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(true);
      when(() => mockSession.expiresAt).thenReturn(null);

      when(() => mockAuth.refreshSession()).thenThrow(
        const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
      );
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final result = await AuthSessionManager.ensureFreshSession(mockSupabase);
      expect(result, isFalse);
      verify(() => mockAuth.signOut()).called(1);
    });

    test('returns false without signing out on transient network error', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(true);
      when(() => mockSession.expiresAt).thenReturn(null);

      when(() => mockAuth.refreshSession()).thenThrow(
        Exception('SocketException: Failed host lookup'),
      );

      final result = await AuthSessionManager.ensureFreshSession(mockSupabase);
      expect(result, isFalse);
      verifyNever(() => mockAuth.signOut());
    });
  });

  group('AuthSessionManager — withAuthRecovery', () {
    test('returns action result directly on success', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(false);
      final in1Hour =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      when(() => mockSession.expiresAt).thenReturn(in1Hour);

      final result = await AuthSessionManager.withAuthRecovery(
        mockSupabase,
        () async => 'data_from_db',
      );

      expect(result, 'data_from_db');
    });

    test('retries and succeeds when first call throws JWT expired', () async {
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockSession.isExpired).thenReturn(false);
      final in1Hour =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      when(() => mockSession.expiresAt).thenReturn(in1Hour);

      final newSession = MockSession();
      when(() => mockAuth.refreshSession()).thenAnswer(
        (_) async => AuthResponse(session: newSession, user: mockUser),
      );

      int attempts = 0;
      final result = await AuthSessionManager.withAuthRecovery(
        mockSupabase,
        () async {
          attempts++;
          if (attempts == 1) {
            throw const PostgrestException(message: 'JWT expired');
          }
          return 'recovered_data';
        },
      );

      expect(result, 'recovered_data');
      expect(attempts, 2);
      verify(() => mockAuth.refreshSession()).called(1);
    });
  });
}
