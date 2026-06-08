import 'package:freezed_annotation/freezed_annotation.dart';

part 'offline_refill_model.freezed.dart';
part 'offline_refill_model.g.dart';

@freezed
abstract class CarrierUssdSuggestion with _$CarrierUssdSuggestion {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CarrierUssdSuggestion({
    required String id,
    @JsonKey(name: 'carrier_id') required String carrierId,
    @JsonKey(name: 'plan_name') required String planName,
    required double cost,
    @JsonKey(name: 'ussd_code') required String ussdCode,
  }) = _CarrierUssdSuggestion;

  factory CarrierUssdSuggestion.fromJson(Map<String, dynamic> json) =>
      _$CarrierUssdSuggestionFromJson(json);
}

@freezed
abstract class OfflineRefillSettings with _$OfflineRefillSettings {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory OfflineRefillSettings({
    String? id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'is_enabled') @Default(true) bool isEnabled,
    @JsonKey(name: 'default_refill_amount') @Default(10.00) double defaultRefillAmount,
    @JsonKey(name: 'target_sim_line_id') String? targetSimLineId,
    @JsonKey(name: 'custom_phone_number') String? customPhoneNumber,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _OfflineRefillSettings;

  factory OfflineRefillSettings.fromJson(Map<String, dynamic> json) =>
      _$OfflineRefillSettingsFromJson(json);
}
