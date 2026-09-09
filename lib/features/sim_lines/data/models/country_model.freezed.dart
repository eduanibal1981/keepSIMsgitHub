// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'country_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Country {

 String get id; String get name;@JsonKey(name: 'iso_code') String get isoCode;@JsonKey(name: 'dialing_code') String get dialingCode;@JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji) String get flagEmoji;@JsonKey(name: 'currency_code') String get currencyCode;@JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable) double? get avgSimReplacementCost;@JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue) bool get isSupported;@JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable) double? get smsVerifyCost;@JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable) double? get callVerifyCost;@JsonKey(name: 'verification_price_version') int get verificationPriceVersion;
/// Create a copy of Country
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountryCopyWith<Country> get copyWith => _$CountryCopyWithImpl<Country>(this as Country, _$identity);

  /// Serializes this Country to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Country&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isoCode, isoCode) || other.isoCode == isoCode)&&(identical(other.dialingCode, dialingCode) || other.dialingCode == dialingCode)&&(identical(other.flagEmoji, flagEmoji) || other.flagEmoji == flagEmoji)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.avgSimReplacementCost, avgSimReplacementCost) || other.avgSimReplacementCost == avgSimReplacementCost)&&(identical(other.isSupported, isSupported) || other.isSupported == isSupported)&&(identical(other.smsVerifyCost, smsVerifyCost) || other.smsVerifyCost == smsVerifyCost)&&(identical(other.callVerifyCost, callVerifyCost) || other.callVerifyCost == callVerifyCost)&&(identical(other.verificationPriceVersion, verificationPriceVersion) || other.verificationPriceVersion == verificationPriceVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isoCode,dialingCode,flagEmoji,currencyCode,avgSimReplacementCost,isSupported,smsVerifyCost,callVerifyCost,verificationPriceVersion);

@override
String toString() {
  return 'Country(id: $id, name: $name, isoCode: $isoCode, dialingCode: $dialingCode, flagEmoji: $flagEmoji, currencyCode: $currencyCode, avgSimReplacementCost: $avgSimReplacementCost, isSupported: $isSupported, smsVerifyCost: $smsVerifyCost, callVerifyCost: $callVerifyCost, verificationPriceVersion: $verificationPriceVersion)';
}


}

