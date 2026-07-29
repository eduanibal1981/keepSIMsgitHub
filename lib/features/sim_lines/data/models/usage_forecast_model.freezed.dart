// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'usage_forecast_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UsageForecast {

 String get id; String get userId; String? get simLineId; String? get esimId; String get subjectKind; String get method; String get confidence; int get samplesCount; double? get observedIntervalDays; double? get mbPerDay; int? get effectiveValidityDays; DateTime? get predictedDepletionAt; int? get daysRemaining; int? get suggestedFrequencyDays; double? get suggestedAmountUsd; String? get suggestedOfferId; int get alertLeadDays; DateTime? get lastAlertAt; DateTime? get computedAt;
/// Create a copy of UsageForecast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageForecastCopyWith<UsageForecast> get copyWith => _$UsageForecastCopyWithImpl<UsageForecast>(this as UsageForecast, _$identity);

  /// Serializes this UsageForecast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageForecast&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.esimId, esimId) || other.esimId == esimId)&&(identical(other.subjectKind, subjectKind) || other.subjectKind == subjectKind)&&(identical(other.method, method) || other.method == method)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.samplesCount, samplesCount) || other.samplesCount == samplesCount)&&(identical(other.observedIntervalDays, observedIntervalDays) || other.observedIntervalDays == observedIntervalDays)&&(identical(other.mbPerDay, mbPerDay) || other.mbPerDay == mbPerDay)&&(identical(other.effectiveValidityDays, effectiveValidityDays) || other.effectiveValidityDays == effectiveValidityDays)&&(identical(other.predictedDepletionAt, predictedDepletionAt) || other.predictedDepletionAt == predictedDepletionAt)&&(identical(other.daysRemaining, daysRemaining) || other.daysRemaining == daysRemaining)&&(identical(other.suggestedFrequencyDays, suggestedFrequencyDays) || other.suggestedFrequencyDays == suggestedFrequencyDays)&&(identical(other.suggestedAmountUsd, suggestedAmountUsd) || other.suggestedAmountUsd == suggestedAmountUsd)&&(identical(other.suggestedOfferId, suggestedOfferId) || other.suggestedOfferId == suggestedOfferId)&&(identical(other.alertLeadDays, alertLeadDays) || other.alertLeadDays == alertLeadDays)&&(identical(other.lastAlertAt, lastAlertAt) || other.lastAlertAt == lastAlertAt)&&(identical(other.computedAt, computedAt) || other.computedAt == computedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,simLineId,esimId,subjectKind,method,confidence,samplesCount,observedIntervalDays,mbPerDay,effectiveValidityDays,predictedDepletionAt,daysRemaining,suggestedFrequencyDays,suggestedAmountUsd,suggestedOfferId,alertLeadDays,lastAlertAt,computedAt]);

@override
String toString() {
  return 'UsageForecast(id: $id, userId: $userId, simLineId: $simLineId, esimId: $esimId, subjectKind: $subjectKind, method: $method, confidence: $confidence, samplesCount: $samplesCount, observedIntervalDays: $observedIntervalDays, mbPerDay: $mbPerDay, effectiveValidityDays: $effectiveValidityDays, predictedDepletionAt: $predictedDepletionAt, daysRemaining: $daysRemaining, suggestedFrequencyDays: $suggestedFrequencyDays, suggestedAmountUsd: $suggestedAmountUsd, suggestedOfferId: $suggestedOfferId, alertLeadDays: $alertLeadDays, lastAlertAt: $lastAlertAt, computedAt: $computedAt)';
}


}

