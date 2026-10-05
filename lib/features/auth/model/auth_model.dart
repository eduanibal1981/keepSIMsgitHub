/// SIM Shield — Auth Model (User Profile)
///
/// Maps to the `profiles` table in Supabase.
/// Uses Freezed v3 with snake_case JSON serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_model.freezed.dart';
part 'auth_model.g.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UserProfile({
    @Default('') String id,
    @Default('') String email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? homeCountryCode,
    @JsonKey(name: 'last_country') String? lastCountry,
    @Default('USD') String preferredCurrency,
    @Default(false) bool isPowerUser,
    @JsonKey(name: 'subscription_tier')
    @Default('standard')
    String subscriptionTier,
    String? referralCode,
    String? referredBy,
    @Default(false) bool onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

/// The subset of `profiles` a signed-in client is allowed to write.
///
/// `toJson()` serialises the whole row, including columns the server owns:
/// `is_power_user` (privilege), `is_suspended` (moderation), `subscription_tier`
/// (entitlement), `referral_code` / `referred_by` (set only by
/// `apply_referral()`), plus the immutable `id`, `email` and `created_at`.
/// Those columns were revoked from `authenticated` by migration
/// `20260801090000_f6_table_grant_lockdown`, so sending the full model now
/// fails with 42501 — the same breakage the D5d column lockdown caused for SIM
/// line editing. Send this instead on UPDATE.
extension UserProfileWritablePayload on UserProfile {
  /// Editing identity details must not overwrite a concurrently changed
  /// currency, phone, or onboarding preference.
  Map<String, dynamic> toDetailsWritableJson() => {
    'full_name': fullName,
    'home_country_code': homeCountryCode,
    'updated_at': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> toClientWritableJson() {
    return {
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'home_country_code': homeCountryCode,
      'last_country': lastCountry,
      'preferred_currency': preferredCurrency,
      'onboarding_completed': onboardingCompleted,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
