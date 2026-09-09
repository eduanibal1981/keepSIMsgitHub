// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_verification_quote_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineVerificationQuote {

@JsonKey(name: 'sim_line_id') String get simLineId;@JsonKey(name: 'phone_number') String get phoneNumber;@JsonKey(name: 'country_id') String? get countryId;@JsonKey(name: 'country_name') String? get countryName;@JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble) double get smsVerifyCostUsd;@JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble) double get callVerifyCostUsd;@JsonKey(name: 'is_paid_plan') bool get isPaidPlan;@JsonKey(name: 'has_annual_allowance') bool get hasAnnualAllowance;@JsonKey(name: 'allowance_period_end') DateTime? get allowancePeriodEnd;@JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble) double get walletBalanceUsd;@JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble) double get walletAvailableUsd;@JsonKey(name: 'price_version') int get priceVersion;@JsonKey(name: 'in_flight_attempt_id') String? get inFlightAttemptId;
/// Create a copy of LineVerificationQuote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineVerificationQuoteCopyWith<LineVerificationQuote> get copyWith => _$LineVerificationQuoteCopyWithImpl<LineVerificationQuote>(this as LineVerificationQuote, _$identity);

  /// Serializes this LineVerificationQuote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineVerificationQuote&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.smsVerifyCostUsd, smsVerifyCostUsd) || other.smsVerifyCostUsd == smsVerifyCostUsd)&&(identical(other.callVerifyCostUsd, callVerifyCostUsd) || other.callVerifyCostUsd == callVerifyCostUsd)&&(identical(other.isPaidPlan, isPaidPlan) || other.isPaidPlan == isPaidPlan)&&(identical(other.hasAnnualAllowance, hasAnnualAllowance) || other.hasAnnualAllowance == hasAnnualAllowance)&&(identical(other.allowancePeriodEnd, allowancePeriodEnd) || other.allowancePeriodEnd == allowancePeriodEnd)&&(identical(other.walletBalanceUsd, walletBalanceUsd) || other.walletBalanceUsd == walletBalanceUsd)&&(identical(other.walletAvailableUsd, walletAvailableUsd) || other.walletAvailableUsd == walletAvailableUsd)&&(identical(other.priceVersion, priceVersion) || other.priceVersion == priceVersion)&&(identical(other.inFlightAttemptId, inFlightAttemptId) || other.inFlightAttemptId == inFlightAttemptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,phoneNumber,countryId,countryName,smsVerifyCostUsd,callVerifyCostUsd,isPaidPlan,hasAnnualAllowance,allowancePeriodEnd,walletBalanceUsd,walletAvailableUsd,priceVersion,inFlightAttemptId);

@override
String toString() {
  return 'LineVerificationQuote(simLineId: $simLineId, phoneNumber: $phoneNumber, countryId: $countryId, countryName: $countryName, smsVerifyCostUsd: $smsVerifyCostUsd, callVerifyCostUsd: $callVerifyCostUsd, isPaidPlan: $isPaidPlan, hasAnnualAllowance: $hasAnnualAllowance, allowancePeriodEnd: $allowancePeriodEnd, walletBalanceUsd: $walletBalanceUsd, walletAvailableUsd: $walletAvailableUsd, priceVersion: $priceVersion, inFlightAttemptId: $inFlightAttemptId)';
}


}

