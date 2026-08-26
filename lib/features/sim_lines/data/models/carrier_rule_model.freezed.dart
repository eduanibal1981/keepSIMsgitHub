// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'carrier_rule_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CarrierRule {

 String get id;@JsonKey(name: 'carrier_id') String get carrierId;@JsonKey(name: 'rule_type') String get ruleType;/// Days from the last qualifying activity until the line is terminated and
/// the number can be reissued. The cliff the plan year is built around.
@JsonKey(name: 'inactivity_limit_days') int get inactivityLimitDays;/// Window after the cliff in which the same number can still be recovered.
/// Deliberately not planned against — it is the margin, not the budget.
@JsonKey(name: 'grace_period_days') int get gracePeriodDays;@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double get minimumTopupAmount;/// Line validity a top-up of [minimumTopupAmount] buys.
///
/// Informational. This used to drive the refill cadence, which is how a
/// Saudi line whose carrier terminates at 180 days was sold 13 refills a
/// year: the column held a 30-day *bundle* cycle, not a deactivation
/// window. Use [refillIntervalDays] for anything that schedules or prices.
@JsonKey(name: 'topup_validity_days') int get topupValidityDays;@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double get inappPricing;@JsonKey(name: 'inapp_pricing_currency') String get inappPricingCurrency;@JsonKey(name: 'offer_id') String? get offerId;@JsonKey(name: 'offer_value') int? get offerValue;/// One of `recharge_ok`, `min_denomination`, `usage_required` — see
/// [refillAloneKeepsLineActive].
@JsonKey(name: 'activity_requirement') String get activityRequirement;/// On a `min_denomination` carrier, the smallest top-up that actually buys
/// line validity. A refill below this lands as credit and the number still
/// churns.
@JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble) double? get validityQualifyingTopupAmount;/// Operator-sourced English explanation of the requirement. Shown as the
/// detail line under the localised warning at purchase time.
@JsonKey(name: 'activity_requirement_note') String? get activityRequirementNote;/// When unused credit is swept. Costs the subscriber money, not the number,
/// so it never shortens the cadence.
@JsonKey(name: 'balance_validity_days') int? get balanceValidityDays;@JsonKey(name: 'refill_interval_days_override') int? get refillIntervalDaysOverride;@JsonKey(name: 'rule_source_url') String? get ruleSourceUrl;@JsonKey(name: 'sms_sender_ids') List<String>? get smsSenderIds;@JsonKey(name: 'sms_balance_regex') String? get smsBalanceRegex;@JsonKey(name: 'sms_expiry_regex') String? get smsExpiryRegex;@JsonKey(name: 'sms_keywords') List<String>? get smsKeywords;@JsonKey(name: 'sms_language') String get smsLanguage;
/// Create a copy of CarrierRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CarrierRuleCopyWith<CarrierRule> get copyWith => _$CarrierRuleCopyWithImpl<CarrierRule>(this as CarrierRule, _$identity);

  /// Serializes this CarrierRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CarrierRule&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.inactivityLimitDays, inactivityLimitDays) || other.inactivityLimitDays == inactivityLimitDays)&&(identical(other.gracePeriodDays, gracePeriodDays) || other.gracePeriodDays == gracePeriodDays)&&(identical(other.minimumTopupAmount, minimumTopupAmount) || other.minimumTopupAmount == minimumTopupAmount)&&(identical(other.topupValidityDays, topupValidityDays) || other.topupValidityDays == topupValidityDays)&&(identical(other.inappPricing, inappPricing) || other.inappPricing == inappPricing)&&(identical(other.inappPricingCurrency, inappPricingCurrency) || other.inappPricingCurrency == inappPricingCurrency)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.offerValue, offerValue) || other.offerValue == offerValue)&&(identical(other.activityRequirement, activityRequirement) || other.activityRequirement == activityRequirement)&&(identical(other.validityQualifyingTopupAmount, validityQualifyingTopupAmount) || other.validityQualifyingTopupAmount == validityQualifyingTopupAmount)&&(identical(other.activityRequirementNote, activityRequirementNote) || other.activityRequirementNote == activityRequirementNote)&&(identical(other.balanceValidityDays, balanceValidityDays) || other.balanceValidityDays == balanceValidityDays)&&(identical(other.refillIntervalDaysOverride, refillIntervalDaysOverride) || other.refillIntervalDaysOverride == refillIntervalDaysOverride)&&(identical(other.ruleSourceUrl, ruleSourceUrl) || other.ruleSourceUrl == ruleSourceUrl)&&const DeepCollectionEquality().equals(other.smsSenderIds, smsSenderIds)&&(identical(other.smsBalanceRegex, smsBalanceRegex) || other.smsBalanceRegex == smsBalanceRegex)&&(identical(other.smsExpiryRegex, smsExpiryRegex) || other.smsExpiryRegex == smsExpiryRegex)&&const DeepCollectionEquality().equals(other.smsKeywords, smsKeywords)&&(identical(other.smsLanguage, smsLanguage) || other.smsLanguage == smsLanguage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,carrierId,ruleType,inactivityLimitDays,gracePeriodDays,minimumTopupAmount,topupValidityDays,inappPricing,inappPricingCurrency,offerId,offerValue,activityRequirement,validityQualifyingTopupAmount,activityRequirementNote,balanceValidityDays,refillIntervalDaysOverride,ruleSourceUrl,const DeepCollectionEquality().hash(smsSenderIds),smsBalanceRegex,smsExpiryRegex,const DeepCollectionEquality().hash(smsKeywords),smsLanguage]);

