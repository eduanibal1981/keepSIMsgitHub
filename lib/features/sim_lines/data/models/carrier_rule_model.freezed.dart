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

 String get id;@JsonKey(name: 'carrier_id') String get carrierId;@JsonKey(name: 'rule_type') String get ruleType;@JsonKey(name: 'inactivity_limit_days') int get inactivityLimitDays;@JsonKey(name: 'grace_period_days') int get gracePeriodDays;@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double get minimumTopupAmount;@JsonKey(name: 'topup_validity_days') int get topupValidityDays;@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double get inappPricing;@JsonKey(name: 'inapp_pricing_currency') String get inappPricingCurrency;
/// Create a copy of CarrierRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CarrierRuleCopyWith<CarrierRule> get copyWith => _$CarrierRuleCopyWithImpl<CarrierRule>(this as CarrierRule, _$identity);

  /// Serializes this CarrierRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CarrierRule&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.inactivityLimitDays, inactivityLimitDays) || other.inactivityLimitDays == inactivityLimitDays)&&(identical(other.gracePeriodDays, gracePeriodDays) || other.gracePeriodDays == gracePeriodDays)&&(identical(other.minimumTopupAmount, minimumTopupAmount) || other.minimumTopupAmount == minimumTopupAmount)&&(identical(other.topupValidityDays, topupValidityDays) || other.topupValidityDays == topupValidityDays)&&(identical(other.inappPricing, inappPricing) || other.inappPricing == inappPricing)&&(identical(other.inappPricingCurrency, inappPricingCurrency) || other.inappPricingCurrency == inappPricingCurrency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,carrierId,ruleType,inactivityLimitDays,gracePeriodDays,minimumTopupAmount,topupValidityDays,inappPricing,inappPricingCurrency);

@override
String toString() {
  return 'CarrierRule(id: $id, carrierId: $carrierId, ruleType: $ruleType, inactivityLimitDays: $inactivityLimitDays, gracePeriodDays: $gracePeriodDays, minimumTopupAmount: $minimumTopupAmount, topupValidityDays: $topupValidityDays, inappPricing: $inappPricing, inappPricingCurrency: $inappPricingCurrency)';
}


}

/// @nodoc
abstract mixin class $CarrierRuleCopyWith<$Res>  {
  factory $CarrierRuleCopyWith(CarrierRule value, $Res Function(CarrierRule) _then) = _$CarrierRuleCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'rule_type') String ruleType,@JsonKey(name: 'inactivity_limit_days') int inactivityLimitDays,@JsonKey(name: 'grace_period_days') int gracePeriodDays,@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double minimumTopupAmount,@JsonKey(name: 'topup_validity_days') int topupValidityDays,@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double inappPricing,@JsonKey(name: 'inapp_pricing_currency') String inappPricingCurrency
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? carrierId = null,Object? ruleType = null,Object? inactivityLimitDays = null,Object? gracePeriodDays = null,Object? minimumTopupAmount = null,Object? topupValidityDays = null,Object? inappPricing = null,Object? inappPricingCurrency = null,}) {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency)  $default,) {final _that = this;
switch (_that) {
case _CarrierRule():
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'rule_type')  String ruleType, @JsonKey(name: 'inactivity_limit_days')  int inactivityLimitDays, @JsonKey(name: 'grace_period_days')  int gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble)  double minimumTopupAmount, @JsonKey(name: 'topup_validity_days')  int topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble)  double inappPricing, @JsonKey(name: 'inapp_pricing_currency')  String inappPricingCurrency)?  $default,) {final _that = this;
switch (_that) {
case _CarrierRule() when $default != null:
return $default(_that.id,_that.carrierId,_that.ruleType,_that.inactivityLimitDays,_that.gracePeriodDays,_that.minimumTopupAmount,_that.topupValidityDays,_that.inappPricing,_that.inappPricingCurrency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CarrierRule implements CarrierRule {
  const _CarrierRule({required this.id, @JsonKey(name: 'carrier_id') required this.carrierId, @JsonKey(name: 'rule_type') required this.ruleType, @JsonKey(name: 'inactivity_limit_days') required this.inactivityLimitDays, @JsonKey(name: 'grace_period_days') required this.gracePeriodDays, @JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) required this.minimumTopupAmount, @JsonKey(name: 'topup_validity_days') required this.topupValidityDays, @JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) required this.inappPricing, @JsonKey(name: 'inapp_pricing_currency') required this.inappPricingCurrency});
  factory _CarrierRule.fromJson(Map<String, dynamic> json) => _$CarrierRuleFromJson(json);

@override final  String id;
@override@JsonKey(name: 'carrier_id') final  String carrierId;
@override@JsonKey(name: 'rule_type') final  String ruleType;
@override@JsonKey(name: 'inactivity_limit_days') final  int inactivityLimitDays;
@override@JsonKey(name: 'grace_period_days') final  int gracePeriodDays;
@override@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) final  double minimumTopupAmount;
@override@JsonKey(name: 'topup_validity_days') final  int topupValidityDays;
@override@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) final  double inappPricing;
@override@JsonKey(name: 'inapp_pricing_currency') final  String inappPricingCurrency;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CarrierRule&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.ruleType, ruleType) || other.ruleType == ruleType)&&(identical(other.inactivityLimitDays, inactivityLimitDays) || other.inactivityLimitDays == inactivityLimitDays)&&(identical(other.gracePeriodDays, gracePeriodDays) || other.gracePeriodDays == gracePeriodDays)&&(identical(other.minimumTopupAmount, minimumTopupAmount) || other.minimumTopupAmount == minimumTopupAmount)&&(identical(other.topupValidityDays, topupValidityDays) || other.topupValidityDays == topupValidityDays)&&(identical(other.inappPricing, inappPricing) || other.inappPricing == inappPricing)&&(identical(other.inappPricingCurrency, inappPricingCurrency) || other.inappPricingCurrency == inappPricingCurrency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,carrierId,ruleType,inactivityLimitDays,gracePeriodDays,minimumTopupAmount,topupValidityDays,inappPricing,inappPricingCurrency);

@override
String toString() {
  return 'CarrierRule(id: $id, carrierId: $carrierId, ruleType: $ruleType, inactivityLimitDays: $inactivityLimitDays, gracePeriodDays: $gracePeriodDays, minimumTopupAmount: $minimumTopupAmount, topupValidityDays: $topupValidityDays, inappPricing: $inappPricing, inappPricingCurrency: $inappPricingCurrency)';
}


}

/// @nodoc
abstract mixin class _$CarrierRuleCopyWith<$Res> implements $CarrierRuleCopyWith<$Res> {
  factory _$CarrierRuleCopyWith(_CarrierRule value, $Res Function(_CarrierRule) _then) = __$CarrierRuleCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'rule_type') String ruleType,@JsonKey(name: 'inactivity_limit_days') int inactivityLimitDays,@JsonKey(name: 'grace_period_days') int gracePeriodDays,@JsonKey(name: 'minimum_topup_amount', fromJson: _parseDouble) double minimumTopupAmount,@JsonKey(name: 'topup_validity_days') int topupValidityDays,@JsonKey(name: 'inapp_pricing', fromJson: _parseDouble) double inappPricing,@JsonKey(name: 'inapp_pricing_currency') String inappPricingCurrency
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? carrierId = null,Object? ruleType = null,Object? inactivityLimitDays = null,Object? gracePeriodDays = null,Object? minimumTopupAmount = null,Object? topupValidityDays = null,Object? inappPricing = null,Object? inappPricingCurrency = null,}) {
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
as String,
  ));
}


}

// dart format on
