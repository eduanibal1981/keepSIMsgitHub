// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sim_liveness_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SimLivenessResult {

@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'carrier_status') String get carrierStatus;@JsonKey(name: 'detected_operator_name') String? get detectedOperatorName;@JsonKey(name: 'country_code') String? get countryCode;@JsonKey(name: 'reason') String? get reason;@JsonKey(name: 'message') String get message;@JsonKey(name: 'provider') String get provider;@JsonKey(name: 'verified_at') DateTime? get verifiedAt;
/// Create a copy of SimLivenessResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimLivenessResultCopyWith<SimLivenessResult> get copyWith => _$SimLivenessResultCopyWithImpl<SimLivenessResult>(this as SimLivenessResult, _$identity);

  /// Serializes this SimLivenessResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimLivenessResult&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.carrierStatus, carrierStatus) || other.carrierStatus == carrierStatus)&&(identical(other.detectedOperatorName, detectedOperatorName) || other.detectedOperatorName == detectedOperatorName)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.message, message) || other.message == message)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isActive,carrierStatus,detectedOperatorName,countryCode,reason,message,provider,verifiedAt);

@override
String toString() {
  return 'SimLivenessResult(isActive: $isActive, carrierStatus: $carrierStatus, detectedOperatorName: $detectedOperatorName, countryCode: $countryCode, reason: $reason, message: $message, provider: $provider, verifiedAt: $verifiedAt)';
}


}

