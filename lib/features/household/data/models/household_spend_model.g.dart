// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_spend_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HouseholdSpendRow _$HouseholdSpendRowFromJson(Map<String, dynamic> json) =>
    _HouseholdSpendRow(
      memberRowId: json['member_row_id'] as String,
      memberId: json['member_id'] as String?,
      memberEmail: json['member_email'] as String,
      memberName: json['member_name'] as String?,
      role: json['role'] as String,
      inviteStatus: json['invite_status'] as String,
      monthlyCapUsd: (json['monthly_cap_usd'] as num?)?.toDouble() ?? 0.0,
      perTxnCapUsd: (json['per_txn_cap_usd'] as num?)?.toDouble(),
      committedUsd: (json['committed_usd'] as num?)?.toDouble() ?? 0.0,
      inFlightUsd: (json['in_flight_usd'] as num?)?.toDouble() ?? 0.0,
      spentMtdUsd: (json['spent_mtd_usd'] as num?)?.toDouble() ?? 0.0,
      remainingUsd: (json['remaining_usd'] as num?)?.toDouble() ?? 0.0,
      lastSpendAt: json['last_spend_at'] == null
          ? null
          : DateTime.parse(json['last_spend_at'] as String),
    );

Map<String, dynamic> _$HouseholdSpendRowToJson(_HouseholdSpendRow instance) =>
    <String, dynamic>{
      'member_row_id': instance.memberRowId,
      'member_id': instance.memberId,
      'member_email': instance.memberEmail,
      'member_name': instance.memberName,
      'role': instance.role,
      'invite_status': instance.inviteStatus,
      'monthly_cap_usd': instance.monthlyCapUsd,
      'per_txn_cap_usd': instance.perTxnCapUsd,
      'committed_usd': instance.committedUsd,
      'in_flight_usd': instance.inFlightUsd,
      'spent_mtd_usd': instance.spentMtdUsd,
      'remaining_usd': instance.remainingUsd,
      'last_spend_at': instance.lastSpendAt?.toIso8601String(),
    };

_HouseholdAllowance _$HouseholdAllowanceFromJson(Map<String, dynamic> json) =>
    _HouseholdAllowance(
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      role: json['role'] as String,
      monthlyCapUsd: (json['monthly_cap_usd'] as num?)?.toDouble() ?? 0.0,
      perTxnCapUsd: (json['per_txn_cap_usd'] as num?)?.toDouble(),
      spentMtdUsd: (json['spent_mtd_usd'] as num?)?.toDouble() ?? 0.0,
      remainingUsd: (json['remaining_usd'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$HouseholdAllowanceToJson(_HouseholdAllowance instance) =>
    <String, dynamic>{
      'owner_id': instance.ownerId,
      'owner_name': instance.ownerName,
      'owner_email': instance.ownerEmail,
      'role': instance.role,
      'monthly_cap_usd': instance.monthlyCapUsd,
      'per_txn_cap_usd': instance.perTxnCapUsd,
      'spent_mtd_usd': instance.spentMtdUsd,
      'remaining_usd': instance.remainingUsd,
    };