/// @nodoc
abstract mixin class $CountryCopyWith<$Res>  {
  factory $CountryCopyWith(Country value, $Res Function(Country) _then) = _$CountryCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'iso_code') String isoCode,@JsonKey(name: 'dialing_code') String dialingCode,@JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji) String flagEmoji,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable) double? avgSimReplacementCost,@JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue) bool isSupported,@JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable) double? smsVerifyCost,@JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable) double? callVerifyCost,@JsonKey(name: 'verification_price_version') int verificationPriceVersion
});




}
/// @nodoc
class _$CountryCopyWithImpl<$Res>
    implements $CountryCopyWith<$Res> {
  _$CountryCopyWithImpl(this._self, this._then);

  final Country _self;
  final $Res Function(Country) _then;

/// Create a copy of Country
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isoCode = null,Object? dialingCode = null,Object? flagEmoji = null,Object? currencyCode = null,Object? avgSimReplacementCost = freezed,Object? isSupported = null,Object? smsVerifyCost = freezed,Object? callVerifyCost = freezed,Object? verificationPriceVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isoCode: null == isoCode ? _self.isoCode : isoCode // ignore: cast_nullable_to_non_nullable
as String,dialingCode: null == dialingCode ? _self.dialingCode : dialingCode // ignore: cast_nullable_to_non_nullable
as String,flagEmoji: null == flagEmoji ? _self.flagEmoji : flagEmoji // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,avgSimReplacementCost: freezed == avgSimReplacementCost ? _self.avgSimReplacementCost : avgSimReplacementCost // ignore: cast_nullable_to_non_nullable
as double?,isSupported: null == isSupported ? _self.isSupported : isSupported // ignore: cast_nullable_to_non_nullable
as bool,smsVerifyCost: freezed == smsVerifyCost ? _self.smsVerifyCost : smsVerifyCost // ignore: cast_nullable_to_non_nullable
as double?,callVerifyCost: freezed == callVerifyCost ? _self.callVerifyCost : callVerifyCost // ignore: cast_nullable_to_non_nullable
as double?,verificationPriceVersion: null == verificationPriceVersion ? _self.verificationPriceVersion : verificationPriceVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Country].
extension CountryPatterns on Country {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Country value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Country() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Country value)  $default,){
final _that = this;
switch (_that) {
case _Country():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Country value)?  $default,){
final _that = this;
switch (_that) {
case _Country() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'iso_code')  String isoCode, @JsonKey(name: 'dialing_code')  String dialingCode, @JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji)  String flagEmoji, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable)  double? avgSimReplacementCost, @JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue)  bool isSupported, @JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable)  double? smsVerifyCost, @JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable)  double? callVerifyCost, @JsonKey(name: 'verification_price_version')  int verificationPriceVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Country() when $default != null:
return $default(_that.id,_that.name,_that.isoCode,_that.dialingCode,_that.flagEmoji,_that.currencyCode,_that.avgSimReplacementCost,_that.isSupported,_that.smsVerifyCost,_that.callVerifyCost,_that.verificationPriceVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'iso_code')  String isoCode, @JsonKey(name: 'dialing_code')  String dialingCode, @JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji)  String flagEmoji, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable)  double? avgSimReplacementCost, @JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue)  bool isSupported, @JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable)  double? smsVerifyCost, @JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable)  double? callVerifyCost, @JsonKey(name: 'verification_price_version')  int verificationPriceVersion)  $default,) {final _that = this;
switch (_that) {
case _Country():
return $default(_that.id,_that.name,_that.isoCode,_that.dialingCode,_that.flagEmoji,_that.currencyCode,_that.avgSimReplacementCost,_that.isSupported,_that.smsVerifyCost,_that.callVerifyCost,_that.verificationPriceVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'iso_code')  String isoCode, @JsonKey(name: 'dialing_code')  String dialingCode, @JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji)  String flagEmoji, @JsonKey(name: 'currency_code')  String currencyCode, @JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable)  double? avgSimReplacementCost, @JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue)  bool isSupported, @JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable)  double? smsVerifyCost, @JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable)  double? callVerifyCost, @JsonKey(name: 'verification_price_version')  int verificationPriceVersion)?  $default,) {final _that = this;
switch (_that) {
case _Country() when $default != null:
return $default(_that.id,_that.name,_that.isoCode,_that.dialingCode,_that.flagEmoji,_that.currencyCode,_that.avgSimReplacementCost,_that.isSupported,_that.smsVerifyCost,_that.callVerifyCost,_that.verificationPriceVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Country implements Country {
  const _Country({required this.id, required this.name, @JsonKey(name: 'iso_code') required this.isoCode, @JsonKey(name: 'dialing_code') required this.dialingCode, @JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji) this.flagEmoji = '🌐', @JsonKey(name: 'currency_code') required this.currencyCode, @JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable) this.avgSimReplacementCost, @JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue) this.isSupported = true, @JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable) this.smsVerifyCost = 0.0, @JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable) this.callVerifyCost = 0.0, @JsonKey(name: 'verification_price_version') this.verificationPriceVersion = 1});
  factory _Country.fromJson(Map<String, dynamic> json) => _$CountryFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'iso_code') final  String isoCode;
@override@JsonKey(name: 'dialing_code') final  String dialingCode;
@override@JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji) final  String flagEmoji;
@override@JsonKey(name: 'currency_code') final  String currencyCode;
@override@JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable) final  double? avgSimReplacementCost;
@override@JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue) final  bool isSupported;
@override@JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable) final  double? smsVerifyCost;
@override@JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable) final  double? callVerifyCost;
@override@JsonKey(name: 'verification_price_version') final  int verificationPriceVersion;

