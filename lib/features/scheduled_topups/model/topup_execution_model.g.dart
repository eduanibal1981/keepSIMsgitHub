// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topup_execution_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TopupExecution _$TopupExecutionFromJson(Map<String, dynamic> json) =>
    _TopupExecution(
      id: json['id'] as String,
      scheduledTopupId: json['scheduled_topup_id'] as String?,
      simLineId: json['sim_line_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      reloadlyTransactionId: json['reloadly_transaction_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      failureReason: json['failure_reason'] as String?,
      retryOf: json['retry_of'] as String?,
      validityDaysAdded: (json['validity_days_added'] as num?)?.toInt(),
      fulfillmentGateway: json['fulfillment_gateway'] as String?,
      apiProvider: json['api_provider'] as String?,
      executionType: json['execution_type'] as String?,
      executionTime: json['execution_time'] == null
          ? null
          : DateTime.parse(json['execution_time'] as String),
      executedAt: json['executed_at'] == null
          ? null
          : DateTime.parse(json['executed_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      pinCode: json['pin_code'] as String?,
      pinSerial: json['pin_serial'] as String?,
      redeemInstructions: json['redeem_instructions'] as String?,
      targetLocalValue: (json['target_local_value'] as num?)?.toDouble(),
      targetLocalCurrency: json['target_local_currency'] as String?,
      maxAuthorizedUsd: (json['max_authorized_usd'] as num?)?.toDouble(),
      quoteId: json['quote_id'] as String?,
      fundingKind: json['funding_kind'] as String?,
    );

Map<String, dynamic> _$TopupExecutionToJson(_TopupExecution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scheduled_topup_id': instance.scheduledTopupId,
      'sim_line_id': instance.simLineId,
      'user_id': instance.userId,
      'amount': instance.amount,
      'currency': instance.currency,
      'reloadly_transaction_id': instance.reloadlyTransactionId,
      'status': instance.status,
      'failure_reason': instance.failureReason,
      'retry_of': instance.retryOf,
      'validity_days_added': instance.validityDaysAdded,
      'fulfillment_gateway': instance.fulfillmentGateway,
      'api_provider': instance.apiProvider,
      'execution_type': instance.executionType,
      'execution_time': instance.executionTime?.toIso8601String(),
      'executed_at': instance.executedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'pin_code': instance.pinCode,
      'pin_serial': instance.pinSerial,
      'redeem_instructions': instance.redeemInstructions,
      'target_local_value': instance.targetLocalValue,
      'target_local_currency': instance.targetLocalCurrency,
      'max_authorized_usd': instance.maxAuthorizedUsd,
      'quote_id': instance.quoteId,
      'funding_kind': instance.fundingKind,
    };