/// @nodoc
abstract mixin class $UsageForecastCopyWith<$Res>  {
  factory $UsageForecastCopyWith(UsageForecast value, $Res Function(UsageForecast) _then) = _$UsageForecastCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String? simLineId, String? esimId, String subjectKind, String method, String confidence, int samplesCount, double? observedIntervalDays, double? mbPerDay, int? effectiveValidityDays, DateTime? predictedDepletionAt, int? daysRemaining, int? suggestedFrequencyDays, double? suggestedAmountUsd, String? suggestedOfferId, int alertLeadDays, DateTime? lastAlertAt, DateTime? computedAt
});




}
/// @nodoc
class _$UsageForecastCopyWithImpl<$Res>
    implements $UsageForecastCopyWith<$Res> {
  _$UsageForecastCopyWithImpl(this._self, this._then);

  final UsageForecast _self;
  final $Res Function(UsageForecast) _then;

/// Create a copy of UsageForecast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? simLineId = freezed,Object? esimId = freezed,Object? subjectKind = null,Object? method = null,Object? confidence = null,Object? samplesCount = null,Object? observedIntervalDays = freezed,Object? mbPerDay = freezed,Object? effectiveValidityDays = freezed,Object? predictedDepletionAt = freezed,Object? daysRemaining = freezed,Object? suggestedFrequencyDays = freezed,Object? suggestedAmountUsd = freezed,Object? suggestedOfferId = freezed,Object? alertLeadDays = null,Object? lastAlertAt = freezed,Object? computedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,simLineId: freezed == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String?,esimId: freezed == esimId ? _self.esimId : esimId // ignore: cast_nullable_to_non_nullable
as String?,subjectKind: null == subjectKind ? _self.subjectKind : subjectKind // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as String,samplesCount: null == samplesCount ? _self.samplesCount : samplesCount // ignore: cast_nullable_to_non_nullable
as int,observedIntervalDays: freezed == observedIntervalDays ? _self.observedIntervalDays : observedIntervalDays // ignore: cast_nullable_to_non_nullable
as double?,mbPerDay: freezed == mbPerDay ? _self.mbPerDay : mbPerDay // ignore: cast_nullable_to_non_nullable
as double?,effectiveValidityDays: freezed == effectiveValidityDays ? _self.effectiveValidityDays : effectiveValidityDays // ignore: cast_nullable_to_non_nullable
as int?,predictedDepletionAt: freezed == predictedDepletionAt ? _self.predictedDepletionAt : predictedDepletionAt // ignore: cast_nullable_to_non_nullable
as DateTime?,daysRemaining: freezed == daysRemaining ? _self.daysRemaining : daysRemaining // ignore: cast_nullable_to_non_nullable
as int?,suggestedFrequencyDays: freezed == suggestedFrequencyDays ? _self.suggestedFrequencyDays : suggestedFrequencyDays // ignore: cast_nullable_to_non_nullable
as int?,suggestedAmountUsd: freezed == suggestedAmountUsd ? _self.suggestedAmountUsd : suggestedAmountUsd // ignore: cast_nullable_to_non_nullable
as double?,suggestedOfferId: freezed == suggestedOfferId ? _self.suggestedOfferId : suggestedOfferId // ignore: cast_nullable_to_non_nullable
as String?,alertLeadDays: null == alertLeadDays ? _self.alertLeadDays : alertLeadDays // ignore: cast_nullable_to_non_nullable
as int,lastAlertAt: freezed == lastAlertAt ? _self.lastAlertAt : lastAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,computedAt: freezed == computedAt ? _self.computedAt : computedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageForecast].
extension UsageForecastPatterns on UsageForecast {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageForecast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageForecast() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageForecast value)  $default,){
final _that = this;
switch (_that) {
case _UsageForecast():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageForecast value)?  $default,){
final _that = this;
switch (_that) {
case _UsageForecast() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String? simLineId,  String? esimId,  String subjectKind,  String method,  String confidence,  int samplesCount,  double? observedIntervalDays,  double? mbPerDay,  int? effectiveValidityDays,  DateTime? predictedDepletionAt,  int? daysRemaining,  int? suggestedFrequencyDays,  double? suggestedAmountUsd,  String? suggestedOfferId,  int alertLeadDays,  DateTime? lastAlertAt,  DateTime? computedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageForecast() when $default != null:
return $default(_that.id,_that.userId,_that.simLineId,_that.esimId,_that.subjectKind,_that.method,_that.confidence,_that.samplesCount,_that.observedIntervalDays,_that.mbPerDay,_that.effectiveValidityDays,_that.predictedDepletionAt,_that.daysRemaining,_that.suggestedFrequencyDays,_that.suggestedAmountUsd,_that.suggestedOfferId,_that.alertLeadDays,_that.lastAlertAt,_that.computedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String? simLineId,  String? esimId,  String subjectKind,  String method,  String confidence,  int samplesCount,  double? observedIntervalDays,  double? mbPerDay,  int? effectiveValidityDays,  DateTime? predictedDepletionAt,  int? daysRemaining,  int? suggestedFrequencyDays,  double? suggestedAmountUsd,  String? suggestedOfferId,  int alertLeadDays,  DateTime? lastAlertAt,  DateTime? computedAt)  $default,) {final _that = this;
switch (_that) {
case _UsageForecast():
return $default(_that.id,_that.userId,_that.simLineId,_that.esimId,_that.subjectKind,_that.method,_that.confidence,_that.samplesCount,_that.observedIntervalDays,_that.mbPerDay,_that.effectiveValidityDays,_that.predictedDepletionAt,_that.daysRemaining,_that.suggestedFrequencyDays,_that.suggestedAmountUsd,_that.suggestedOfferId,_that.alertLeadDays,_that.lastAlertAt,_that.computedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String? simLineId,  String? esimId,  String subjectKind,  String method,  String confidence,  int samplesCount,  double? observedIntervalDays,  double? mbPerDay,  int? effectiveValidityDays,  DateTime? predictedDepletionAt,  int? daysRemaining,  int? suggestedFrequencyDays,  double? suggestedAmountUsd,  String? suggestedOfferId,  int alertLeadDays,  DateTime? lastAlertAt,  DateTime? computedAt)?  $default,) {final _that = this;
switch (_that) {
case _UsageForecast() when $default != null:
return $default(_that.id,_that.userId,_that.simLineId,_that.esimId,_that.subjectKind,_that.method,_that.confidence,_that.samplesCount,_that.observedIntervalDays,_that.mbPerDay,_that.effectiveValidityDays,_that.predictedDepletionAt,_that.daysRemaining,_that.suggestedFrequencyDays,_that.suggestedAmountUsd,_that.suggestedOfferId,_that.alertLeadDays,_that.lastAlertAt,_that.computedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _UsageForecast extends UsageForecast {
  const _UsageForecast({required this.id, required this.userId, this.simLineId, this.esimId, required this.subjectKind, required this.method, required this.confidence, this.samplesCount = 0, this.observedIntervalDays, this.mbPerDay, this.effectiveValidityDays, this.predictedDepletionAt, this.daysRemaining, this.suggestedFrequencyDays, this.suggestedAmountUsd, this.suggestedOfferId, this.alertLeadDays = 7, this.lastAlertAt, this.computedAt}): super._();
  factory _UsageForecast.fromJson(Map<String, dynamic> json) => _$UsageForecastFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String? simLineId;
@override final  String? esimId;
@override final  String subjectKind;
@override final  String method;
@override final  String confidence;
@override@JsonKey() final  int samplesCount;
@override final  double? observedIntervalDays;
@override final  double? mbPerDay;
@override final  int? effectiveValidityDays;
@override final  DateTime? predictedDepletionAt;
@override final  int? daysRemaining;
@override final  int? suggestedFrequencyDays;
@override final  double? suggestedAmountUsd;
@override final  String? suggestedOfferId;
@override@JsonKey() final  int alertLeadDays;
@override final  DateTime? lastAlertAt;
@override final  DateTime? computedAt;

/// Create a copy of UsageForecast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageForecastCopyWith<_UsageForecast> get copyWith => __$UsageForecastCopyWithImpl<_UsageForecast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageForecastToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageForecast&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.esimId, esimId) || other.esimId == esimId)&&(identical(other.subjectKind, subjectKind) || other.subjectKind == subjectKind)&&(identical(other.method, method) || other.method == method)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.samplesCount, samplesCount) || other.samplesCount == samplesCount)&&(identical(other.observedIntervalDays, observedIntervalDays) || other.observedIntervalDays == observedIntervalDays)&&(identical(other.mbPerDay, mbPerDay) || other.mbPerDay == mbPerDay)&&(identical(other.effectiveValidityDays, effectiveValidityDays) || other.effectiveValidityDays == effectiveValidityDays)&&(identical(other.predictedDepletionAt, predictedDepletionAt) || other.predictedDepletionAt == predictedDepletionAt)&&(identical(other.daysRemaining, daysRemaining) || other.daysRemaining == daysRemaining)&&(identical(other.suggestedFrequencyDays, suggestedFrequencyDays) || other.suggestedFrequencyDays == suggestedFrequencyDays)&&(identical(other.suggestedAmountUsd, suggestedAmountUsd) || other.suggestedAmountUsd == suggestedAmountUsd)&&(identical(other.suggestedOfferId, suggestedOfferId) || other.suggestedOfferId == suggestedOfferId)&&(identical(other.alertLeadDays, alertLeadDays) || other.alertLeadDays == alertLeadDays)&&(identical(other.lastAlertAt, lastAlertAt) || other.lastAlertAt == lastAlertAt)&&(identical(other.computedAt, computedAt) || other.computedAt == computedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,simLineId,esimId,subjectKind,method,confidence,samplesCount,observedIntervalDays,mbPerDay,effectiveValidityDays,predictedDepletionAt,daysRemaining,suggestedFrequencyDays,suggestedAmountUsd,suggestedOfferId,alertLeadDays,lastAlertAt,computedAt]);

@override
String toString() {
  return 'UsageForecast(id: $id, userId: $userId, simLineId: $simLineId, esimId: $esimId, subjectKind: $subjectKind, method: $method, confidence: $confidence, samplesCount: $samplesCount, observedIntervalDays: $observedIntervalDays, mbPerDay: $mbPerDay, effectiveValidityDays: $effectiveValidityDays, predictedDepletionAt: $predictedDepletionAt, daysRemaining: $daysRemaining, suggestedFrequencyDays: $suggestedFrequencyDays, suggestedAmountUsd: $suggestedAmountUsd, suggestedOfferId: $suggestedOfferId, alertLeadDays: $alertLeadDays, lastAlertAt: $lastAlertAt, computedAt: $computedAt)';
}


}

/// @nodoc
abstract mixin class _$UsageForecastCopyWith<$Res> implements $UsageForecastCopyWith<$Res> {
  factory _$UsageForecastCopyWith(_UsageForecast value, $Res Function(_UsageForecast) _then) = __$UsageForecastCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String? simLineId, String? esimId, String subjectKind, String method, String confidence, int samplesCount, double? observedIntervalDays, double? mbPerDay, int? effectiveValidityDays, DateTime? predictedDepletionAt, int? daysRemaining, int? suggestedFrequencyDays, double? suggestedAmountUsd, String? suggestedOfferId, int alertLeadDays, DateTime? lastAlertAt, DateTime? computedAt
});




}
/// @nodoc
class __$UsageForecastCopyWithImpl<$Res>
    implements _$UsageForecastCopyWith<$Res> {
  __$UsageForecastCopyWithImpl(this._self, this._then);

  final _UsageForecast _self;
  final $Res Function(_UsageForecast) _then;

/// Create a copy of UsageForecast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? simLineId = freezed,Object? esimId = freezed,Object? subjectKind = null,Object? method = null,Object? confidence = null,Object? samplesCount = null,Object? observedIntervalDays = freezed,Object? mbPerDay = freezed,Object? effectiveValidityDays = freezed,Object? predictedDepletionAt = freezed,Object? daysRemaining = freezed,Object? suggestedFrequencyDays = freezed,Object? suggestedAmountUsd = freezed,Object? suggestedOfferId = freezed,Object? alertLeadDays = null,Object? lastAlertAt = freezed,Object? computedAt = freezed,}) {
  return _then(_UsageForecast(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,simLineId: freezed == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String?,esimId: freezed == esimId ? _self.esimId : esimId // ignore: cast_nullable_to_non_nullable
as String?,subjectKind: null == subjectKind ? _self.subjectKind : subjectKind // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as String,samplesCount: null == samplesCount ? _self.samplesCount : samplesCount // ignore: cast_nullable_to_non_nullable
as int,observedIntervalDays: freezed == observedIntervalDays ? _self.observedIntervalDays : observedIntervalDays // ignore: cast_nullable_to_non_nullable
as double?,mbPerDay: freezed == mbPerDay ? _self.mbPerDay : mbPerDay // ignore: cast_nullable_to_non_nullable
as double?,effectiveValidityDays: freezed == effectiveValidityDays ? _self.effectiveValidityDays : effectiveValidityDays // ignore: cast_nullable_to_non_nullable
as int?,predictedDepletionAt: freezed == predictedDepletionAt ? _self.predictedDepletionAt : predictedDepletionAt // ignore: cast_nullable_to_non_nullable
as DateTime?,daysRemaining: freezed == daysRemaining ? _self.daysRemaining : daysRemaining // ignore: cast_nullable_to_non_nullable
as int?,suggestedFrequencyDays: freezed == suggestedFrequencyDays ? _self.suggestedFrequencyDays : suggestedFrequencyDays // ignore: cast_nullable_to_non_nullable
as int?,suggestedAmountUsd: freezed == suggestedAmountUsd ? _self.suggestedAmountUsd : suggestedAmountUsd // ignore: cast_nullable_to_non_nullable
as double?,suggestedOfferId: freezed == suggestedOfferId ? _self.suggestedOfferId : suggestedOfferId // ignore: cast_nullable_to_non_nullable
as String?,alertLeadDays: null == alertLeadDays ? _self.alertLeadDays : alertLeadDays // ignore: cast_nullable_to_non_nullable
as int,lastAlertAt: freezed == lastAlertAt ? _self.lastAlertAt : lastAlertAt // ignore: cast_nullable_to_non_nullable
as DateTime?,computedAt: freezed == computedAt ? _self.computedAt : computedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