/// Create a copy of Country
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountryCopyWith<_Country> get copyWith => __$CountryCopyWithImpl<_Country>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Country&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isoCode, isoCode) || other.isoCode == isoCode)&&(identical(other.dialingCode, dialingCode) || other.dialingCode == dialingCode)&&(identical(other.flagEmoji, flagEmoji) || other.flagEmoji == flagEmoji)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.avgSimReplacementCost, avgSimReplacementCost) || other.avgSimReplacementCost == avgSimReplacementCost)&&(identical(other.isSupported, isSupported) || other.isSupported == isSupported)&&(identical(other.smsVerifyCost, smsVerifyCost) || other.smsVerifyCost == smsVerifyCost)&&(identical(other.callVerifyCost, callVerifyCost) || other.callVerifyCost == callVerifyCost)&&(identical(other.verificationPriceVersion, verificationPriceVersion) || other.verificationPriceVersion == verificationPriceVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isoCode,dialingCode,flagEmoji,currencyCode,avgSimReplacementCost,isSupported,smsVerifyCost,callVerifyCost,verificationPriceVersion);

@override
String toString() {
  return 'Country(id: $id, name: $name, isoCode: $isoCode, dialingCode: $dialingCode, flagEmoji: $flagEmoji, currencyCode: $currencyCode, avgSimReplacementCost: $avgSimReplacementCost, isSupported: $isSupported, smsVerifyCost: $smsVerifyCost, callVerifyCost: $callVerifyCost, verificationPriceVersion: $verificationPriceVersion)';
}


}

/// @nodoc
abstract mixin class _$CountryCopyWith<$Res> implements $CountryCopyWith<$Res> {
  factory _$CountryCopyWith(_Country value, $Res Function(_Country) _then) = __$CountryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'iso_code') String isoCode,@JsonKey(name: 'dialing_code') String dialingCode,@JsonKey(name: 'flag_emoji', fromJson: _parseFlagEmoji) String flagEmoji,@JsonKey(name: 'currency_code') String currencyCode,@JsonKey(name: 'avg_sim_replacement_cost', fromJson: _parseDoubleNullable) double? avgSimReplacementCost,@JsonKey(name: 'is_supported', fromJson: _parseBoolDefaultTrue) bool isSupported,@JsonKey(name: 'sms_verify_cost', fromJson: _parseDoubleNullable) double? smsVerifyCost,@JsonKey(name: 'call_verify_cost', fromJson: _parseDoubleNullable) double? callVerifyCost,@JsonKey(name: 'verification_price_version') int verificationPriceVersion
});




}
/// @nodoc
class __$CountryCopyWithImpl<$Res>
    implements _$CountryCopyWith<$Res> {
  __$CountryCopyWithImpl(this._self, this._then);

  final _Country _self;
  final $Res Function(_Country) _then;

/// Create a copy of Country
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isoCode = null,Object? dialingCode = null,Object? flagEmoji = null,Object? currencyCode = null,Object? avgSimReplacementCost = freezed,Object? isSupported = null,Object? smsVerifyCost = freezed,Object? callVerifyCost = freezed,Object? verificationPriceVersion = null,}) {
  return _then(_Country(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isoCode: null == isoCode ? _self.isoCode : isoCode // ignore: cast_nullable_to_non_nullable
as String,dialingCode: null == dialingCode ? _self.dialingCode : dialingCode // ignore: cast_nullable_to_non_nullable
as String,flagEmoji: null == flagEmoji ? _self.flagEmoji : flagEmoji // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,avgSimReplacementCost: freezed == avgSimReplacementCost ? _self.avgSimReplacementCost : avgSimReplacementCost // ignore: cast_nullable_to_non_nullable
as double?,isSupported: null == isSupported ? _self.isSupported : isSupported // ignore: cast_nullable_to_non_nullable
as bool,smsVerifyCost: freezed == smsVerifyCost ? _self.smsVerifyCost : smsVerifyCost // ignore: cast_nullable_to_non_nullable
as double?,callVerifyCost: freezed == callVerifyCost ? _self.callVerifyCost : callVerifyCost // ignore: cast_nullable_to_non_nullable
as double?,verificationPriceVersion: null == verificationPriceVersion ? _self.verificationPriceVersion : verificationPriceVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
