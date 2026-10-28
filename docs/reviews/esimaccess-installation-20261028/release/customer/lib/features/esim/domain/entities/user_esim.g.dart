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
  purchasedAt: json['purchasedAt'] == null
      ? null
      : DateTime.parse(json['purchasedAt'] as String),
  firstActivatedAt: json['firstActivatedAt'] == null
      ? null
      : DateTime.parse(json['firstActivatedAt'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  lastSyncedAt: json['lastSyncedAt'] == null
      ? null
      : DateTime.parse(json['lastSyncedAt'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  issuanceVerified: json['issuanceVerified'] as bool? ?? false,
  profileState: json['profileState'] as String? ?? 'unknown',
  installationState: json['installationState'] as String? ?? 'unknown',
  bundleState: json['bundleState'] as String? ?? 'unknown',
  activationTrigger: json['activationTrigger'] as String? ?? 'unknown',
  dataTotalBytes: (json['dataTotalBytes'] as num?)?.toInt(),
  dataUsedBytes: (json['dataUsedBytes'] as num?)?.toInt(),
  dataRemainingBytes: (json['dataRemainingBytes'] as num?)?.toInt(),
  usageObservedAt: json['usageObservedAt'] == null
      ? null
      : DateTime.parse(json['usageObservedAt'] as String),
  lastObservationAt: json['lastObservationAt'] == null
      ? null
      : DateTime.parse(json['lastObservationAt'] as String),
  lastUsageAttemptAt: json['lastUsageAttemptAt'] == null
      ? null
      : DateTime.parse(json['lastUsageAttemptAt'] as String),
  activationDeadlineAt: json['activationDeadlineAt'] == null
      ? null
      : DateTime.parse(json['activationDeadlineAt'] as String),
  usageErrorCode: json['usageErrorCode'] as String?,
  catalogueDetails: json['catalogueDetails'] as Map<String, dynamic>?,
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
  'purchasedAt': instance.purchasedAt?.toIso8601String(),
  'firstActivatedAt': instance.firstActivatedAt?.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'lastSyncedAt': instance.lastSyncedAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'issuanceVerified': instance.issuanceVerified,
  'profileState': instance.profileState,
  'installationState': instance.installationState,
  'bundleState': instance.bundleState,
  'activationTrigger': instance.activationTrigger,
  'dataTotalBytes': instance.dataTotalBytes,
  'dataUsedBytes': instance.dataUsedBytes,
  'dataRemainingBytes': instance.dataRemainingBytes,
  'usageObservedAt': instance.usageObservedAt?.toIso8601String(),
  'lastObservationAt': instance.lastObservationAt?.toIso8601String(),
  'lastUsageAttemptAt': instance.lastUsageAttemptAt?.toIso8601String(),
  'activationDeadlineAt': instance.activationDeadlineAt?.toIso8601String(),
  'usageErrorCode': instance.usageErrorCode,
  'catalogueDetails': instance.catalogueDetails,
};
