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
    @Default('USD') String preferredCurrency,
    @Default(false) bool isPowerUser,
    String? referralCode,
    String? referredBy,
    @Default(false) bool onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
