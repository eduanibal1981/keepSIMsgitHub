import 'package:freezed_annotation/freezed_annotation.dart';

part 'sim_liveness_result.freezed.dart';
part 'sim_liveness_result.g.dart';

@freezed
abstract class SimLivenessResult with _$SimLivenessResult {
  const factory SimLivenessResult({
    @JsonKey(name: 'is_active') @Default(false) bool isActive,
    @JsonKey(name: 'carrier_status')
    @Default('pending')
    String carrierStatus, // 'active', 'inactive', 'unsupported', 'pending'
    @JsonKey(name: 'detected_operator_name') String? detectedOperatorName,
    @JsonKey(name: 'country_code') String? countryCode,
    @JsonKey(name: 'reason') String? reason,
    @JsonKey(name: 'message') @Default('') String message,
    @JsonKey(name: 'provider') @Default('none') String provider,
    @JsonKey(name: 'verified_at') DateTime? verifiedAt,
  }) = _SimLivenessResult;

  factory SimLivenessResult.fromJson(Map<String, dynamic> json) =>
      _$SimLivenessResultFromJson(json);
}
