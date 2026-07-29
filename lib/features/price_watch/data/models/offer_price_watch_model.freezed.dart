// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offer_price_watch_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OfferPriceWatch {

 String get id; String get userId;/// `topup` (a country + carrier) or `esim` (a country).
 String get source; String get countryCode; String? get carrierCode; String get origin; bool get isActive;/// null means "use the server default", currently 10%.
 double? get thresholdPercent;/// The best price we can currently see. For `esim` this is RETAIL $/GB —
/// wholesale never leaves the database. For `topup` it is the USD price of
/// the offer that moved most.
 double? get lastBestUsd; double? get lastBaselineUsd; double? get lastAlertedBestUsd; DateTime? get lastAlertAt; DateTime? get lastCheckedAt; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of OfferPriceWatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfferPriceWatchCopyWith<OfferPriceWatch> get copyWith => _$OfferPriceWatchCopyWithImpl<OfferPriceWatch>(this as OfferPriceWatch, _$identity);

  /// Serializes this OfferPriceWatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OfferPriceWatch&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.source, source) || other.source == source)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.carrierCode, carrierCode) || other.carrierCode == carrierCode)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.thresholdPercent, thresholdPercent) || other.thresholdPercent == thresholdPercent)&&(identical(other.lastBestUsd, lastBestUsd) || other.lastBestUsd == lastBestUsd)&&(identical(other.lastBaselineUsd, lastBaselineUsd) || other.lastBaselineUsd == lastBaselineUsd)&&(identical(other.lastAlertedBestUsd, lastAlertedBestUsd) || other.lastAlertedBestUsd == lastAlertedBestUsd)&&(identical(other.lastAlertAt, lastAlertAt) || other.lastAlertAt == lastAlertAt)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,source,countryCode,carrierCode,origin,isActive,thresholdPercent,lastBestUsd,lastBaselineUsd,lastAlertedBestUsd,lastAlertAt,lastCheckedAt,createdAt,updatedAt);

