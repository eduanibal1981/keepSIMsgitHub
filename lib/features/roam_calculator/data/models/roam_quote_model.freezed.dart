// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'roam_quote_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoamQuote {

 String get destinationCountryCode; String get destinationCountryName; int get tripDays; int get tripDataMb; String? get roamingCarrierId; String? get roamingCarrierName; String? get roamingHomeCountry; String? get roamingProductName;/// `day_pass` | `bundle` | `payg`.
 String? get roamingProductKind;/// `country` (a tariff for this destination) | `worldwide` (a zone pass).
 String? get roamingScope;/// Packs needed, or days for a day pass, or megabytes for pay-as-you-go.
 int? get roamingUnits; double? get roamingTotalUsd; bool get roamingIsEstimate; String? get roamingSourceUrl; DateTime? get roamingPricedAsOf; String? get esimOfferId; String? get esimBundleName; int? get esimDataMb; int? get esimDurationDays; int? get esimQuantity; double? get esimUnitPriceUsd; double? get esimTotalUsd; bool get esimCoversTrip;/// Positive when the eSIM is cheaper. Null unless both sides are priced
/// *and* the eSIM actually covers the trip.
 double? get savingsUsd; String get verdict;
/// Create a copy of RoamQuote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoamQuoteCopyWith<RoamQuote> get copyWith => _$RoamQuoteCopyWithImpl<RoamQuote>(this as RoamQuote, _$identity);

  /// Serializes this RoamQuote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoamQuote&&(identical(other.destinationCountryCode, destinationCountryCode) || other.destinationCountryCode == destinationCountryCode)&&(identical(other.destinationCountryName, destinationCountryName) || other.destinationCountryName == destinationCountryName)&&(identical(other.tripDays, tripDays) || other.tripDays == tripDays)&&(identical(other.tripDataMb, tripDataMb) || other.tripDataMb == tripDataMb)&&(identical(other.roamingCarrierId, roamingCarrierId) || other.roamingCarrierId == roamingCarrierId)&&(identical(other.roamingCarrierName, roamingCarrierName) || other.roamingCarrierName == roamingCarrierName)&&(identical(other.roamingHomeCountry, roamingHomeCountry) || other.roamingHomeCountry == roamingHomeCountry)&&(identical(other.roamingProductName, roamingProductName) || other.roamingProductName == roamingProductName)&&(identical(other.roamingProductKind, roamingProductKind) || other.roamingProductKind == roamingProductKind)&&(identical(other.roamingScope, roamingScope) || other.roamingScope == roamingScope)&&(identical(other.roamingUnits, roamingUnits) || other.roamingUnits == roamingUnits)&&(identical(other.roamingTotalUsd, roamingTotalUsd) || other.roamingTotalUsd == roamingTotalUsd)&&(identical(other.roamingIsEstimate, roamingIsEstimate) || other.roamingIsEstimate == roamingIsEstimate)&&(identical(other.roamingSourceUrl, roamingSourceUrl) || other.roamingSourceUrl == roamingSourceUrl)&&(identical(other.roamingPricedAsOf, roamingPricedAsOf) || other.roamingPricedAsOf == roamingPricedAsOf)&&(identical(other.esimOfferId, esimOfferId) || other.esimOfferId == esimOfferId)&&(identical(other.esimBundleName, esimBundleName) || other.esimBundleName == esimBundleName)&&(identical(other.esimDataMb, esimDataMb) || other.esimDataMb == esimDataMb)&&(identical(other.esimDurationDays, esimDurationDays) || other.esimDurationDays == esimDurationDays)&&(identical(other.esimQuantity, esimQuantity) || other.esimQuantity == esimQuantity)&&(identical(other.esimUnitPriceUsd, esimUnitPriceUsd) || other.esimUnitPriceUsd == esimUnitPriceUsd)&&(identical(other.esimTotalUsd, esimTotalUsd) || other.esimTotalUsd == esimTotalUsd)&&(identical(other.esimCoversTrip, esimCoversTrip) || other.esimCoversTrip == esimCoversTrip)&&(identical(other.savingsUsd, savingsUsd) || other.savingsUsd == savingsUsd)&&(identical(other.verdict, verdict) || other.verdict == verdict));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,destinationCountryCode,destinationCountryName,tripDays,tripDataMb,roamingCarrierId,roamingCarrierName,roamingHomeCountry,roamingProductName,roamingProductKind,roamingScope,roamingUnits,roamingTotalUsd,roamingIsEstimate,roamingSourceUrl,roamingPricedAsOf,esimOfferId,esimBundleName,esimDataMb,esimDurationDays,esimQuantity,esimUnitPriceUsd,esimTotalUsd,esimCoversTrip,savingsUsd,verdict]);