@override
String toString() {
  return 'CarrierRule(id: $id, carrierId: $carrierId, ruleType: $ruleType, inactivityLimitDays: $inactivityLimitDays, gracePeriodDays: $gracePeriodDays, minimumTopupAmount: $minimumTopupAmount, topupValidityDays: $topupValidityDays, inappPricing: $inappPricing, inappPricingCurrency: $inappPricingCurrency, offerId: $offerId, offerValue: $offerValue, activityRequirement: $activityRequirement, validityQualifyingTopupAmount: $validityQualifyingTopupAmount, activityRequirementNote: $activityRequirementNote, balanceValidityDays: $balanceValidityDays, refillIntervalDaysOverride: $refillIntervalDaysOverride, ruleSourceUrl: $ruleSourceUrl, smsSenderIds: $smsSenderIds, smsBalanceRegex: $smsBalanceRegex, smsExpiryRegex: $smsExpiryRegex, smsKeywords: $smsKeywords, smsLanguage: $smsLanguage)';
}


}

/// @nodoc
abstract mixin class $CarrierRuleCopyWith<$Res>  {
  factory $CarrierRuleCopyWith(CarrierRule value, $Res Function(CarrierRule) _then) = _$CarrierRuleCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'rule_type') String ruleType,@JsonKey(name: 'inactivity_limit_days') int inactivityLimitDays,@JsonKey(name: 'grace_period_days') int gracePeriodDays,@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double minimumTopupAmount,@JsonKey(name: 'topup_validity_days') int topupValidityDays,@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double inappPricing,@JsonKey(name: 'inapp_pricing_currency') String inappPricingCurrency,@JsonKey(name: 'offer_id') String? offerId,@JsonKey(name: 'offer_value') int? offerValue,@JsonKey(name: 'activity_requirement') String activityRequirement,@JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble) double? validityQualifyingTopupAmount,@JsonKey(name: 'activity_requirement_note') String? activityRequirementNote,@JsonKey(name: 'balance_validity_days') int? balanceValidityDays,@JsonKey(name: 'refill_interval_days_override') int? refillIntervalDaysOverride,@JsonKey(name: 'rule_source_url') String? ruleSourceUrl,@JsonKey(name: 'sms_sender_ids') List<String>? smsSenderIds,@JsonKey(name: 'sms_balance_regex') String? smsBalanceRegex,@JsonKey(name: 'sms_expiry_regex') String? smsExpiryRegex,@JsonKey(name: 'sms_keywords') List<String>? smsKeywords,@JsonKey(name: 'sms_language') String smsLanguage
});




}
/// @nodoc
class _$CarrierRuleCopyWithImpl<$Res>
    implements $CarrierRuleCopyWith<$Res> {
  _$CarrierRuleCopyWithImpl(this._self, this._then);

  final CarrierRule _self;
  final $Res Function(CarrierRule) _then;

/// Create a copy of CarrierRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? carrierId = null,Object? ruleType = null,Object? inactivityLimitDays = null,Object? gracePeriodDays = null,Object? minimumTopupAmount = null,Object? topupValidityDays = null,Object? inappPricing = null,Object? inappPricingCurrency = null,Object? offerId = freezed,Object? offerValue = freezed,Object? activityRequirement = null,Object? validityQualifyingTopupAmount = freezed,Object? activityRequirementNote = freezed,Object? balanceValidityDays = freezed,Object? refillIntervalDaysOverride = freezed,Object? ruleSourceUrl = freezed,Object? smsSenderIds = freezed,Object? smsBalanceRegex = freezed,Object? smsExpiryRegex = freezed,Object? smsKeywords = freezed,Object? smsLanguage = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,inactivityLimitDays: null == inactivityLimitDays ? _self.inactivityLimitDays : inactivityLimitDays // ignore: cast_nullable_to_non_nullable
as int,gracePeriodDays: null == gracePeriodDays ? _self.gracePeriodDays : gracePeriodDays // ignore: cast_nullable_to_non_nullable
as int,minimumTopupAmount: null == minimumTopupAmount ? _self.minimumTopupAmount : minimumTopupAmount // ignore: cast_nullable_to_non_nullable
as double,topupValidityDays: null == topupValidityDays ? _self.topupValidityDays : topupValidityDays // ignore: cast_nullable_to_non_nullable
as int,inappPricing: null == inappPricing ? _self.inappPricing : inappPricing // ignore: cast_nullable_to_non_nullable
as double,inappPricingCurrency: null == inappPricingCurrency ? _self.inappPricingCurrency : inappPricingCurrency // ignore: cast_nullable_to_non_nullable
as String,offerId: freezed == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String?,offerValue: freezed == offerValue ? _self.offerValue : offerValue // ignore: cast_nullable_to_non_nullable
as int?,activityRequirement: null == activityRequirement ? _self.activityRequirement : activityRequirement // ignore: cast_nullable_to_non_nullable
as String,validityQualifyingTopupAmount: freezed == validityQualifyingTopupAmount ? _self.validityQualifyingTopupAmount : validityQualifyingTopupAmount // ignore: cast_nullable_to_non_nullable
as double?,activityRequirementNote: freezed == activityRequirementNote ? _self.activityRequirementNote : activityRequirementNote // ignore: cast_nullable_to_non_nullable
as String?,balanceValidityDays: freezed == balanceValidityDays ? _self.balanceValidityDays : balanceValidityDays // ignore: cast_nullable_to_non_nullable
as int?,refillIntervalDaysOverride: freezed == refillIntervalDaysOverride ? _self.refillIntervalDaysOverride : refillIntervalDaysOverride // ignore: cast_nullable_to_non_nullable
as int?,ruleSourceUrl: freezed == ruleSourceUrl ? _self.ruleSourceUrl : ruleSourceUrl // ignore: cast_nullable_to_non_nullable
as String?,smsSenderIds: freezed == smsSenderIds ? _self.smsSenderIds : smsSenderIds // ignore: cast_nullable_to_non_nullable
as List<String>?,smsBalanceRegex: freezed == smsBalanceRegex ? _self.smsBalanceRegex : smsBalanceRegex // ignore: cast_nullable_to_non_nullable
as String?,smsExpiryRegex: freezed == smsExpiryRegex ? _self.smsExpiryRegex : smsExpiryRegex // ignore: cast_nullable_to_non_nullable
as String?,smsKeywords: freezed == smsKeywords ? _self.smsKeywords : smsKeywords // ignore: cast_nullable_to_non_nullable
as List<String>?,smsLanguage: null == smsLanguage ? _self.smsLanguage : smsLanguage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CarrierRule].
extension CarrierRulePatterns on CarrierRule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CarrierRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CarrierRule value)  $default,){
final _that = this;
switch (_that) {
case _CarrierRule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CarrierRule value)?  $default,){
final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency, @JsonKey(name: 'offer_id')  String? offerId, @JsonKey(name: 'offer_value')  int? offerValue, @JsonKey(name: 'activity_requirement')  String activityRequirement, @JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble)  double? validityQualifyingTopupAmount, @JsonKey(name: 'activity_requirement_note')  String? activityRequirementNote, @JsonKey(name: 'balance_validity_days')  int? balanceValidityDays, @JsonKey(name: 'refill_interval_days_override')  int? refillIntervalDaysOverride, @JsonKey(name: 'rule_source_url')  String? ruleSourceUrl, @JsonKey(name: 'sms_sender_ids')  List<String>? smsSenderIds, @JsonKey(name: 'sms_balance_regex')  String? smsBalanceRegex, @JsonKey(name: 'sms_expiry_regex')  String? smsExpiryRegex, @JsonKey(name: 'sms_keywords')  List<String>? smsKeywords, @JsonKey(name: 'sms_language')  String smsLanguage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency,_that.offerId,_that.offerValue,_that.activityRequirement,_that.validityQualifyingTopupAmount,_that.activityRequirementNote,_that.balanceValidityDays,_that.refillIntervalDaysOverride,_that.ruleSourceUrl,_that.smsSenderIds,_that.smsBalanceRegex,_that.smsExpiryRegex,_that.smsKeywords,_that.smsLanguage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency, @JsonKey(name: 'offer_id')  String? offerId, @JsonKey(name: 'offer_value')  int? offerValue, @JsonKey(name: 'activity_requirement')  String activityRequirement, @JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble)  double? validityQualifyingTopupAmount, @JsonKey(name: 'activity_requirement_note')  String? activityRequirementNote, @JsonKey(name: 'balance_validity_days')  int? balanceValidityDays, @JsonKey(name: 'refill_interval_days_override')  int? refillIntervalDaysOverride, @JsonKey(name: 'rule_source_url')  String? ruleSourceUrl, @JsonKey(name: 'sms_sender_ids')  List<String>? smsSenderIds, @JsonKey(name: 'sms_balance_regex')  String? smsBalanceRegex, @JsonKey(name: 'sms_expiry_regex')  String? smsExpiryRegex, @JsonKey(name: 'sms_keywords')  List<String>? smsKeywords, @JsonKey(name: 'sms_language')  String smsLanguage)  $default,) {final _that = this;
switch (_that) {
case _CarrierRule():
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency,_that.offerId,_that.offerValue,_that.activityRequirement,_that.validityQualifyingTopupAmount,_that.activityRequirementNote,_that.balanceValidityDays,_that.refillIntervalDaysOverride,_that.ruleSourceUrl,_that.smsSenderIds,_that.smsBalanceRegex,_that.smsExpiryRegex,_that.smsKeywords,_that.smsLanguage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency, @JsonKey(name: 'offer_id')  String? offerId, @JsonKey(name: 'offer_value')  int? offerValue, @JsonKey(name: 'activity_requirement')  String activityRequirement, @JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble)  double? validityQualifyingTopupAmount, @JsonKey(name: 'activity_requirement_note')  String? activityRequirementNote, @JsonKey(name: 'balance_validity_days')  int? balanceValidityDays, @JsonKey(name: 'refill_interval_days_override')  int? refillIntervalDaysOverride, @JsonKey(name: 'rule_source_url')  String? ruleSourceUrl, @JsonKey(name: 'sms_sender_ids')  List<String>? smsSenderIds, @JsonKey(name: 'sms_balance_regex')  String? smsBalanceRegex, @JsonKey(name: 'sms_expiry_regex')  String? smsExpiryRegex, @JsonKey(name: 'sms_keywords')  List<String>? smsKeywords, @JsonKey(name: 'sms_language')  String smsLanguage)?  $default,) {final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency,_that.offerId,_that.offerValue,_that.activityRequirement,_that.validityQualifyingTopupAmount,_that.activityRequirementNote,_that.balanceValidityDays,_that.refillIntervalDaysOverride,_that.ruleSourceUrl,_that.smsSenderIds,_that.smsBalanceRegex,_that.smsExpiryRegex,_that.smsKeywords,_that.smsLanguage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CarrierRule extends CarrierRule {
  const _CarrierRule({required this.id, @JsonKey(name: 'carrier_id') required this.carrierId, @JsonKey(name: 'rule_type') required this.ruleType, @JsonKey(name: 'inactivity_limit_days') required this.inactivityLimitDays, @JsonKey(name: 'grace_period_days') required this.gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) required this.minimumTopupAmount, @JsonKey(name: 'topup_validity_days') required this.topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) required this.inappPricing, @JsonKey(name: 'inapp_pricing_currency') required this.inappPricingCurrency, @JsonKey(name: 'offer_id') this.offerId, @JsonKey(name: 'offer_value') this.offerValue, @JsonKey(name: 'activity_requirement') this.activityRequirement = 'recharge_ok', @JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble) this.validityQualifyingTopupAmount, @JsonKey(name: 'activity_requirement_note') this.activityRequirementNote, @JsonKey(name: 'balance_validity_days') this.balanceValidityDays, @JsonKey(name: 'refill_interval_days_override') this.refillIntervalDaysOverride, @JsonKey(name: 'rule_source_url') this.ruleSourceUrl, @JsonKey(name: 'sms_sender_ids') final  List<String>? smsSenderIds, @JsonKey(name: 'sms_balance_regex') this.smsBalanceRegex, @JsonKey(name: 'sms_expiry_regex') this.smsExpiryRegex, @JsonKey(name: 'sms_keywords') final  List<String>? smsKeywords, @JsonKey(name: 'sms_language') this.smsLanguage = 'auto'}): _smsSenderIds = smsSenderIds,_smsKeywords = smsKeywords,super._();
  factory _CarrierRule.fromJson(Map<String, dynamic> json) => _$CarrierRuleFromJson(json);

