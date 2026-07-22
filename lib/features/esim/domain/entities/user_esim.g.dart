// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_esim.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserEsim _$UserEsimFromJson(Map<String, dynamic> json) => _UserEsim(
  id: json['id'] as String,
  userId: json['userId'] as String,
  esimOrderId: json['esimOrderId'] as String,
  iccid: json['iccid'] as String,
  lpaActivationCode: json['lpaActivationCode'] as String,
  qrCodeUrl: json['qrCodeUrl'] as String,
  bundleName: json['bundleName'] as String,
  provider: json['provider'] as String,
  status: json['status'] as String,
  dataRemainingMb: (json['dataRemainingMb'] as num).toInt(),
  dataTotalMb: (json['dataTotalMb'] as num).toInt(),
  purchasedAt: DateTime.parse(json['purchasedAt'] as String),
  firstActivatedAt: json['firstActivatedAt'] == null
      ? null
      : DateTime.parse(json['firstActivatedAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserEsimToJson(_UserEsim instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'esimOrderId': instance.esimOrderId,
  'iccid': instance.iccid,
  'lpaActivationCode': instance.lpaActivationCode,
  'qrCodeUrl': instance.qrCodeUrl,
  'bundleName': instance.bundleName,
  'provider': instance.provider,
  'status': instance.status,
  'dataRemainingMb': instance.dataRemainingMb,
  'dataTotalMb': instance.dataTotalMb,
  'purchasedAt': instance.purchasedAt.toIso8601String(),
  'firstActivatedAt': instance.firstActivatedAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
