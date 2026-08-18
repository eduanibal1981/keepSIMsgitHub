// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_voucher_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StoredVoucher _$StoredVoucherFromJson(Map<String, dynamic> json) =>
    _StoredVoucher(
      grantId: json['grant_id'] as String,
      simLineId: json['sim_line_id'] as String,
      pin: json['pin'] as String,
      serial: json['serial'] as String?,
      faceValueUsd: (json['face_value_usd'] as num).toDouble(),
      amountDueUsd: (json['amount_due_usd'] as num).toDouble(),
      instructions: json['instructions'] as String,
      redeemUssdTemplate: json['redeem_ussd_template'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      revealedAt: json['revealed_at'] == null
          ? null
          : DateTime.parse(json['revealed_at'] as String),
      reported: json['reported'] as bool? ?? false,
      storedAt: json['stored_at'] == null
          ? null
          : DateTime.parse(json['stored_at'] as String),
    );

Map<String, dynamic> _$StoredVoucherToJson(_StoredVoucher instance) =>
    <String, dynamic>{
      'grant_id': instance.grantId,
      'sim_line_id': instance.simLineId,
      'pin': instance.pin,
      'serial': instance.serial,
      'face_value_usd': instance.faceValueUsd,
      'amount_due_usd': instance.amountDueUsd,
      'instructions': instance.instructions,
      'redeem_ussd_template': instance.redeemUssdTemplate,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'revealed_at': instance.revealedAt?.toIso8601String(),
      'reported': instance.reported,
      'stored_at': instance.storedAt?.toIso8601String(),
    };

_VoucherGrant _$VoucherGrantFromJson(Map<String, dynamic> json) =>
    _VoucherGrant(
      id: json['id'] as String,
      status: json['status'] as String,
      amountDueUsd: (json['amount_due_usd'] as num?)?.toDouble(),
      faceValueUsd: (json['face_value_usd'] as num?)?.toDouble(),
      revealedAt: json['revealed_at'] == null
          ? null
          : DateTime.parse(json['revealed_at'] as String),
      provisionedAt: json['provisioned_at'] == null
          ? null
          : DateTime.parse(json['provisioned_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$VoucherGrantToJson(_VoucherGrant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'amount_due_usd': instance.amountDueUsd,
      'face_value_usd': instance.faceValueUsd,
      'revealed_at': instance.revealedAt?.toIso8601String(),
      'provisioned_at': instance.provisionedAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
    };

_VoucherRequest _$VoucherRequestFromJson(Map<String, dynamic> json) =>
    _VoucherRequest(
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$VoucherRequestToJson(_VoucherRequest instance) =>
    <String, dynamic>{
      'due_at': instance.dueAt?.toIso8601String(),
      'reason': instance.reason,
    };

_VoucherLineState _$VoucherLineStateFromJson(Map<String, dynamic> json) =>
    _VoucherLineState(
      simLineId: json['sim_line_id'] as String,
      phoneNumber: json['phone_number'] as String,
      nickname: json['nickname'] as String?,
      carrierId: json['carrier_id'] as String?,
      carrierName: json['carrier_name'] as String?,
      entitled: json['entitled'] as bool? ?? false,
      grant: json['grant'] == null
          ? null
          : VoucherGrant.fromJson(json['grant'] as Map<String, dynamic>),
      request: json['request'] == null
          ? null
          : VoucherRequest.fromJson(json['request'] as Map<String, dynamic>),
      stockAvailable: json['stock_available'] as bool? ?? false,
    );

Map<String, dynamic> _$VoucherLineStateToJson(_VoucherLineState instance) =>
    <String, dynamic>{
      'sim_line_id': instance.simLineId,
      'phone_number': instance.phoneNumber,
      'nickname': instance.nickname,
      'carrier_id': instance.carrierId,
      'carrier_name': instance.carrierName,
      'entitled': instance.entitled,
      'grant': instance.grant,
      'request': instance.request,
      'stock_available': instance.stockAvailable,
    };

_OfflineVoucherState _$OfflineVoucherStateFromJson(Map<String, dynamic> json) =>
    _OfflineVoucherState(
      enabled: json['enabled'] as bool? ?? false,
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => VoucherLineState.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <VoucherLineState>[],
      outstandingTotalUsd:
          (json['outstanding_total_usd'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$OfflineVoucherStateToJson(
  _OfflineVoucherState instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'lines': instance.lines,
  'outstanding_total_usd': instance.outstandingTotalUsd,
};