@override
String toString() {
  return 'OfferPriceWatch(id: $id, userId: $userId, source: $source, countryCode: $countryCode, carrierCode: $carrierCode, origin: $origin, isActive: $isActive, thresholdPercent: $thresholdPercent, lastBestUsd: $lastBestUsd, lastBaselineUsd: $lastBaselineUsd, lastAlertedBestUsd: $lastAlertedBestUsd, lastAlertAt: $lastAlertAt, lastCheckedAt: $lastCheckedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OfferPriceWatchCopyWith<$Res>  {
  factory $OfferPriceWatchCopyWith(OfferPriceWatch value, $Res Function(OfferPriceWatch) _then) = _$OfferPriceWatchCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String source, String countryCode, String? carrierCode, String origin, bool isActive, double? thresholdPercent, double? lastBestUsd, double? lastBaselineUsd, double? lastAlertedBestUsd, DateTime? lastAlertAt, DateTime? lastCheckedAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$OfferPriceWatchCopyWithImpl<$Res>
    implements $OfferPriceWatchCopyWith<$Res> {
  _$OfferPriceWatchCopyWithImpl(this._self, this._then);

  final OfferPriceWatch _self;
  final $Res Function(OfferPriceWatch) _then;

/// Create a copy of OfferPriceWatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? source = null,Object? countryCode = null,Object? carrierCode = freezed,Object? origin = null,Object? isActive = null,Object? thresholdPercent = freezed,Object? lastBestUsd = freezed,Object? lastBaselineUsd = freezed,Object? lastAlertedBestUsd = freezed,Object? lastAlertAt = freezed,Object? lastCheckedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,carrierCode: freezed == carrierCode ? _self.carrierCode : carrierCode // ignore: cast_nullable_to_non_nullable
as String?,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,thresholdPercent: freezed == thresholdPercent ? _self.thresholdPercent : thresholdPercent // ignore: cast_nullable_to_non_nullable
as double?,lastBestUsd: freezed == lastBestUsd ? _self.lastBestUsd : lastBestUsd // ignore: cast_nullable_to_non_nullable
as double?,lastBaselineUsd: freezed == lastBaselineUsd ? _self.lastBaselineUsd : lastBaselineUsd // ignore: cast_nullable_to_non_nullable
as double?,lastAlertedBestUsd: freezed == lastAlertedBestUsd ? _self.lastAlertedBestUsd : lastAlertedBestUsd // ignore: cast_nullable_to_non_nullable
as double?,lastAlertAt: freezed == lastAlertAt ? _self.lastAlertAt : lastAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastCheckedAt: freezed == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OfferPriceWatch].
extension OfferPriceWatchPatterns on OfferPriceWatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OfferPriceWatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OfferPriceWatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OfferPriceWatch value)  $default,){
final _that = this;
switch (_that) {
case _OfferPriceWatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OfferPriceWatch value)?  $default,){
final _that = this;
switch (_that) {
case _OfferPriceWatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String source,  String countryCode,  String? carrierCode,  String origin,  bool isActive,  double? thresholdPercent,  double? lastBestUsd,  double? lastBaselineUsd,  double? lastAlertedBestUsd,  DateTime? lastAlertAt,  DateTime? lastCheckedAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OfferPriceWatch() when $default != null:
return $default(_that.id,_that.userId,_that.source,_that.countryCode,_that.carrierCode,_that.origin,_that.isActive,_that.thresholdPercent,_that.lastBestUsd,_that.lastBaselineUsd,_that.lastAlertedBestUsd,_that.lastAlertAt,_that.lastCheckedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String source,  String countryCode,  String? carrierCode,  String origin,  bool isActive,  double? thresholdPercent,  double? lastBestUsd,  double? lastBaselineUsd,  double? lastAlertedBestUsd,  DateTime? lastAlertAt,  DateTime? lastCheckedAt,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OfferPriceWatch():
return $default(_that.id,_that.userId,_that.source,_that.countryCode,_that.carrierCode,_that.origin,_that.isActive,_that.thresholdPercent,_that.lastBestUsd,_that.lastBaselineUsd,_that.lastAlertedBestUsd,_that.lastAlertAt,_that.lastCheckedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String source,  String countryCode,  String? carrierCode,  String origin,  bool isActive,  double? thresholdPercent,  double? lastBestUsd,  double? lastBaselineUsd,  double? lastAlertedBestUsd,  DateTime? lastAlertAt,  DateTime? lastCheckedAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OfferPriceWatch() when $default != null:
return $default(_that.id,_that.userId,_that.source,_that.countryCode,_that.carrierCode,_that.origin,_that.isActive,_that.thresholdPercent,_that.lastBestUsd,_that.lastBaselineUsd,_that.lastAlertedBestUsd,_that.lastAlertAt,_that.lastCheckedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _OfferPriceWatch extends OfferPriceWatch {
  const _OfferPriceWatch({required this.id, required this.userId, required this.source, required this.countryCode, this.carrierCode, this.origin = 'user', this.isActive = true, this.thresholdPercent, this.lastBestUsd, this.lastBaselineUsd, this.lastAlertedBestUsd, this.lastAlertAt, this.lastCheckedAt, this.createdAt, this.updatedAt}): super._();
  factory _OfferPriceWatch.fromJson(Map<String, dynamic> json) => _$OfferPriceWatchFromJson(json);

@override final  String id;
@override final  String userId;
/// `topup` (a country + carrier) or `esim` (a country).
@override final  String source;
@override final  String countryCode;
@override final  String? carrierCode;
@override@JsonKey() final  String origin;
@override@JsonKey() final  bool isActive;
/// null means "use the server default", currently 10%.
@override final  double? thresholdPercent;
/// The best price we can currently see. For `esim` this is RETAIL $/GB —
/// wholesale never leaves the database. For `topup` it is the USD price of
/// the offer that moved most.
@override final  double? lastBestUsd;
@override final  double? lastBaselineUsd;
@override final  double? lastAlertedBestUsd;
@override final  DateTime? lastAlertAt;
@override final  DateTime? lastCheckedAt;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of OfferPriceWatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfferPriceWatchCopyWith<_OfferPriceWatch> get copyWith => __$OfferPriceWatchCopyWithImpl<_OfferPriceWatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OfferPriceWatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OfferPriceWatch&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.source, source) || other.source == source)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.carrierCode, carrierCode) || other.carrierCode == carrierCode)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.thresholdPercent, thresholdPercent) || other.thresholdPercent == thresholdPercent)&&(identical(other.lastBestUsd, lastBestUsd) || other.lastBestUsd == lastBestUsd)&&(identical(other.lastBaselineUsd, lastBaselineUsd) || other.lastBaselineUsd == lastBaselineUsd)&&(identical(other.lastAlertedBestUsd, lastAlertedBestUsd) || other.lastAlertedBestUsd == lastAlertedBestUsd)&&(identical(other.lastAlertAt, lastAlertAt) || other.lastAlertAt == lastAlertAt)&&(identical(other.lastCheckedAt, lastCheckedAt) || other.lastCheckedAt == lastCheckedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,source,countryCode,carrierCode,origin,isActive,thresholdPercent,lastBestUsd,lastBaselineUsd,lastAlertedBestUsd,lastAlertAt,lastCheckedAt,createdAt,updatedAt);

