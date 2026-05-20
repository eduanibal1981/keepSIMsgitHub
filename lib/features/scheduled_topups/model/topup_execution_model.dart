/// SIM Shield — Top-Up Execution Model
///
/// Maps to `topup_executions` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'topup_execution_model.freezed.dart';
part 'topup_execution_model.g.dart';

@freezed
abstract class TopupExecution with _$TopupExecution {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory TopupExecution({
    required String id,
    String? scheduledTopupId,
    required String simLineId,
    required String userId,
    required double amount,
    @Default('USD') String currency,
    String? reloadlyTransactionId,
    @Default('pending') String status, // 'pending', 'processing', 'success', 'failed', 'refunded'
    String? failureReason,
    String? retryOf,
    int? validityDaysAdded,
    required DateTime executedAt,
    DateTime? completedAt,
    DateTime? createdAt,
  }) = _TopupExecution;

  factory TopupExecution.fromJson(Map<String, dynamic> json) =>
      _$TopupExecutionFromJson(json);
}