/// @nodoc
abstract mixin class $LineVerificationQuoteCopyWith<$Res>  {
  factory $LineVerificationQuoteCopyWith(LineVerificationQuote value, $Res Function(LineVerificationQuote) _then) = _$LineVerificationQuoteCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber,@JsonKey(name: 'country_id') String? countryId,@JsonKey(name: 'country_name') String? countryName,@JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble) double smsVerifyCostUsd,@JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble) double callVerifyCostUsd,@JsonKey(name: 'is_paid_plan') bool isPaidPlan,@JsonKey(name: 'has_annual_allowance') bool hasAnnualAllowance,@JsonKey(name: 'allowance_period_end') DateTime? allowancePeriodEnd,@JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble) double walletBalanceUsd,@JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble) double walletAvailableUsd,@JsonKey(name: 'price_version') int priceVersion,@JsonKey(name: 'in_flight_attempt_id') String? inFlightAttemptId
});




}
/// @nodoc
class _$LineVerificationQuoteCopyWithImpl<$Res>
    implements $LineVerificationQuoteCopyWith<$Res> {
  _$LineVerificationQuoteCopyWithImpl(this._self, this._then);

  final LineVerificationQuote _self;
  final $Res Function(LineVerificationQuote) _then;

/// Create a copy of LineVerificationQuote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? simLineId = null,Object? phoneNumber = null,Object? countryId = freezed,Object? countryName = freezed,Object? smsVerifyCostUsd = null,Object? callVerifyCostUsd = null,Object? isPaidPlan = null,Object? hasAnnualAllowance = null,Object? allowancePeriodEnd = freezed,Object? walletBalanceUsd = null,Object? walletAvailableUsd = null,Object? priceVersion = null,Object? inFlightAttemptId = freezed,}) {
  return _then(_self.copyWith(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,smsVerifyCostUsd: null == smsVerifyCostUsd ? _self.smsVerifyCostUsd : smsVerifyCostUsd // ignore: cast_nullable_to_non_nullable
as double,callVerifyCostUsd: null == callVerifyCostUsd ? _self.callVerifyCostUsd : callVerifyCostUsd // ignore: cast_nullable_to_non_nullable
as double,isPaidPlan: null == isPaidPlan ? _self.isPaidPlan : isPaidPlan // ignore: cast_nullable_to_non_nullable
as bool,hasAnnualAllowance: null == hasAnnualAllowance ? _self.hasAnnualAllowance : hasAnnualAllowance // ignore: cast_nullable_to_non_nullable
as bool,allowancePeriodEnd: freezed == allowancePeriodEnd ? _self.allowancePeriodEnd : allowancePeriodEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,walletBalanceUsd: null == walletBalanceUsd ? _self.walletBalanceUsd : walletBalanceUsd // ignore: cast_nullable_to_non_nullable
as double,walletAvailableUsd: null == walletAvailableUsd ? _self.walletAvailableUsd : walletAvailableUsd // ignore: cast_nullable_to_non_nullable
as double,priceVersion: null == priceVersion ? _self.priceVersion : priceVersion // ignore: cast_nullable_to_non_nullable
as int,inFlightAttemptId: freezed == inFlightAttemptId ? _self.inFlightAttemptId : inFlightAttemptId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineVerificationQuote].
extension LineVerificationQuotePatterns on LineVerificationQuote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineVerificationQuote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineVerificationQuote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineVerificationQuote value)  $default,){
final _that = this;
switch (_that) {
case _LineVerificationQuote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineVerificationQuote value)?  $default,){
final _that = this;
switch (_that) {
case _LineVerificationQuote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'country_name')  String? countryName, @JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble)  double smsVerifyCostUsd, @JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble)  double callVerifyCostUsd, @JsonKey(name: 'is_paid_plan')  bool isPaidPlan, @JsonKey(name: 'has_annual_allowance')  bool hasAnnualAllowance, @JsonKey(name: 'allowance_period_end')  DateTime? allowancePeriodEnd, @JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble)  double walletBalanceUsd, @JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble)  double walletAvailableUsd, @JsonKey(name: 'price_version')  int priceVersion, @JsonKey(name: 'in_flight_attempt_id')  String? inFlightAttemptId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineVerificationQuote() when $default != null:
return $default(_that.simLineId,_that.phoneNumber,_that.countryId,_that.countryName,_that.smsVerifyCostUsd,_that.callVerifyCostUsd,_that.isPaidPlan,_that.hasAnnualAllowance,_that.allowancePeriodEnd,_that.walletBalanceUsd,_that.walletAvailableUsd,_that.priceVersion,_that.inFlightAttemptId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'country_name')  String? countryName, @JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble)  double smsVerifyCostUsd, @JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble)  double callVerifyCostUsd, @JsonKey(name: 'is_paid_plan')  bool isPaidPlan, @JsonKey(name: 'has_annual_allowance')  bool hasAnnualAllowance, @JsonKey(name: 'allowance_period_end')  DateTime? allowancePeriodEnd, @JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble)  double walletBalanceUsd, @JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble)  double walletAvailableUsd, @JsonKey(name: 'price_version')  int priceVersion, @JsonKey(name: 'in_flight_attempt_id')  String? inFlightAttemptId)  $default,) {final _that = this;
switch (_that) {
case _LineVerificationQuote():
return $default(_that.simLineId,_that.phoneNumber,_that.countryId,_that.countryName,_that.smsVerifyCostUsd,_that.callVerifyCostUsd,_that.isPaidPlan,_that.hasAnnualAllowance,_that.allowancePeriodEnd,_that.walletBalanceUsd,_that.walletAvailableUsd,_that.priceVersion,_that.inFlightAttemptId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'country_name')  String? countryName, @JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble)  double smsVerifyCostUsd, @JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble)  double callVerifyCostUsd, @JsonKey(name: 'is_paid_plan')  bool isPaidPlan, @JsonKey(name: 'has_annual_allowance')  bool hasAnnualAllowance, @JsonKey(name: 'allowance_period_end')  DateTime? allowancePeriodEnd, @JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble)  double walletBalanceUsd, @JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble)  double walletAvailableUsd, @JsonKey(name: 'price_version')  int priceVersion, @JsonKey(name: 'in_flight_attempt_id')  String? inFlightAttemptId)?  $default,) {final _that = this;
switch (_that) {
case _LineVerificationQuote() when $default != null:
return $default(_that.simLineId,_that.phoneNumber,_that.countryId,_that.countryName,_that.smsVerifyCostUsd,_that.callVerifyCostUsd,_that.isPaidPlan,_that.hasAnnualAllowance,_that.allowancePeriodEnd,_that.walletBalanceUsd,_that.walletAvailableUsd,_that.priceVersion,_that.inFlightAttemptId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineVerificationQuote implements LineVerificationQuote {
  const _LineVerificationQuote({@JsonKey(name: 'sim_line_id') required this.simLineId, @JsonKey(name: 'phone_number') required this.phoneNumber, @JsonKey(name: 'country_id') this.countryId, @JsonKey(name: 'country_name') this.countryName, @JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble) this.smsVerifyCostUsd = 0.0, @JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble) this.callVerifyCostUsd = 0.0, @JsonKey(name: 'is_paid_plan') this.isPaidPlan = false, @JsonKey(name: 'has_annual_allowance') this.hasAnnualAllowance = false, @JsonKey(name: 'allowance_period_end') this.allowancePeriodEnd, @JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble) this.walletBalanceUsd = 0.0, @JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble) this.walletAvailableUsd = 0.0, @JsonKey(name: 'price_version') this.priceVersion = 1, @JsonKey(name: 'in_flight_attempt_id') this.inFlightAttemptId});
  factory _LineVerificationQuote.fromJson(Map<String, dynamic> json) => _$LineVerificationQuoteFromJson(json);