@override final  String id;
@override@JsonKey(name: 'carrier_id') final  String carrierId;
@override@JsonKey(name: 'rule_type') final  String ruleType;
/// Days from the last qualifying activity until the line is terminated and
/// the number can be reissued. The cliff the plan year is built around.
@override@JsonKey(name: 'inactivity_limit_days') final  int inactivityLimitDays;
/// Window after the cliff in which the same number can still be recovered.
/// Deliberately not planned against — it is the margin, not the budget.
@override@JsonKey(name: 'grace_period_days') final  int gracePeriodDays;
@override@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) final  double minimumTopupAmount;
/// Line validity a top-up of [minimumTopupAmount] buys.
///
/// Informational. This used to drive the refill cadence, which is how a
/// Saudi line whose carrier terminates at 180 days was sold 13 refills a
/// year: the column held a 30-day *bundle* cycle, not a deactivation
/// window. Use [refillIntervalDays] for anything that schedules or prices.
@override@JsonKey(name: 'topup_validity_days') final  int topupValidityDays;
@override@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) final  double inappPricing;
@override@JsonKey(name: 'inapp_pricing_currency') final  String inappPricingCurrency;
@override@JsonKey(name: 'offer_id') final  String? offerId;
@override@JsonKey(name: 'offer_value') final  int? offerValue;
/// One of `recharge_ok`, `min_denomination`, `usage_required` — see
/// [refillAloneKeepsLineActive].
@override@JsonKey(name: 'activity_requirement') final  String activityRequirement;
/// On a `min_denomination` carrier, the smallest top-up that actually buys
/// line validity. A refill below this lands as credit and the number still
/// churns.
@override@JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble) final  double? validityQualifyingTopupAmount;
/// Operator-sourced English explanation of the requirement. Shown as the
/// detail line under the localised warning at purchase time.
@override@JsonKey(name: 'activity_requirement_note') final  String? activityRequirementNote;
/// When unused credit is swept. Costs the subscriber money, not the number,
/// so it never shortens the cadence.
@override@JsonKey(name: 'balance_validity_days') final  int? balanceValidityDays;
@override@JsonKey(name: 'refill_interval_days_override') final  int? refillIntervalDaysOverride;
@override@JsonKey(name: 'rule_source_url') final  String? ruleSourceUrl;
 final  List<String>? _smsSenderIds;
