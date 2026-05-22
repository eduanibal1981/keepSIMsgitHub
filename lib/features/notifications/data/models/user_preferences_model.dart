import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_preferences_model.freezed.dart';
part 'user_preferences_model.g.dart';

@freezed
abstract class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'quiet_hours_start') String? quietHoursStart,
    @JsonKey(name: 'quiet_hours_end') String? quietHoursEnd,
    @JsonKey(name: 'weekly_digest_enabled')
    @Default(true)
    bool weeklyDigestEnabled,
    @JsonKey(name: 'travel_mode_enabled')
    @Default(false)
    bool travelModeEnabled,
    @JsonKey(name: 'biometric_enabled') @Default(false) bool biometricEnabled,
    @JsonKey(name: 'transaction_pin_hash') String? transactionPinHash,
    @Default('system') String theme,
    @Default('en') String language,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}
