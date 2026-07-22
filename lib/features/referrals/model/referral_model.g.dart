// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReferredFriend _$ReferredFriendFromJson(Map<String, dynamic> json) =>
    _ReferredFriend(
      id: json['id'] as String,
      referrerId: json['referrer_id'] as String,
      referredUserId: json['referred_user_id'] as String,
      code: json['code'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );

Map<String, dynamic> _$ReferredFriendToJson(_ReferredFriend instance) =>
    <String, dynamic>{
      'id': instance.id,
      'referrer_id': instance.referrerId,
      'referred_user_id': instance.referredUserId,
      'code': instance.code,
      'created_at': instance.createdAt?.toIso8601String(),
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
    };

_ReferralPointEntry _$ReferralPointEntryFromJson(Map<String, dynamic> json) =>
    _ReferralPointEntry(
      id: json['id'] as String,
      referrerId: json['referrer_id'] as String,
      referredUserId: json['referred_user_id'] as String,
      simLineId: json['sim_line_id'] as String?,
      points: (json['points'] as num).toInt(),
      source: json['source'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$ReferralPointEntryToJson(_ReferralPointEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'referrer_id': instance.referrerId,
      'referred_user_id': instance.referredUserId,
      'sim_line_id': instance.simLineId,
      'points': instance.points,
      'source': instance.source,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_ReferralRedemptionEntry _$ReferralRedemptionEntryFromJson(
  Map<String, dynamic> json,
) => _ReferralRedemptionEntry(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  pointsSpent: (json['points_spent'] as num).toInt(),
  walletTxnId: json['wallet_txn_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ReferralRedemptionEntryToJson(
  _ReferralRedemptionEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'points_spent': instance.pointsSpent,
  'wallet_txn_id': instance.walletTxnId,
  'created_at': instance.createdAt?.toIso8601String(),
};

_ReferralSummary _$ReferralSummaryFromJson(Map<String, dynamic> json) =>
    _ReferralSummary(
      pointsBalance: (json['points_balance'] as num).toInt(),
      totalPointsEarned: (json['total_points_earned'] as num).toInt(),
      pointsSpent: (json['points_spent'] as num).toInt(),
      referralCode: json['referral_code'] as String,
      referredFriends: (json['referred_friends'] as List<dynamic>)
          .map((e) => ReferredFriend.fromJson(e as Map<String, dynamic>))
          .toList(),
      pointHistory: (json['point_history'] as List<dynamic>)
          .map((e) => ReferralPointEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      redemptions: (json['redemptions'] as List<dynamic>)
          .map(
            (e) => ReferralRedemptionEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$ReferralSummaryToJson(_ReferralSummary instance) =>
    <String, dynamic>{
      'points_balance': instance.pointsBalance,
      'total_points_earned': instance.totalPointsEarned,
      'points_spent': instance.pointsSpent,
      'referral_code': instance.referralCode,
      'referred_friends': instance.referredFriends,
      'point_history': instance.pointHistory,
      'redemptions': instance.redemptions,
    };