@override@JsonKey(name: 'sms_sender_ids') List<String>? get smsSenderIds {
  final value = _smsSenderIds;
  if (value == null) return null;
  if (_smsSenderIds is EqualUnmodifiableListView) return _smsSenderIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'sms_balance_regex') final  String? smsBalanceRegex;
@override@JsonKey(name: 'sms_expiry_regex') final  String? smsExpiryRegex;
 final  List<String>? _smsKeywords;
@override@JsonKey(name: 'sms_keywords') List<String>? get smsKeywords {
  final value = _smsKeywords;
  if (value == null) return null;
  if (_smsKeywords is EqualUnmodifiableListView) return _smsKeywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'sms_language') final  String smsLanguage;

/// Create a copy of CarrierRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CarrierRuleCopyWith<_CarrierRule> get copyWith => __$CarrierRuleCopyWithImpl<_CarrierRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CarrierRuleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CarrierRule&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.inactivityLimitDays, inactivityLimitDays) || other.inactivityLimitDays == inactivityLimitDays)&&(identical(other.gracePeriodDays, gracePeriodDays) || other.gracePeriodDays == gracePeriodDays)&&(identical(other.minimumTopupAmount, minimumTopupAmount) || other.minimumTopupAmount == minimumTopupAmount)&&(identical(other.topupValidityDays, topupValidityDays) || other.topupValidityDays == topupValidityDays)&&(identical(other.inappPricing, inappPricing) || other.inappPricing == inappPricing)&&(identical(other.inappPricingCurrency, inappPricingCurrency) || other.inappPricingCurrency == inappPricingCurrency)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.offerValue, offerValue) || other.offerValue == offerValue)&&(identical(other.activityRequirement, activityRequirement) || other.activityRequirement == activityRequirement)&&(identical(other.validityQualifyingTopupAmount, validityQualifyingTopupAmount) || other.validityQualifyingTopupAmount == validityQualifyingTopupAmount)&&(identical(other.activityRequirementNote, activityRequirementNote) || other.activityRequirementNote == activityRequirementNote)&&(identical(other.balanceValidityDays, balanceValidityDays) || other.balanceValidityDays == balanceValidityDays)&&(identical(other.refillIntervalDaysOverride, refillIntervalDaysOverride) || other.refillIntervalDaysOverride == refillIntervalDaysOverride)&&(identical(other.ruleSourceUrl, ruleSourceUrl) || other.ruleSourceUrl == ruleSourceUrl)&&const DeepCollectionEquality().equals(other._smsSenderIds, _smsSenderIds)&&(identical(other.smsBalanceRegex, smsBalanceRegex) || other.smsBalanceRegex == smsBalanceRegex)&&(identical(other.smsExpiryRegex, smsExpiryRegex) || other.smsExpiryRegex == smsExpiryRegex)&&const DeepCollectionEquality().equals(other._smsKeywords, _smsKeywords)&&(identical(other.smsLanguage, smsLanguage) || other.smsLanguage == smsLanguage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,carrierId,ruleType,inactivityLimitDays,gracePeriodDays,minimumTopupAmount,topupValidityDays,inappPricing,inappPricingCurrency,offerId,offerValue,activityRequirement,validityQualifyingTopupAmount,activityRequirementNote,balanceValidityDays,refillIntervalDaysOverride,ruleSourceUrl,const DeepCollectionEquality().hash(_smsSenderIds),smsBalanceRegex,smsExpiryRegex,const DeepCollectionEquality().hash(_smsKeywords),smsLanguage]);