/// @nodoc
abstract mixin class $SimLivenessResultCopyWith<$Res>  {
  factory $SimLivenessResultCopyWith(SimLivenessResult value, $Res Function(SimLivenessResult) _then) = _$SimLivenessResultCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'carrier_status') String carrierStatus,@JsonKey(name: 'detected_operator_name') String? detectedOperatorName,@JsonKey(name: 'country_code') String? countryCode,@JsonKey(name: 'reason') String? reason,@JsonKey(name: 'message') String message,@JsonKey(name: 'provider') String provider,@JsonKey(name: 'verified_at') DateTime? verifiedAt
});




}
/// @nodoc
class _$SimLivenessResultCopyWithImpl<$Res>
    implements $SimLivenessResultCopyWith<$Res> {
  _$SimLivenessResultCopyWithImpl(this._self, this._then);

  final SimLivenessResult _self;
  final $Res Function(SimLivenessResult) _then;

/// Create a copy of SimLivenessResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isActive = null,Object? carrierStatus = null,Object? detectedOperatorName = freezed,Object? countryCode = freezed,Object? reason = freezed,Object? message = null,Object? provider = null,Object? verifiedAt = freezed,}) {
  return _then(_self.copyWith(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,carrierStatus: null == carrierStatus ? _self.carrierStatus : carrierStatus // ignore: cast_nullable_to_non_nullable
as String,detectedOperatorName: freezed == detectedOperatorName ? _self.detectedOperatorName : detectedOperatorName // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SimLivenessResult].
extension SimLivenessResultPatterns on SimLivenessResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimLivenessResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimLivenessResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimLivenessResult value)  $default,){
final _that = this;
switch (_that) {
case _SimLivenessResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimLivenessResult value)?  $default,){
final _that = this;
switch (_that) {
case _SimLivenessResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'carrier_status')  String carrierStatus, @JsonKey(name: 'detected_operator_name')  String? detectedOperatorName, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'message')  String message, @JsonKey(name: 'provider')  String provider, @JsonKey(name: 'verified_at')  DateTime? verifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimLivenessResult() when $default != null:
return $default(_that.isActive,_that.carrierStatus,_that.detectedOperatorName,_that.countryCode,_that.reason,_that.message,_that.provider,_that.verifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'carrier_status')  String carrierStatus, @JsonKey(name: 'detected_operator_name')  String? detectedOperatorName, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'message')  String message, @JsonKey(name: 'provider')  String provider, @JsonKey(name: 'verified_at')  DateTime? verifiedAt)  $default,) {final _that = this;
switch (_that) {
case _SimLivenessResult():
return $default(_that.isActive,_that.carrierStatus,_that.detectedOperatorName,_that.countryCode,_that.reason,_that.message,_that.provider,_that.verifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'carrier_status')  String carrierStatus, @JsonKey(name: 'detected_operator_name')  String? detectedOperatorName, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'reason')  String? reason, @JsonKey(name: 'message')  String message, @JsonKey(name: 'provider')  String provider, @JsonKey(name: 'verified_at')  DateTime? verifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _SimLivenessResult() when $default != null:
return $default(_that.isActive,_that.carrierStatus,_that.detectedOperatorName,_that.countryCode,_that.reason,_that.message,_that.provider,_that.verifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimLivenessResult implements SimLivenessResult {
  const _SimLivenessResult({@JsonKey(name: 'is_active') this.isActive = false, @JsonKey(name: 'carrier_status') this.carrierStatus = 'pending', @JsonKey(name: 'detected_operator_name') this.detectedOperatorName, @JsonKey(name: 'country_code') this.countryCode, @JsonKey(name: 'reason') this.reason, @JsonKey(name: 'message') this.message = '', @JsonKey(name: 'provider') this.provider = 'none', @JsonKey(name: 'verified_at') this.verifiedAt});
  factory _SimLivenessResult.fromJson(Map<String, dynamic> json) => _$SimLivenessResultFromJson(json);

@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'carrier_status') final  String carrierStatus;
@override@JsonKey(name: 'detected_operator_name') final  String? detectedOperatorName;
@override@JsonKey(name: 'country_code') final  String? countryCode;
@override@JsonKey(name: 'reason') final  String? reason;
@override@JsonKey(name: 'message') final  String message;
@override@JsonKey(name: 'provider') final  String provider;
@override@JsonKey(name: 'verified_at') final  DateTime? verifiedAt;

/// Create a copy of SimLivenessResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimLivenessResultCopyWith<_SimLivenessResult> get copyWith => __$SimLivenessResultCopyWithImpl<_SimLivenessResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimLivenessResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimLivenessResult&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.carrierStatus, carrierStatus) || other.carrierStatus == carrierStatus)&&(identical(other.detectedOperatorName, detectedOperatorName) || other.detectedOperatorName == detectedOperatorName)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.message, message) || other.message == message)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isActive,carrierStatus,detectedOperatorName,countryCode,reason,message,provider,verifiedAt);

@override
String toString() {
  return 'SimLivenessResult(isActive: $isActive, carrierStatus: $carrierStatus, detectedOperatorName: $detectedOperatorName, countryCode: $countryCode, reason: $reason, message: $message, provider: $provider, verifiedAt: $verifiedAt)';
}


}

/// @nodoc
abstract mixin class _$SimLivenessResultCopyWith<$Res> implements $SimLivenessResultCopyWith<$Res> {
  factory _$SimLivenessResultCopyWith(_SimLivenessResult value, $Res Function(_SimLivenessResult) _then) = __$SimLivenessResultCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'carrier_status') String carrierStatus,@JsonKey(name: 'detected_operator_name') String? detectedOperatorName,@JsonKey(name: 'country_code') String? countryCode,@JsonKey(name: 'reason') String? reason,@JsonKey(name: 'message') String message,@JsonKey(name: 'provider') String provider,@JsonKey(name: 'verified_at') DateTime? verifiedAt
});




}
/// @nodoc
class __$SimLivenessResultCopyWithImpl<$Res>
    implements _$SimLivenessResultCopyWith<$Res> {
  __$SimLivenessResultCopyWithImpl(this._self, this._then);

  final _SimLivenessResult _self;
  final $Res Function(_SimLivenessResult) _then;

/// Create a copy of SimLivenessResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isActive = null,Object? carrierStatus = null,Object? detectedOperatorName = freezed,Object? countryCode = freezed,Object? reason = freezed,Object? message = null,Object? provider = null,Object? verifiedAt = freezed,}) {
  return _then(_SimLivenessResult(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,carrierStatus: null == carrierStatus ? _self.carrierStatus : carrierStatus // ignore: cast_nullable_to_non_nullable
as String,detectedOperatorName: freezed == detectedOperatorName ? _self.detectedOperatorName : detectedOperatorName // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
