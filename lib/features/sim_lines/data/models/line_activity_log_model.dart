/// SIM Shield — Line Activity Log Model
///
/// Maps to `line_activity_log` table in Supabase.
/// Uses Freezed v3 with snake_case serialization.
library;

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

part 'line_activity_log_model.freezed.dart';
part 'line_activity_log_model.g.dart';

@freezed
abstract class LineActivityLog with _$LineActivityLog {
  const LineActivityLog._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LineActivityLog({
    required String id,
    required String simLineId,
    required String userId,
    required String eventType,
    String? description,
    @Default({}) Map<String, dynamic> metadata,
    required DateTime createdAt,
  }) = _LineActivityLog;

  factory LineActivityLog.fromJson(Map<String, dynamic> json) =>
      _$LineActivityLogFromJson(json);

  String getLocalizedDescription(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (loc == null) return description ?? '';

    final rawAmount = metadata['amount'] ?? metadata['base_cost_usd'];
    final amountStr = rawAmount != null
        ? (double.tryParse(rawAmount.toString())?.toStringAsFixed(2) ?? rawAmount.toString())
        : '';
    final providerStr =
        (metadata['provider'] ?? 'zendit').toString().toUpperCase();
    final reasonStr =
        metadata['failure_reason'] ?? metadata['refund_reason'] ?? 'Failed';

    switch (eventType) {
      case 'topup_requested':
        return loc.activityTopupRequested(amountStr);
      case 'topup_success':
        return loc.activityTopupSuccess(amountStr, providerStr);
      case 'topup_failed':
        return loc.activityTopupFailed(amountStr, reasonStr.toString());
      case 'topup_refunded':
        return loc.activityTopupRefunded(amountStr);
      case 'topup_cancelled':
        return loc.activityTopupCancelled(amountStr);
      case 'topup_retry_queued':
        return loc.activityTopupRetryQueued(amountStr);
      case 'created':
        return loc.activityLineCreated;
      case 'health_update':
        return loc.activityHealthUpdate;
      case 'reminder_sent':
        return loc.activityReminderSent;
      default:
        if (description != null && description!.isNotEmpty) {
          return description!;
        }
        return eventType;
    }
  }
}