@override@JsonKey(name: 'sim_line_id') final  String simLineId;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override@JsonKey(name: 'country_id') final  String? countryId;
@override@JsonKey(name: 'country_name') final  String? countryName;
@override@JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble) final  double smsVerifyCostUsd;
@override@JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble) final  double callVerifyCostUsd;
@override@JsonKey(name: 'is_paid_plan') final  bool isPaidPlan;
@override@JsonKey(name: 'has_annual_allowance') final  bool hasAnnualAllowance;
@override@JsonKey(name: 'allowance_period_end') final  DateTime? allowancePeriodEnd;
@override@JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble) final  double walletBalanceUsd;
@override@JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble) final  double walletAvailableUsd;
@override@JsonKey(name: 'price_version') final  int priceVersion;
@override@JsonKey(name: 'in_flight_attempt_id') final  String? inFlightAttemptId;

/// Create a copy of LineVerificationQuote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineVerificationQuoteCopyWith<_LineVerificationQuote> get copyWith => __$LineVerificationQuoteCopyWithImpl<_LineVerificationQuote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineVerificationQuoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineVerificationQuote&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.smsVerifyCostUsd, smsVerifyCostUsd) || other.smsVerifyCostUsd == smsVerifyCostUsd)&&(identical(other.callVerifyCostUsd, callVerifyCostUsd) || other.callVerifyCostUsd == callVerifyCostUsd)&&(identical(other.isPaidPlan, isPaidPlan) || other.isPaidPlan == isPaidPlan)&&(identical(other.hasAnnualAllowance, hasAnnualAllowance) || other.hasAnnualAllowance == hasAnnualAllowance)&&(identical(other.allowancePeriodEnd, allowancePeriodEnd) || other.allowancePeriodEnd == allowancePeriodEnd)&&(identical(other.walletBalanceUsd, walletBalanceUsd) || other.walletBalanceUsd == walletBalanceUsd)&&(identical(other.walletAvailableUsd, walletAvailableUsd) || other.walletAvailableUsd == walletAvailableUsd)&&(identical(other.priceVersion, priceVersion) || other.priceVersion == priceVersion)&&(identical(other.inFlightAttemptId, inFlightAttemptId) || other.inFlightAttemptId == inFlightAttemptId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,phoneNumber,countryId,countryName,smsVerifyCostUsd,callVerifyCostUsd,isPaidPlan,hasAnnualAllowance,allowancePeriodEnd,walletBalanceUsd,walletAvailableUsd,priceVersion,inFlightAttemptId);