@override
String toString() {
  return 'OfferPriceWatch(id: $id, userId: $userId, source: $source, countryCode: $countryCode, carrierCode: $carrierCode, origin: $origin, isActive: $isActive, thresholdPercent: $thresholdPercent, lastBestUsd: $lastBestUsd, lastBaselineUsd: $lastBaselineUsd, lastAlertedBestUsd: $lastAlertedBestUsd, lastAlertAt: $lastAlertAt, lastCheckedAt: $lastCheckedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OfferPriceWatchCopyWith<$Res> implements $OfferPriceWatchCopyWith<$Res> {
  factory _$OfferPriceWatchCopyWith(_OfferPriceWatch value, $Res Function(_OfferPriceWatch) _then) = __$OfferPriceWatchCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String source, String countryCode, String? carrierCode, String origin, bool isActive, double? thresholdPercent, double? lastBestUsd, double? lastBaselineUsd, double? lastAlertedBestUsd, DateTime? lastAlertAt, DateTime? lastCheckedAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$OfferPriceWatchCopyWithImpl<$Res>
    implements _$OfferPriceWatchCopyWith<$Res> {
  __$OfferPriceWatchCopyWithImpl(this._self, this._then);

  final _OfferPriceWatch _self;
  final $Res Function(_OfferPriceWatch) _then;

/// Create a copy of OfferPriceWatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? source = null,Object? countryCode = null,Object? carrierCode = freezed,Object? origin = null,Object? isActive = null,Object? thresholdPercent = freezed,Object? lastBestUsd = freezed,Object? lastBaselineUsd = freezed,Object? lastAlertedBestUsd = freezed,Object? lastAlertAt = freezed,Object? lastCheckedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_OfferPriceWatch(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,carrierCode: freezed == carrierCode ? _self.carrierCode : carrierCode // ignore: cast_nullable_to_non_nullable
as String?,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,thresholdPercent: freezed == thresholdPercent ? _self.thresholdPercent : thresholdPercent // ignore: cast_nullable_to_non_nullable
as double?,lastBestUsd: freezed == lastBestUsd ? _self.lastBestUsd : lastBestUsd // ignore: cast_nullable_to_non_nullable
as double?,lastBaselineUsd: freezed == lastBaselineUsd ? _self.lastBaselineUsd : lastBaselineUsd // ignore: cast_nullable_to_non_nullable
as double?,lastAlertedBestUsd: freezed == lastAlertedBestUsd ? _self.lastAlertedBestUsd : lastAlertedBestUsd // ignore: cast_nullable_to_non_nullable
as double?,lastAlertAt: freezed == lastAlertAt ? _self.lastAlertAt : lastAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastCheckedAt: freezed == lastCheckedAt ? _self.lastCheckedAt : lastCheckedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
