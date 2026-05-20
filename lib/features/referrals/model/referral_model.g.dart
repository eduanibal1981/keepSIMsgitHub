// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Referral _$ReferralFromJson(Map<String, dynamic> json) => _Referral(
  id: json['id'] as String,
  referrerId: json['referrer_id'] as String,
  referredId: json['referred_id'] as String,
  referralCode: json['referral_code'] as String,
  rewardAmount: (json['reward_amount'] as num).toDouble(),
  referrerCredited: json['referrer_credited'] as bool,
  referredCredited: json['referred_credited'] as bool,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  referredProfile: json['referred_profile'] == null
      ? null
      : UserProfile.fromJson(json['referred_profile'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReferralToJson(_Referral instance) => <String, dynamic>{
  'id': instance.id,
  'referrer_id': instance.referrerId,
  'referred_id': instance.referredId,
  'referral_code': instance.referralCode,
  'reward_amount': instance.rewardAmount,
  'referrer_credited': instance.referrerCredited,
  'referred_credited': instance.referredCredited,
  'created_at': instance.createdAt?.toIso8601String(),
  'referred_profile': instance.referredProfile,
};
