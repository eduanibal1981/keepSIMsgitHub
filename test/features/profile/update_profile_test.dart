import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';

void main() {
  group('UserProfile update payload tests (Session F3-F6)', () {
    test('toClientWritableJson includes only client-writable columns', () {
      final profile = UserProfile(
        id: 'test-user-id-456',
        email: 'someone@example.com',
        fullName: 'Test User',
        avatarUrl: 'https://example.com/a.png',
        phone: '+15551234567',
        homeCountryCode: 'US',
        lastCountry: 'FR',
        preferredCurrency: 'EUR',
        isPowerUser: true,
        subscriptionTier: 'premium',
        referralCode: 'ABC123',
        referredBy: 'XYZ789',
        onboardingCompleted: true,
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );

      final payload = profile.toClientWritableJson();

      // Client-writable fields MUST be present.
      expect(payload['full_name'], equals('Test User'));
      expect(payload['avatar_url'], equals('https://example.com/a.png'));
      expect(payload['phone'], equals('+15551234567'));
      expect(payload['home_country_code'], equals('US'));
      expect(payload['last_country'], equals('FR'));
      expect(payload['preferred_currency'], equals('EUR'));
      expect(payload['onboarding_completed'], isTrue);
      expect(payload.containsKey('updated_at'), isTrue);

      // Server-owned fields MUST NOT be present. `authenticated` had its
      // column-level UPDATE grant on these revoked by migration
      // 20260801090000_f6_table_grant_lockdown, so sending any of them makes
      // PostgREST return 42501 and profile editing breaks entirely.
      expect(payload.containsKey('is_power_user'), isFalse);
      expect(payload.containsKey('subscription_tier'), isFalse);
      expect(payload.containsKey('referral_code'), isFalse);
      expect(payload.containsKey('referred_by'), isFalse);
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('email'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
    });

    test('toJson still carries the server-owned columns (read path unchanged)', () {
      // toJson() is still the correct serialiser for reads and for the local
      // cache — only the UPDATE path had to narrow. If this ever fails, the
      // model changed and the read path needs re-checking too.
      const profile = UserProfile(
        id: 'test-user-id-456',
        email: 'someone@example.com',
        isPowerUser: true,
        subscriptionTier: 'premium',
      );

      final json = profile.toJson();

      expect(json['id'], equals('test-user-id-456'));
      expect(json['email'], equals('someone@example.com'));
      expect(json['is_power_user'], isTrue);
      expect(json['subscription_tier'], equals('premium'));
    });

    test('is_power_user cannot be smuggled through the writable payload', () {
      // The escalation this closes: profiles.is_power_user syncs into
      // auth.users.raw_app_meta_data and thence into the JWT, which the
      // "Allow power users full access on sim_lines" RLS policy honours.
      const attacker = UserProfile(id: 'attacker', isPowerUser: true);

      expect(attacker.toClientWritableJson().keys, isNot(contains('is_power_user')));
      expect(attacker.toClientWritableJson().keys, isNot(contains('is_suspended')));
    });
  });
}
