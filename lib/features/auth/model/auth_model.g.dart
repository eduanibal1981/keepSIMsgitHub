// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String? ?? '',
  email: json['email'] as String? ?? '',
  fullName: json['full_name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  phone: json['phone'] as String?,
  homeCountryCode: json['home_country_code'] as String?,
  lastCountry: json['last_country'] as String?,
  preferredCurrency: json['preferred_currency'] as String? ?? 'USD',
  isPowerUser: json['is_power_user'] as bool? ?? false,
  subscriptionTier: json['subscription_tier'] as String? ?? 'standard',
  referralCode: json['referral_code'] as String?,
  referredBy: json['referred_by'] as String?,
  onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
      'avatar_url': instance.avatarUrl,
      'phone': instance.phone,
      'home_country_code': instance.homeCountryCode,
      'last_country': instance.lastCountry,
      'preferred_currency': instance.preferredCurrency,
      'is_power_user': instance.isPowerUser,
      'subscription_tier': instance.subscriptionTier,
      'referral_code': instance.referralCode,
      'referred_by': instance.referredBy,
      'onboarding_completed': instance.onboardingCompleted,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
