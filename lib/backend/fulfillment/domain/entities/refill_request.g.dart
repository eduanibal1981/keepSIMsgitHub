// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refill_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefillRequest _$RefillRequestFromJson(Map<String, dynamic> json) =>
    _RefillRequest(
      id: json['id'] as String,
      corporateLineId: json['corporate_line_id'] as String,
      source: json['source'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      fulfillmentMethodUsed: json['fulfillment_method_used'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$RefillRequestToJson(_RefillRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'corporate_line_id': instance.corporateLineId,
      'source': instance.source,
      'amount': instance.amount,
      'status': instance.status,
      'fulfillment_method_used': instance.fulfillmentMethodUsed,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
