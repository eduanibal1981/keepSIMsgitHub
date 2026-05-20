/// SIM Shield — Scheduled Top-Up Model
///
/// Maps to `scheduled_topups` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_topup_model.freezed.dart';
part 'scheduled_topup_model.g.dart';

@freezed
abstract class ScheduledTopup with _$ScheduledTopup {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ScheduledTopup({
    required String id,
    required String simLineId,
    required String userId,
    required double amount,
    @Default('USD') String currency,
    required int frequencyDays,
    required DateTime nextExecutionAt,
    DateTime? lastExecutionAt,
    @Default(true) bool isActive,
    @Default(0) int retryCount,
    @Default(4) int maxRetries,
    @Default('active') String status, // 'active', 'paused', 'failed_permanently', 'completed'
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ScheduledTopup;

  factory ScheduledTopup.fromJson(Map<String, dynamic> json) =>
      _$ScheduledTopupFromJson(json);
}
