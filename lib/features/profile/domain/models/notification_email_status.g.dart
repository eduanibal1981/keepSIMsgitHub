// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_email_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationEmailStatus _$NotificationEmailStatusFromJson(
  Map<String, dynamic> json,
) => _NotificationEmailStatus(
  accountEmail: json['account_email'] as String?,
  accountEmailVerified: json['account_email_verified'] as bool? ?? false,
  currentEmail: json['current_email'] as String?,
  alternateEmail: json['alternate_email'] as String?,
  pendingEmail: json['pending_email'] as String?,
);

Map<String, dynamic> _$NotificationEmailStatusToJson(
  _NotificationEmailStatus instance,
) => <String, dynamic>{
  'account_email': instance.accountEmail,
  'account_email_verified': instance.accountEmailVerified,
  'current_email': instance.currentEmail,
  'alternate_email': instance.alternateEmail,
  'pending_email': instance.pendingEmail,
};
