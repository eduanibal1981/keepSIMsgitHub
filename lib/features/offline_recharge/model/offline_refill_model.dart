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
    @JsonKey(name: 'default_refill_amount')
    @Default(10.00)
    double defaultRefillAmount,
    @JsonKey(name: 'target_sim_line_id') String? targetSimLineId,
    @JsonKey(name: 'custom_phone_number') String? customPhoneNumber,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _OfflineRefillSettings;

  factory OfflineRefillSettings.fromJson(Map<String, dynamic> json) =>
      _$OfflineRefillSettingsFromJson(json);
}

/// The three offline channels, in fallback order. String values match
/// `topup_executions.refill_channel` and the webhooks' `p_channel` (C4).
abstract final class OfflineChannel {
  static const whatsapp = 'whatsapp';
  static const sms = 'sms';
  static const missedCall = 'missed_call';
}

/// Local lifecycle of a queued offline refill. `sent`/`processing` are
/// non-terminal (still reconciling); `confirmed`/`failed`/`timedOut` are final.
abstract final class PendingRefillStatus {
  static const sent = 'sent';
  static const processing = 'processing';
  static const confirmed = 'confirmed';
  static const failed = 'failed';
  static const timedOut = 'timed_out';

  static bool isTerminal(String s) =>
      s == confirmed || s == failed || s == timedOut;
}

/// A locally-queued offline refill. Persisted via LocalCacheService BEFORE the
/// external app (WhatsApp / SMS / dialer) is launched, so a request survives the
/// app being killed mid-flow; reconciled against `topup_executions` once the
/// device is back online (C4). This is a device-local record, never written to
/// Supabase — the real refill is created server-side by the channel's webhook.
@freezed
abstract class PendingOfflineRefill with _$PendingOfflineRefill {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingOfflineRefill({
    required String id,
    required String channel,
    @JsonKey(name: 'sim_line_id') required String simLineId,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    required double amount,
    @Default(PendingRefillStatus.sent) String status,
    @JsonKey(name: 'launched_at') required DateTime launchedAt,
    @JsonKey(name: 'execution_id') String? executionId,
    @JsonKey(name: 'failure_reason') String? failureReason,
  }) = _PendingOfflineRefill;

  factory PendingOfflineRefill.fromJson(Map<String, dynamic> json) =>
      _$PendingOfflineRefillFromJson(json);
}