@override
String toString() {
  return 'CarrierRule(id: $id, carrierId: $carrierId, ruleType: $ruleType, inactivityLimitDays: $inactivityLimitDays, gracePeriodDays: $gracePeriodDays, minimumTopupAmount: $minimumTopupAmount, topupValidityDays: $topupValidityDays, inappPricing: $inappPricing, inappPricingCurrency: $inappPricingCurrency, offerId: $offerId, offerValue: $offerValue, activityRequirement: $activityRequirement, validityQualifyingTopupAmount: $validityQualifyingTopupAmount, activityRequirementNote: $activityRequirementNote, balanceValidityDays: $balanceValidityDays, refillIntervalDaysOverride: $refillIntervalDaysOverride, ruleSourceUrl: $ruleSourceUrl, smsSenderIds: $smsSenderIds, smsBalanceRegex: $smsBalanceRegex, smsExpiryRegex: $smsExpiryRegex, smsKeywords: $smsKeywords, smsLanguage: $smsLanguage)';
}


}

/// @nodoc
abstract mixin class _$CarrierRuleCopyWith<$Res> implements $CarrierRuleCopyWith<$Res> {
  factory _$CarrierRuleCopyWith(_CarrierRule value, $Res Function(_CarrierRule) _then) = __$CarrierRuleCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'rule_type') String ruleType,@JsonKey(name: 'inactivity_limit_days') int inactivityLimitDays,@JsonKey(name: 'grace_period_days') int gracePeriodDays,@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double minimumTopupAmount,@JsonKey(name: 'topup_validity_days') int topupValidityDays,@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double inappPricing,@JsonKey(name: 'inapp_pricing_currency') String inappPricingCurrency,@JsonKey(name: 'offer_id') String? offerId,@JsonKey(name: 'offer_value') int? offerValue,@JsonKey(name: 'activity_requirement') String activityRequirement,@JsonKey(name: 'validity_qualifying_topup_amount', fromJson: _parseNullableDouble) double? validityQualifyingTopupAmount,@JsonKey(name: 'activity_requirement_note') String? activityRequirementNote,@JsonKey(name: 'balance_validity_days') int? balanceValidityDays,@JsonKey(name: 'refill_interval_days_override') int? refillIntervalDaysOverride,@JsonKey(name: 'rule_source_url') String? ruleSourceUrl,@JsonKey(name: 'sms_sender_ids') List<String>? smsSenderIds,@JsonKey(name: 'sms_balance_regex') String? smsBalanceRegex,@JsonKey(name: 'sms_expiry_regex') String? smsExpiryRegex,@JsonKey(name: 'sms_keywords') List<String>? smsKeywords,@JsonKey(name: 'sms_language') String smsLanguage
});




}
/// @nodoc
class __$CarrierRuleCopyWithImpl<$Res>
    implements _$CarrierRuleCopyWith<$Res> {
  __$CarrierRuleCopyWithImpl(this._self, this._then);

  final _CarrierRule _self;
  final $Res Function(_CarrierRule) _then;

/// Create a copy of CarrierRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? carrierId = null,Object? ruleType = null,Object? inactivityLimitDays = null,Object? gracePeriodDays = null,Object? minimumTopupAmount = null,Object? topupValidityDays = null,Object? inappPricing = null,Object? inappPricingCurrency = null,Object? offerId = freezed,Object? offerValue = freezed,Object? activityRequirement = null,Object? validityQualifyingTopupAmount = freezed,Object? activityRequirementNote = freezed,Object? balanceValidityDays = freezed,Object? refillIntervalDaysOverride = freezed,Object? ruleSourceUrl = freezed,Object? smsSenderIds = freezed,Object? smsBalanceRegex = freezed,Object? smsExpiryRegex = freezed,Object? smsKeywords = freezed,Object? smsLanguage = null,}) {
  return _then(_CarrierRule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,ruleType: null == ruleType ? _self.ruleType : ruleType // ignore: cast_nullable_to_non_nullable
as String,inactivityLimitDays: null == inactivityLimitDays ? _self.inactivityLimitDays : inactivityLimitDays // ignore: cast_nullable_to_non_nullable
as int,gracePeriodDays: null == gracePeriodDays ? _self.gracePeriodDays : gracePeriodDays // ignore: cast_nullable_to_non_nullable
as int,minimumTopupAmount: null == minimumTopupAmount ? _self.minimumTopupAmount : minimumTopupAmount // ignore: cast_nullable_to_non_nullable
as double,topupValidityDays: null == topupValidityDays ? _self.topupValidityDays : topupValidityDays // ignore: cast_nullable_to_non_nullable
as int,inappPricing: null == inappPricing ? _self.inappPricing : inappPricing // ignore: cast_nullable_to_non_nullable
as double,inappPricingCurrency: null == inappPricingCurrency ? _self.inappPricingCurrency : inappPricingCurrency // ignore: cast_nullable_to_non_nullable
as String,offerId: freezed == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String?,offerValue: freezed == offerValue ? _self.offerValue : offerValue // ignore: cast_nullable_to_non_nullable
as int?,activityRequirement: null == activityRequirement ? _self.activityRequirement : activityRequirement // ignore: cast_nullable_to_non_nullable
as String,validityQualifyingTopupAmount: freezed == validityQualifyingTopupAmount ? _self.validityQualifyingTopupAmount : validityQualifyingTopupAmount // ignore: cast_nullable_to_non_nullable
as double?,activityRequirementNote: freezed == activityRequirementNote ? _self.activityRequirementNote : activityRequirementNote // ignore: cast_nullable_to_non_nullable
as String?,balanceValidityDays: freezed == balanceValidityDays ? _self.balanceValidityDays : balanceValidityDays // ignore: cast_nullable_to_non_nullable
as int?,refillIntervalDaysOverride: freezed == refillIntervalDaysOverride ? _self.refillIntervalDaysOverride : refillIntervalDaysOverride // ignore: cast_nullable_to_non_nullable
as int?,ruleSourceUrl: freezed == ruleSourceUrl ? _self.ruleSourceUrl : ruleSourceUrl // ignore: cast_nullable_to_non_nullable
as String?,smsSenderIds: freezed == smsSenderIds ? _self._smsSenderIds : smsSenderIds // ignore: cast_nullable_to_non_nullable
as List<String>?,smsBalanceRegex: freezed == smsBalanceRegex ? _self.smsBalanceRegex : smsBalanceRegex // ignore: cast_nullable_to_non_nullable
as String?,smsExpiryRegex: freezed == smsExpiryRegex ? _self.smsExpiryRegex : smsExpiryRegex // ignore: cast_nullable_to_non_nullable
as String?,smsKeywords: freezed == smsKeywords ? _self._smsKeywords : smsKeywords // ignore: cast_nullable_to_non_nullable
as List<String>?,smsLanguage: null == smsLanguage ? _self.smsLanguage : smsLanguage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
