/// SIM Shield — Line Activity Log Model
///
/// Maps to `line_activity_log` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'line_activity_log_model.freezed.dart';
part 'line_activity_log_model.g.dart';

@freezed
abstract class LineActivityLog with _$LineActivityLog {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LineActivityLog({
    required String id,
    required String simLineId,
    required String userId,
    required String
    eventType, // 'topup_success', 'topup_failed', 'status_change', 'health_update', 'tier_change', 'paused', 'resumed', 'created', 'grace_period_entered', 'rescue_topup_triggered', 'validity_extended'
    String? description,
    @Default({}) Map<String, dynamic> metadata,
    required DateTime createdAt,
  }) = _LineActivityLog;

  factory LineActivityLog.fromJson(Map<String, dynamic> json) =>
      _$LineActivityLogFromJson(json);
}