@override
String toString() {
  return 'LineVerificationQuote(simLineId: $simLineId, phoneNumber: $phoneNumber, countryId: $countryId, countryName: $countryName, smsVerifyCostUsd: $smsVerifyCostUsd, callVerifyCostUsd: $callVerifyCostUsd, isPaidPlan: $isPaidPlan, hasAnnualAllowance: $hasAnnualAllowance, allowancePeriodEnd: $allowancePeriodEnd, walletBalanceUsd: $walletBalanceUsd, walletAvailableUsd: $walletAvailableUsd, priceVersion: $priceVersion, inFlightAttemptId: $inFlightAttemptId)';
}


}

/// @nodoc
abstract mixin class _$LineVerificationQuoteCopyWith<$Res> implements $LineVerificationQuoteCopyWith<$Res> {
  factory _$LineVerificationQuoteCopyWith(_LineVerificationQuote value, $Res Function(_LineVerificationQuote) _then) = __$LineVerificationQuoteCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber,@JsonKey(name: 'country_id') String? countryId,@JsonKey(name: 'country_name') String? countryName,@JsonKey(name: 'sms_verify_cost_usd', fromJson: _parseDouble) double smsVerifyCostUsd,@JsonKey(name: 'call_verify_cost_usd', fromJson: _parseDouble) double callVerifyCostUsd,@JsonKey(name: 'is_paid_plan') bool isPaidPlan,@JsonKey(name: 'has_annual_allowance') bool hasAnnualAllowance,@JsonKey(name: 'allowance_period_end') DateTime? allowancePeriodEnd,@JsonKey(name: 'wallet_balance_usd', fromJson: _parseDouble) double walletBalanceUsd,@JsonKey(name: 'wallet_available_usd', fromJson: _parseDouble) double walletAvailableUsd,@JsonKey(name: 'price_version') int priceVersion,@JsonKey(name: 'in_flight_attempt_id') String? inFlightAttemptId
});




}
/// @nodoc
class __$LineVerificationQuoteCopyWithImpl<$Res>
    implements _$LineVerificationQuoteCopyWith<$Res> {
  __$LineVerificationQuoteCopyWithImpl(this._self, this._then);

  final _LineVerificationQuote _self;
  final $Res Function(_LineVerificationQuote) _then;

/// Create a copy of LineVerificationQuote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? simLineId = null,Object? phoneNumber = null,Object? countryId = freezed,Object? countryName = freezed,Object? smsVerifyCostUsd = null,Object? callVerifyCostUsd = null,Object? isPaidPlan = null,Object? hasAnnualAllowance = null,Object? allowancePeriodEnd = freezed,Object? walletBalanceUsd = null,Object? walletAvailableUsd = null,Object? priceVersion = null,Object? inFlightAttemptId = freezed,}) {
  return _then(_LineVerificationQuote(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,smsVerifyCostUsd: null == smsVerifyCostUsd ? _self.smsVerifyCostUsd : smsVerifyCostUsd // ignore: cast_nullable_to_non_nullable
as double,callVerifyCostUsd: null == callVerifyCostUsd ? _self.callVerifyCostUsd : callVerifyCostUsd // ignore: cast_nullable_to_non_nullable
as double,isPaidPlan: null == isPaidPlan ? _self.isPaidPlan : isPaidPlan // ignore: cast_nullable_to_non_nullable
as bool,hasAnnualAllowance: null == hasAnnualAllowance ? _self.hasAnnualAllowance : hasAnnualAllowance // ignore: cast_nullable_to_non_nullable
as bool,allowancePeriodEnd: freezed == allowancePeriodEnd ? _self.allowancePeriodEnd : allowancePeriodEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,walletBalanceUsd: null == walletBalanceUsd ? _self.walletBalanceUsd : walletBalanceUsd // ignore: cast_nullable_to_non_nullable
as double,walletAvailableUsd: null == walletAvailableUsd ? _self.walletAvailableUsd : walletAvailableUsd // ignore: cast_nullable_to_non_nullable
as double,priceVersion: null == priceVersion ? _self.priceVersion : priceVersion // ignore: cast_nullable_to_non_nullable
as int,inFlightAttemptId: freezed == inFlightAttemptId ? _self.inFlightAttemptId : inFlightAttemptId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
