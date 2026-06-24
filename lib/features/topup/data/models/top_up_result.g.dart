// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_up_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TopUpResult _$TopUpResultFromJson(Map<String, dynamic> json) => _TopUpResult(
  success: json['success'] as bool,
  transactionId: json['transactionId'] as String,
  errorMessage: json['errorMessage'] as String?,
  amountToppedUp: (json['amountToppedUp'] as num?)?.toDouble(),
  localBenefit: json['localBenefit'] as String?,
);

Map<String, dynamic> _$TopUpResultToJson(_TopUpResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'transactionId': instance.transactionId,
      'errorMessage': instance.errorMessage,
      'amountToppedUp': instance.amountToppedUp,
      'localBenefit': instance.localBenefit,
    };
