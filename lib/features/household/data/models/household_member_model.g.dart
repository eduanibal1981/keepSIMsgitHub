// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_member_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HouseholdMember _$HouseholdMemberFromJson(Map<String, dynamic> json) =>
    _HouseholdMember(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      memberEmail: json['member_email'] as String,
      memberId: json['member_id'] as String?,
      role: json['role'] as String,
      inviteStatus: json['invite_status'] as String,
      invitedAt: DateTime.parse(json['invited_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerName: json['owner_name'] as String?,
      memberName: json['member_name'] as String?,
      memberAvatar: json['member_avatar'] as String?,
    );

Map<String, dynamic> _$HouseholdMemberToJson(_HouseholdMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'member_email': instance.memberEmail,
      'member_id': instance.memberId,
      'role': instance.role,
      'invite_status': instance.inviteStatus,
      'invited_at': instance.invitedAt.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'owner_name': instance.ownerName,
      'member_name': instance.memberName,
      'member_avatar': instance.memberAvatar,
    };