@override
String toString() {
  return 'RoamQuote(destinationCountryCode: $destinationCountryCode, destinationCountryName: $destinationCountryName, tripDays: $tripDays, tripDataMb: $tripDataMb, roamingCarrierId: $roamingCarrierId, roamingCarrierName: $roamingCarrierName, roamingHomeCountry: $roamingHomeCountry, roamingProductName: $roamingProductName, roamingProductKind: $roamingProductKind, roamingScope: $roamingScope, roamingUnits: $roamingUnits, roamingTotalUsd: $roamingTotalUsd, roamingIsEstimate: $roamingIsEstimate, roamingSourceUrl: $roamingSourceUrl, roamingPricedAsOf: $roamingPricedAsOf, esimOfferId: $esimOfferId, esimBundleName: $esimBundleName, esimDataMb: $esimDataMb, esimDurationDays: $esimDurationDays, esimQuantity: $esimQuantity, esimUnitPriceUsd: $esimUnitPriceUsd, esimTotalUsd: $esimTotalUsd, esimCoversTrip: $esimCoversTrip, savingsUsd: $savingsUsd, verdict: $verdict)';
}


}

/// @nodoc
abstract mixin class $RoamQuoteCopyWith<$Res>  {
  factory $RoamQuoteCopyWith(RoamQuote value, $Res Function(RoamQuote) _then) = _$RoamQuoteCopyWithImpl;
@useResult
$Res call({
 String destinationCountryCode, String destinationCountryName, int tripDays, int tripDataMb, String? roamingCarrierId, String? roamingCarrierName, String? roamingHomeCountry, String? roamingProductName, String? roamingProductKind, String? roamingScope, int? roamingUnits, double? roamingTotalUsd, bool roamingIsEstimate, String? roamingSourceUrl, DateTime? roamingPricedAsOf, String? esimOfferId, String? esimBundleName, int? esimDataMb, int? esimDurationDays, int? esimQuantity, double? esimUnitPriceUsd, double? esimTotalUsd, bool esimCoversTrip, double? savingsUsd, String verdict
});




}
/// @nodoc
class _$RoamQuoteCopyWithImpl<$Res>
    implements $RoamQuoteCopyWith<$Res> {
  _$RoamQuoteCopyWithImpl(this._self, this._then);

  final RoamQuote _self;
  final $Res Function(RoamQuote) _then;

/// Create a copy of RoamQuote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? destinationCountryCode = null,Object? destinationCountryName = null,Object? tripDays = null,Object? tripDataMb = null,Object? roamingCarrierId = freezed,Object? roamingCarrierName = freezed,Object? roamingHomeCountry = freezed,Object? roamingProductName = freezed,Object? roamingProductKind = freezed,Object? roamingScope = freezed,Object? roamingUnits = freezed,Object? roamingTotalUsd = freezed,Object? roamingIsEstimate = null,Object? roamingSourceUrl = freezed,Object? roamingPricedAsOf = freezed,Object? esimOfferId = freezed,Object? esimBundleName = freezed,Object? esimDataMb = freezed,Object? esimDurationDays = freezed,Object? esimQuantity = freezed,Object? esimUnitPriceUsd = freezed,Object? esimTotalUsd = freezed,Object? esimCoversTrip = null,Object? savingsUsd = freezed,Object? verdict = null,}) {
  return _then(_self.copyWith(
destinationCountryCode: null == destinationCountryCode ? _self.destinationCountryCode : destinationCountryCode // ignore: cast_nullable_to_non_nullable
as String,destinationCountryName: null == destinationCountryName ? _self.destinationCountryName : destinationCountryName // ignore: cast_nullable_to_non_nullable
as String,tripDays: null == tripDays ? _self.tripDays : tripDays // ignore: cast_nullable_to_non_nullable
as int,tripDataMb: null == tripDataMb ? _self.tripDataMb : tripDataMb // ignore: cast_nullable_to_non_nullable
as int,roamingCarrierId: freezed == roamingCarrierId ? _self.roamingCarrierId : roamingCarrierId // ignore: cast_nullable_to_non_nullable
as String?,roamingCarrierName: freezed == roamingCarrierName ? _self.roamingCarrierName : roamingCarrierName // ignore: cast_nullable_to_non_nullable
as String?,roamingHomeCountry: freezed == roamingHomeCountry ? _self.roamingHomeCountry : roamingHomeCountry // ignore: cast_nullable_to_non_nullable
as String?,roamingProductName: freezed == roamingProductName ? _self.roamingProductName : roamingProductName // ignore: cast_nullable_to_non_nullable
as String?,roamingProductKind: freezed == roamingProductKind ? _self.roamingProductKind : roamingProductKind // ignore: cast_nullable_to_non_nullable
as String?,roamingScope: freezed == roamingScope ? _self.roamingScope : roamingScope // ignore: cast_nullable_to_non_nullable
as String?,roamingUnits: freezed == roamingUnits ? _self.roamingUnits : roamingUnits // ignore: cast_nullable_to_non_nullable
as int?,roamingTotalUsd: freezed == roamingTotalUsd ? _self.roamingTotalUsd : roamingTotalUsd // ignore: cast_nullable_to_non_nullable
as double?,roamingIsEstimate: null == roamingIsEstimate ? _self.roamingIsEstimate : roamingIsEstimate // ignore: cast_nullable_to_non_nullable
as bool,roamingSourceUrl: freezed == roamingSourceUrl ? _self.roamingSourceUrl : roamingSourceUrl // ignore: cast_nullable_to_non_nullable
as String?,roamingPricedAsOf: freezed == roamingPricedAsOf ? _self.roamingPricedAsOf : roamingPricedAsOf // ignore: cast_nullable_to_non_nullable
as DateTime?,esimOfferId: freezed == esimOfferId ? _self.esimOfferId : esimOfferId // ignore: cast_nullable_to_non_nullable
as String?,esimBundleName: freezed == esimBundleName ? _self.esimBundleName : esimBundleName // ignore: cast_nullable_to_non_nullable
as String?,esimDataMb: freezed == esimDataMb ? _self.esimDataMb : esimDataMb // ignore: cast_nullable_to_non_nullable
as int?,esimDurationDays: freezed == esimDurationDays ? _self.esimDurationDays : esimDurationDays // ignore: cast_nullable_to_non_nullable
as int?,esimQuantity: freezed == esimQuantity ? _self.esimQuantity : esimQuantity // ignore: cast_nullable_to_non_nullable
as int?,esimUnitPriceUsd: freezed == esimUnitPriceUsd ? _self.esimUnitPriceUsd : esimUnitPriceUsd // ignore: cast_nullable_to_non_nullable
as double?,esimTotalUsd: freezed == esimTotalUsd ? _self.esimTotalUsd : esimTotalUsd // ignore: cast_nullable_to_non_nullable
as double?,esimCoversTrip: null == esimCoversTrip ? _self.esimCoversTrip : esimCoversTrip // ignore: cast_nullable_to_non_nullable
as bool,savingsUsd: freezed == savingsUsd ? _self.savingsUsd : savingsUsd // ignore: cast_nullable_to_non_nullable
as double?,verdict: null == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RoamQuote].
extension RoamQuotePatterns on RoamQuote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoamQuote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoamQuote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoamQuote value)  $default,){
final _that = this;
switch (_that) {
case _RoamQuote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoamQuote value)?  $default,){
final _that = this;
switch (_that) {
case _RoamQuote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String destinationCountryCode,  String destinationCountryName,  int tripDays,  int tripDataMb,  String? roamingCarrierId,  String? roamingCarrierName,  String? roamingHomeCountry,  String? roamingProductName,  String? roamingProductKind,  String? roamingScope,  int? roamingUnits,  double? roamingTotalUsd,  bool roamingIsEstimate,  String? roamingSourceUrl,  DateTime? roamingPricedAsOf,  String? esimOfferId,  String? esimBundleName,  int? esimDataMb,  int? esimDurationDays,  int? esimQuantity,  double? esimUnitPriceUsd,  double? esimTotalUsd,  bool esimCoversTrip,  double? savingsUsd,  String verdict)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoamQuote() when $default != null:
return $default(_that.destinationCountryCode,_that.destinationCountryName,_that.tripDays,_that.tripDataMb,_that.roamingCarrierId,_that.roamingCarrierName,_that.roamingHomeCountry,_that.roamingProductName,_that.roamingProductKind,_that.roamingScope,_that.roamingUnits,_that.roamingTotalUsd,_that.roamingIsEstimate,_that.roamingSourceUrl,_that.roamingPricedAsOf,_that.esimOfferId,_that.esimBundleName,_that.esimDataMb,_that.esimDurationDays,_that.esimQuantity,_that.esimUnitPriceUsd,_that.esimTotalUsd,_that.esimCoversTrip,_that.savingsUsd,_that.verdict);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String destinationCountryCode,  String destinationCountryName,  int tripDays,  int tripDataMb,  String? roamingCarrierId,  String? roamingCarrierName,  String? roamingHomeCountry,  String? roamingProductName,  String? roamingProductKind,  String? roamingScope,  int? roamingUnits,  double? roamingTotalUsd,  bool roamingIsEstimate,  String? roamingSourceUrl,  DateTime? roamingPricedAsOf,  String? esimOfferId,  String? esimBundleName,  int? esimDataMb,  int? esimDurationDays,  int? esimQuantity,  double? esimUnitPriceUsd,  double? esimTotalUsd,  bool esimCoversTrip,  double? savingsUsd,  String verdict)  $default,) {final _that = this;
switch (_that) {
case _RoamQuote():
return $default(_that.destinationCountryCode,_that.destinationCountryName,_that.tripDays,_that.tripDataMb,_that.roamingCarrierId,_that.roamingCarrierName,_that.roamingHomeCountry,_that.roamingProductName,_that.roamingProductKind,_that.roamingScope,_that.roamingUnits,_that.roamingTotalUsd,_that.roamingIsEstimate,_that.roamingSourceUrl,_that.roamingPricedAsOf,_that.esimOfferId,_that.esimBundleName,_that.esimDataMb,_that.esimDurationDays,_that.esimQuantity,_that.esimUnitPriceUsd,_that.esimTotalUsd,_that.esimCoversTrip,_that.savingsUsd,_that.verdict);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String destinationCountryCode,  String destinationCountryName,  int tripDays,  int tripDataMb,  String? roamingCarrierId,  String? roamingCarrierName,  String? roamingHomeCountry,  String? roamingProductName,  String? roamingProductKind,  String? roamingScope,  int? roamingUnits,  double? roamingTotalUsd,  bool roamingIsEstimate,  String? roamingSourceUrl,  DateTime? roamingPricedAsOf,  String? esimOfferId,  String? esimBundleName,  int? esimDataMb,  int? esimDurationDays,  int? esimQuantity,  double? esimUnitPriceUsd,  double? esimTotalUsd,  bool esimCoversTrip,  double? savingsUsd,  String verdict)?  $default,) {final _that = this;
switch (_that) {
case _RoamQuote() when $default != null:
return $default(_that.destinationCountryCode,_that.destinationCountryName,_that.tripDays,_that.tripDataMb,_that.roamingCarrierId,_that.roamingCarrierName,_that.roamingHomeCountry,_that.roamingProductName,_that.roamingProductKind,_that.roamingScope,_that.roamingUnits,_that.roamingTotalUsd,_that.roamingIsEstimate,_that.roamingSourceUrl,_that.roamingPricedAsOf,_that.esimOfferId,_that.esimBundleName,_that.esimDataMb,_that.esimDurationDays,_that.esimQuantity,_that.esimUnitPriceUsd,_that.esimTotalUsd,_that.esimCoversTrip,_that.savingsUsd,_that.verdict);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _RoamQuote extends RoamQuote {
  const _RoamQuote({required this.destinationCountryCode, required this.destinationCountryName, required this.tripDays, required this.tripDataMb, this.roamingCarrierId, this.roamingCarrierName, this.roamingHomeCountry, this.roamingProductName, this.roamingProductKind, this.roamingScope, this.roamingUnits, this.roamingTotalUsd, this.roamingIsEstimate = true, this.roamingSourceUrl, this.roamingPricedAsOf, this.esimOfferId, this.esimBundleName, this.esimDataMb, this.esimDurationDays, this.esimQuantity, this.esimUnitPriceUsd, this.esimTotalUsd, this.esimCoversTrip = false, this.savingsUsd, required this.verdict}): super._();
  factory _RoamQuote.fromJson(Map<String, dynamic> json) => _$RoamQuoteFromJson(json);

@override final  String destinationCountryCode;
@override final  String destinationCountryName;
@override final  int tripDays;
@override final  int tripDataMb;
@override final  String? roamingCarrierId;
@override final  String? roamingCarrierName;
@override final  String? roamingHomeCountry;
@override final  String? roamingProductName;
/// `day_pass` | `bundle` | `payg`.
@override final  String? roamingProductKind;
/// `country` (a tariff for this destination) | `worldwide` (a zone pass).
@override final  String? roamingScope;
/// Packs needed, or days for a day pass, or megabytes for pay-as-you-go.
@override final  int? roamingUnits;
@override final  double? roamingTotalUsd;
@override@JsonKey() final  bool roamingIsEstimate;
@override final  String? roamingSourceUrl;
@override final  DateTime? roamingPricedAsOf;
@override final  String? esimOfferId;
@override final  String? esimBundleName;
@override final  int? esimDataMb;
@override final  int? esimDurationDays;
@override final  int? esimQuantity;
@override final  double? esimUnitPriceUsd;
@override final  double? esimTotalUsd;
@override@JsonKey() final  bool esimCoversTrip;
/// Positive when the eSIM is cheaper. Null unless both sides are priced
/// *and* the eSIM actually covers the trip.
@override final  double? savingsUsd;
@override final  String verdict;

/// Create a copy of RoamQuote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoamQuoteCopyWith<_RoamQuote> get copyWith => __$RoamQuoteCopyWithImpl<_RoamQuote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoamQuoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoamQuote&&(identical(other.destinationCountryCode, destinationCountryCode) || other.destinationCountryCode == destinationCountryCode)&&(identical(other.destinationCountryName, destinationCountryName) || other.destinationCountryName == destinationCountryName)&&(identical(other.tripDays, tripDays) || other.tripDays == tripDays)&&(identical(other.tripDataMb, tripDataMb) || other.tripDataMb == tripDataMb)&&(identical(other.roamingCarrierId, roamingCarrierId) || other.roamingCarrierId == roamingCarrierId)&&(identical(other.roamingCarrierName, roamingCarrierName) || other.roamingCarrierName == roamingCarrierName)&&(identical(other.roamingHomeCountry, roamingHomeCountry) || other.roamingHomeCountry == roamingHomeCountry)&&(identical(other.roamingProductName, roamingProductName) || other.roamingProductName == roamingProductName)&&(identical(other.roamingProductKind, roamingProductKind) || other.roamingProductKind == roamingProductKind)&&(identical(other.roamingScope, roamingScope) || other.roamingScope == roamingScope)&&(identical(other.roamingUnits, roamingUnits) || other.roamingUnits == roamingUnits)&&(identical(other.roamingTotalUsd, roamingTotalUsd) || other.roamingTotalUsd == roamingTotalUsd)&&(identical(other.roamingIsEstimate, roamingIsEstimate) || other.roamingIsEstimate == roamingIsEstimate)&&(identical(other.roamingSourceUrl, roamingSourceUrl) || other.roamingSourceUrl == roamingSourceUrl)&&(identical(other.roamingPricedAsOf, roamingPricedAsOf) || other.roamingPricedAsOf == roamingPricedAsOf)&&(identical(other.esimOfferId, esimOfferId) || other.esimOfferId == esimOfferId)&&(identical(other.esimBundleName, esimBundleName) || other.esimBundleName == esimBundleName)&&(identical(other.esimDataMb, esimDataMb) || other.esimDataMb == esimDataMb)&&(identical(other.esimDurationDays, esimDurationDays) || other.esimDurationDays == esimDurationDays)&&(identical(other.esimQuantity, esimQuantity) || other.esimQuantity == esimQuantity)&&(identical(other.esimUnitPriceUsd, esimUnitPriceUsd) || other.esimUnitPriceUsd == esimUnitPriceUsd)&&(identical(other.esimTotalUsd, esimTotalUsd) || other.esimTotalUsd == esimTotalUsd)&&(identical(other.esimCoversTrip, esimCoversTrip) || other.esimCoversTrip == esimCoversTrip)&&(identical(other.savingsUsd, savingsUsd) || other.savingsUsd == savingsUsd)&&(identical(other.verdict, verdict) || other.verdict == verdict));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,destinationCountryCode,destinationCountryName,tripDays,tripDataMb,roamingCarrierId,roamingCarrierName,roamingHomeCountry,roamingProductName,roamingProductKind,roamingScope,roamingUnits,roamingTotalUsd,roamingIsEstimate,roamingSourceUrl,roamingPricedAsOf,esimOfferId,esimBundleName,esimDataMb,esimDurationDays,esimQuantity,esimUnitPriceUsd,esimTotalUsd,esimCoversTrip,savingsUsd,verdict]);

@override
String toString() {
  return 'RoamQuote(destinationCountryCode: $destinationCountryCode, destinationCountryName: $destinationCountryName, tripDays: $tripDays, tripDataMb: $tripDataMb, roamingCarrierId: $roamingCarrierId, roamingCarrierName: $roamingCarrierName, roamingHomeCountry: $roamingHomeCountry, roamingProductName: $roamingProductName, roamingProductKind: $roamingProductKind, roamingScope: $roamingScope, roamingUnits: $roamingUnits, roamingTotalUsd: $roamingTotalUsd, roamingIsEstimate: $roamingIsEstimate, roamingSourceUrl: $roamingSourceUrl, roamingPricedAsOf: $roamingPricedAsOf, esimOfferId: $esimOfferId, esimBundleName: $esimBundleName, esimDataMb: $esimDataMb, esimDurationDays: $esimDurationDays, esimQuantity: $esimQuantity, esimUnitPriceUsd: $esimUnitPriceUsd, esimTotalUsd: $esimTotalUsd, esimCoversTrip: $esimCoversTrip, savingsUsd: $savingsUsd, verdict: $verdict)';
}


}

/// @nodoc
abstract mixin class _$RoamQuoteCopyWith<$Res> implements $RoamQuoteCopyWith<$Res> {
  factory _$RoamQuoteCopyWith(_RoamQuote value, $Res Function(_RoamQuote) _then) = __$RoamQuoteCopyWithImpl;
@override @useResult
$Res call({
 String destinationCountryCode, String destinationCountryName, int tripDays, int tripDataMb, String? roamingCarrierId, String? roamingCarrierName, String? roamingHomeCountry, String? roamingProductName, String? roamingProductKind, String? roamingScope, int? roamingUnits, double? roamingTotalUsd, bool roamingIsEstimate, String? roamingSourceUrl, DateTime? roamingPricedAsOf, String? esimOfferId, String? esimBundleName, int? esimDataMb, int? esimDurationDays, int? esimQuantity, double? esimUnitPriceUsd, double? esimTotalUsd, bool esimCoversTrip, double? savingsUsd, String verdict
});




}
/// @nodoc
class __$RoamQuoteCopyWithImpl<$Res>
    implements _$RoamQuoteCopyWith<$Res> {
  __$RoamQuoteCopyWithImpl(this._self, this._then);

  final _RoamQuote _self;
  final $Res Function(_RoamQuote) _then;

/// Create a copy of RoamQuote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? destinationCountryCode = null,Object? destinationCountryName = null,Object? tripDays = null,Object? tripDataMb = null,Object? roamingCarrierId = freezed,Object? roamingCarrierName = freezed,Object? roamingHomeCountry = freezed,Object? roamingProductName = freezed,Object? roamingProductKind = freezed,Object? roamingScope = freezed,Object? roamingUnits = freezed,Object? roamingTotalUsd = freezed,Object? roamingIsEstimate = null,Object? roamingSourceUrl = freezed,Object? roamingPricedAsOf = freezed,Object? esimOfferId = freezed,Object? esimBundleName = freezed,Object? esimDataMb = freezed,Object? esimDurationDays = freezed,Object? esimQuantity = freezed,Object? esimUnitPriceUsd = freezed,Object? esimTotalUsd = freezed,Object? esimCoversTrip = null,Object? savingsUsd = freezed,Object? verdict = null,}) {
  return _then(_RoamQuote(
destinationCountryCode: null == destinationCountryCode ? _self.destinationCountryCode : destinationCountryCode // ignore: cast_nullable_to_non_nullable
as String,destinationCountryName: null == destinationCountryName ? _self.destinationCountryName : destinationCountryName // ignore: cast_nullable_to_non_nullable
as String,tripDays: null == tripDays ? _self.tripDays : tripDays // ignore: cast_nullable_to_non_nullable
as int,tripDataMb: null == tripDataMb ? _self.tripDataMb : tripDataMb // ignore: cast_nullable_to_non_nullable
as int,roamingCarrierId: freezed == roamingCarrierId ? _self.roamingCarrierId : roamingCarrierId // ignore: cast_nullable_to_non_nullable
as String?,roamingCarrierName: freezed == roamingCarrierName ? _self.roamingCarrierName : roamingCarrierName // ignore: cast_nullable_to_non_nullable
as String?,roamingHomeCountry: freezed == roamingHomeCountry ? _self.roamingHomeCountry : roamingHomeCountry // ignore: cast_nullable_to_non_nullable
as String?,roamingProductName: freezed == roamingProductName ? _self.roamingProductName : roamingProductName // ignore: cast_nullable_to_non_nullable
as String?,roamingProductKind: freezed == roamingProductKind ? _self.roamingProductKind : roamingProductKind // ignore: cast_nullable_to_non_nullable
as String?,roamingScope: freezed == roamingScope ? _self.roamingScope : roamingScope // ignore: cast_nullable_to_non_nullable
as String?,roamingUnits: freezed == roamingUnits ? _self.roamingUnits : roamingUnits // ignore: cast_nullable_to_non_nullable
as int?,roamingTotalUsd: freezed == roamingTotalUsd ? _self.roamingTotalUsd : roamingTotalUsd // ignore: cast_nullable_to_non_nullable
as double?,roamingIsEstimate: null == roamingIsEstimate ? _self.roamingIsEstimate : roamingIsEstimate // ignore: cast_nullable_to_non_nullable
as bool,roamingSourceUrl: freezed == roamingSourceUrl ? _self.roamingSourceUrl : roamingSourceUrl // ignore: cast_nullable_to_non_nullable
as String?,roamingPricedAsOf: freezed == roamingPricedAsOf ? _self.roamingPricedAsOf : roamingPricedAsOf // ignore: cast_nullable_to_non_nullable
as DateTime?,esimOfferId: freezed == esimOfferId ? _self.esimOfferId : esimOfferId // ignore: cast_nullable_to_non_nullable
as String?,esimBundleName: freezed == esimBundleName ? _self.esimBundleName : esimBundleName // ignore: cast_nullable_to_non_nullable
as String?,esimDataMb: freezed == esimDataMb ? _self.esimDataMb : esimDataMb // ignore: cast_nullable_to_non_nullable
as int?,esimDurationDays: freezed == esimDurationDays ? _self.esimDurationDays : esimDurationDays // ignore: cast_nullable_to_non_nullable
as int?,esimQuantity: freezed == esimQuantity ? _self.esimQuantity : esimQuantity // ignore: cast_nullable_to_non_nullable
as int?,esimUnitPriceUsd: freezed == esimUnitPriceUsd ? _self.esimUnitPriceUsd : esimUnitPriceUsd // ignore: cast_nullable_to_non_nullable
as double?,esimTotalUsd: freezed == esimTotalUsd ? _self.esimTotalUsd : esimTotalUsd // ignore: cast_nullable_to_non_nullable
as double?,esimCoversTrip: null == esimCoversTrip ? _self.esimCoversTrip : esimCoversTrip // ignore: cast_nullable_to_non_nullable
as bool,savingsUsd: freezed == savingsUsd ? _self.savingsUsd : savingsUsd // ignore: cast_nullable_to_non_nullable
as double?,verdict: null == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RoamCarrierOption {

 String get carrierId; String get carrierName; String get homeIso; String get homeCountry; bool get isHome; bool get hasRate; int get productCount;
/// Create a copy of RoamCarrierOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoamCarrierOptionCopyWith<RoamCarrierOption> get copyWith => _$RoamCarrierOptionCopyWithImpl<RoamCarrierOption>(this as RoamCarrierOption, _$identity);

  /// Serializes this RoamCarrierOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoamCarrierOption&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierName, carrierName) || other.carrierName == carrierName)&&(identical(other.homeIso, homeIso) || other.homeIso == homeIso)&&(identical(other.homeCountry, homeCountry) || other.homeCountry == homeCountry)&&(identical(other.isHome, isHome) || other.isHome == isHome)&&(identical(other.hasRate, hasRate) || other.hasRate == hasRate)&&(identical(other.productCount, productCount) || other.productCount == productCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,carrierId,carrierName,homeIso,homeCountry,isHome,hasRate,productCount);

@override
String toString() {
  return 'RoamCarrierOption(carrierId: $carrierId, carrierName: $carrierName, homeIso: $homeIso, homeCountry: $homeCountry, isHome: $isHome, hasRate: $hasRate, productCount: $productCount)';
}


}

/// @nodoc
abstract mixin class $RoamCarrierOptionCopyWith<$Res>  {
  factory $RoamCarrierOptionCopyWith(RoamCarrierOption value, $Res Function(RoamCarrierOption) _then) = _$RoamCarrierOptionCopyWithImpl;
@useResult
$Res call({
 String carrierId, String carrierName, String homeIso, String homeCountry, bool isHome, bool hasRate, int productCount
});




}
/// @nodoc
class _$RoamCarrierOptionCopyWithImpl<$Res>
    implements $RoamCarrierOptionCopyWith<$Res> {
  _$RoamCarrierOptionCopyWithImpl(this._self, this._then);

  final RoamCarrierOption _self;
  final $Res Function(RoamCarrierOption) _then;

/// Create a copy of RoamCarrierOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? carrierId = null,Object? carrierName = null,Object? homeIso = null,Object? homeCountry = null,Object? isHome = null,Object? hasRate = null,Object? productCount = null,}) {
  return _then(_self.copyWith(
carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,carrierName: null == carrierName ? _self.carrierName : carrierName // ignore: cast_nullable_to_non_nullable
as String,homeIso: null == homeIso ? _self.homeIso : homeIso // ignore: cast_nullable_to_non_nullable
as String,homeCountry: null == homeCountry ? _self.homeCountry : homeCountry // ignore: cast_nullable_to_non_nullable
as String,isHome: null == isHome ? _self.isHome : isHome // ignore: cast_nullable_to_non_nullable
as bool,hasRate: null == hasRate ? _self.hasRate : hasRate // ignore: cast_nullable_to_non_nullable
as bool,productCount: null == productCount ? _self.productCount : productCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoamCarrierOption].
extension RoamCarrierOptionPatterns on RoamCarrierOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoamCarrierOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoamCarrierOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoamCarrierOption value)  $default,){
final _that = this;
switch (_that) {
case _RoamCarrierOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoamCarrierOption value)?  $default,){
final _that = this;
switch (_that) {
case _RoamCarrierOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String carrierId,  String carrierName,  String homeIso,  String homeCountry,  bool isHome,  bool hasRate,  int productCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoamCarrierOption() when $default != null:
return $default(_that.carrierId,_that.carrierName,_that.homeIso,_that.homeCountry,_that.isHome,_that.hasRate,_that.productCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String carrierId,  String carrierName,  String homeIso,  String homeCountry,  bool isHome,  bool hasRate,  int productCount)  $default,) {final _that = this;
switch (_that) {
case _RoamCarrierOption():
return $default(_that.carrierId,_that.carrierName,_that.homeIso,_that.homeCountry,_that.isHome,_that.hasRate,_that.productCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String carrierId,  String carrierName,  String homeIso,  String homeCountry,  bool isHome,  bool hasRate,  int productCount)?  $default,) {final _that = this;
switch (_that) {
case _RoamCarrierOption() when $default != null:
return $default(_that.carrierId,_that.carrierName,_that.homeIso,_that.homeCountry,_that.isHome,_that.hasRate,_that.productCount);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _RoamCarrierOption extends RoamCarrierOption {
  const _RoamCarrierOption({required this.carrierId, required this.carrierName, required this.homeIso, required this.homeCountry, this.isHome = false, this.hasRate = false, this.productCount = 0}): super._();
  factory _RoamCarrierOption.fromJson(Map<String, dynamic> json) => _$RoamCarrierOptionFromJson(json);

@override final  String carrierId;
@override final  String carrierName;
@override final  String homeIso;
@override final  String homeCountry;
@override@JsonKey() final  bool isHome;
@override@JsonKey() final  bool hasRate;
@override@JsonKey() final  int productCount;

/// Create a copy of RoamCarrierOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoamCarrierOptionCopyWith<_RoamCarrierOption> get copyWith => __$RoamCarrierOptionCopyWithImpl<_RoamCarrierOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoamCarrierOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoamCarrierOption&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierName, carrierName) || other.carrierName == carrierName)&&(identical(other.homeIso, homeIso) || other.homeIso == homeIso)&&(identical(other.homeCountry, homeCountry) || other.homeCountry == homeCountry)&&(identical(other.isHome, isHome) || other.isHome == isHome)&&(identical(other.hasRate, hasRate) || other.hasRate == hasRate)&&(identical(other.productCount, productCount) || other.productCount == productCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,carrierId,carrierName,homeIso,homeCountry,isHome,hasRate,productCount);

@override
String toString() {
  return 'RoamCarrierOption(carrierId: $carrierId, carrierName: $carrierName, homeIso: $homeIso, homeCountry: $homeCountry, isHome: $isHome, hasRate: $hasRate, productCount: $productCount)';
}


}

/// @nodoc
abstract mixin class _$RoamCarrierOptionCopyWith<$Res> implements $RoamCarrierOptionCopyWith<$Res> {
  factory _$RoamCarrierOptionCopyWith(_RoamCarrierOption value, $Res Function(_RoamCarrierOption) _then) = __$RoamCarrierOptionCopyWithImpl;
@override @useResult
$Res call({
 String carrierId, String carrierName, String homeIso, String homeCountry, bool isHome, bool hasRate, int productCount
});




}
/// @nodoc
class __$RoamCarrierOptionCopyWithImpl<$Res>
    implements _$RoamCarrierOptionCopyWith<$Res> {
  __$RoamCarrierOptionCopyWithImpl(this._self, this._then);

  final _RoamCarrierOption _self;
  final $Res Function(_RoamCarrierOption) _then;

/// Create a copy of RoamCarrierOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? carrierId = null,Object? carrierName = null,Object? homeIso = null,Object? homeCountry = null,Object? isHome = null,Object? hasRate = null,Object? productCount = null,}) {
  return _then(_RoamCarrierOption(
carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,carrierName: null == carrierName ? _self.carrierName : carrierName // ignore: cast_nullable_to_non_nullable
as String,homeIso: null == homeIso ? _self.homeIso : homeIso // ignore: cast_nullable_to_non_nullable
as String,homeCountry: null == homeCountry ? _self.homeCountry : homeCountry // ignore: cast_nullable_to_non_nullable
as String,isHome: null == isHome ? _self.isHome : isHome // ignore: cast_nullable_to_non_nullable
as bool,hasRate: null == hasRate ? _self.hasRate : hasRate // ignore: cast_nullable_to_non_nullable
as bool,productCount: null == productCount ? _self.productCount : productCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
