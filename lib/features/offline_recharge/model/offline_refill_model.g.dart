// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_refill_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CarrierUssdSuggestion _$CarrierUssdSuggestionFromJson(
  Map<String, dynamic> json,
) => _CarrierUssdSuggestion(
  id: json['id'] as String,
  carrierId: json['carrier_id'] as String,
  planName: json['plan_name'] as String,
  cost: (json['cost'] as num).toDouble(),
  ussdCode: json['ussd_code'] as String,
);

Map<String, dynamic> _$CarrierUssdSuggestionToJson(
  _CarrierUssdSuggestion instance,
) => <String, dynamic>{
  'id': instance.id,
  'carrier_id': instance.carrierId,
  'plan_name': instance.planName,
  'cost': instance.cost,
  'ussd_code': instance.ussdCode,
};

_OfflineRefillSettings _$OfflineRefillSettingsFromJson(
  Map<String, dynamic> json,
) => _OfflineRefillSettings(
  id: json['id'] as String?,
  userId: json['user_id'] as String,
  isEnabled: json['is_enabled'] as bool? ?? true,
  defaultRefillAmount:
      (json['default_refill_amount'] as num?)?.toDouble() ?? 10.00,
  targetSimLineId: json['target_sim_line_id'] as String?,
  customPhoneNumber: json['custom_phone_number'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$OfflineRefillSettingsToJson(
  _OfflineRefillSettings instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'is_enabled': instance.isEnabled,
  'default_refill_amount': instance.defaultRefillAmount,
  'target_sim_line_id': instance.targetSimLineId,
  'custom_phone_number': instance.customPhoneNumber,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_PendingOfflineRefill _$PendingOfflineRefillFromJson(
  Map<String, dynamic> json,
) => _PendingOfflineRefill(
  id: json['id'] as String,
  channel: json['channel'] as String,
  simLineId: json['sim_line_id'] as String,
  phoneNumber: json['phone_number'] as String,
  amount: (json['amount'] as num).toDouble(),
  status: json['status'] as String? ?? PendingRefillStatus.sent,
  launchedAt: DateTime.parse(json['launched_at'] as String),
  executionId: json['execution_id'] as String?,
  failureReason: json['failure_reason'] as String?,
);

Map<String, dynamic> _$PendingOfflineRefillToJson(
  _PendingOfflineRefill instance,
) => <String, dynamic>{
  'id': instance.id,
  'channel': instance.channel,
  'sim_line_id': instance.simLineId,
  'phone_number': instance.phoneNumber,
  'amount': instance.amount,
  'status': instance.status,
  'launched_at': instance.launchedAt.toIso8601String(),
  'execution_id': instance.executionId,
  'failure_reason': instance.failureReason,
};
