// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_rescue_policy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineRescuePolicy {

 String get simLineId; String get userId;/// The most one rescue may cost. 0 = insurance off.
 double get maxUsd;/// Rescue when the forecast says this many days of life remain.
 int get leadDays;/// Warn this many days before that, giving the user a chance to act first.
 int get warnLeadDays;/// When the warning that starts the grace clock was written. Null means no
/// warning is outstanding — either none was needed, or the user acted.
 DateTime? get lastWarnedAt; DateTime? get lastRescueAt; String? get lastRescueExecutionId; int get rescueCount; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of LineRescuePolicy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineRescuePolicyCopyWith<LineRescuePolicy> get copyWith => _$LineRescuePolicyCopyWithImpl<LineRescuePolicy>(this as LineRescuePolicy, _$identity);

  /// Serializes this LineRescuePolicy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineRescuePolicy&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.maxUsd, maxUsd) || other.maxUsd == maxUsd)&&(identical(other.leadDays, leadDays) || other.leadDays == leadDays)&&(identical(other.warnLeadDays, warnLeadDays) || other.warnLeadDays == warnLeadDays)&&(identical(other.lastWarnedAt, lastWarnedAt) || other.lastWarnedAt == lastWarnedAt)&&(identical(other.lastRescueAt, lastRescueAt) || other.lastRescueAt == lastRescueAt)&&(identical(other.lastRescueExecutionId, lastRescueExecutionId) || other.lastRescueExecutionId == lastRescueExecutionId)&&(identical(other.rescueCount, rescueCount) || other.rescueCount == rescueCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,userId,maxUsd,leadDays,warnLeadDays,lastWarnedAt,lastRescueAt,lastRescueExecutionId,rescueCount,createdAt,updatedAt);

@override
String toString() {
  return 'LineRescuePolicy(simLineId: $simLineId, userId: $userId, maxUsd: $maxUsd, leadDays: $leadDays, warnLeadDays: $warnLeadDays, lastWarnedAt: $lastWarnedAt, lastRescueAt: $lastRescueAt, lastRescueExecutionId: $lastRescueExecutionId, rescueCount: $rescueCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $LineRescuePolicyCopyWith<$Res>  {
  factory $LineRescuePolicyCopyWith(LineRescuePolicy value, $Res Function(LineRescuePolicy) _then) = _$LineRescuePolicyCopyWithImpl;
@useResult
$Res call({
 String simLineId, String userId, double maxUsd, int leadDays, int warnLeadDays, DateTime? lastWarnedAt, DateTime? lastRescueAt, String? lastRescueExecutionId, int rescueCount, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$LineRescuePolicyCopyWithImpl<$Res>
    implements $LineRescuePolicyCopyWith<$Res> {
  _$LineRescuePolicyCopyWithImpl(this._self, this._then);

  final LineRescuePolicy _self;
  final $Res Function(LineRescuePolicy) _then;

/// Create a copy of LineRescuePolicy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? simLineId = null,Object? userId = null,Object? maxUsd = null,Object? leadDays = null,Object? warnLeadDays = null,Object? lastWarnedAt = freezed,Object? lastRescueAt = freezed,Object? lastRescueExecutionId = freezed,Object? rescueCount = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,maxUsd: null == maxUsd ? _self.maxUsd : maxUsd // ignore: cast_nullable_to_non_nullable
as double,leadDays: null == leadDays ? _self.leadDays : leadDays // ignore: cast_nullable_to_non_nullable
as int,warnLeadDays: null == warnLeadDays ? _self.warnLeadDays : warnLeadDays // ignore: cast_nullable_to_non_nullable
as int,lastWarnedAt: freezed == lastWarnedAt ? _self.lastWarnedAt : lastWarnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRescueAt: freezed == lastRescueAt ? _self.lastRescueAt : lastRescueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRescueExecutionId: freezed == lastRescueExecutionId ? _self.lastRescueExecutionId : lastRescueExecutionId // ignore: cast_nullable_to_non_nullable
as String?,rescueCount: null == rescueCount ? _self.rescueCount : rescueCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineRescuePolicy].
extension LineRescuePolicyPatterns on LineRescuePolicy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineRescuePolicy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineRescuePolicy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineRescuePolicy value)  $default,){
final _that = this;
switch (_that) {
case _LineRescuePolicy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineRescuePolicy value)?  $default,){
final _that = this;
switch (_that) {
case _LineRescuePolicy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String simLineId,  String userId,  double maxUsd,  int leadDays,  int warnLeadDays,  DateTime? lastWarnedAt,  DateTime? lastRescueAt,  String? lastRescueExecutionId,  int rescueCount,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineRescuePolicy() when $default != null:
return $default(_that.simLineId,_that.userId,_that.maxUsd,_that.leadDays,_that.warnLeadDays,_that.lastWarnedAt,_that.lastRescueAt,_that.lastRescueExecutionId,_that.rescueCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String simLineId,  String userId,  double maxUsd,  int leadDays,  int warnLeadDays,  DateTime? lastWarnedAt,  DateTime? lastRescueAt,  String? lastRescueExecutionId,  int rescueCount,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _LineRescuePolicy():
return $default(_that.simLineId,_that.userId,_that.maxUsd,_that.leadDays,_that.warnLeadDays,_that.lastWarnedAt,_that.lastRescueAt,_that.lastRescueExecutionId,_that.rescueCount,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String simLineId,  String userId,  double maxUsd,  int leadDays,  int warnLeadDays,  DateTime? lastWarnedAt,  DateTime? lastRescueAt,  String? lastRescueExecutionId,  int rescueCount,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _LineRescuePolicy() when $default != null:
return $default(_that.simLineId,_that.userId,_that.maxUsd,_that.leadDays,_that.warnLeadDays,_that.lastWarnedAt,_that.lastRescueAt,_that.lastRescueExecutionId,_that.rescueCount,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LineRescuePolicy extends LineRescuePolicy {
  const _LineRescuePolicy({required this.simLineId, required this.userId, this.maxUsd = 0.0, this.leadDays = 2, this.warnLeadDays = 3, this.lastWarnedAt, this.lastRescueAt, this.lastRescueExecutionId, this.rescueCount = 0, this.createdAt, this.updatedAt}): super._();
  factory _LineRescuePolicy.fromJson(Map<String, dynamic> json) => _$LineRescuePolicyFromJson(json);

@override final  String simLineId;
@override final  String userId;
/// The most one rescue may cost. 0 = insurance off.
@override@JsonKey() final  double maxUsd;
/// Rescue when the forecast says this many days of life remain.
@override@JsonKey() final  int leadDays;
/// Warn this many days before that, giving the user a chance to act first.
@override@JsonKey() final  int warnLeadDays;
/// When the warning that starts the grace clock was written. Null means no
/// warning is outstanding — either none was needed, or the user acted.
@override final  DateTime? lastWarnedAt;
@override final  DateTime? lastRescueAt;
@override final  String? lastRescueExecutionId;
@override@JsonKey() final  int rescueCount;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of LineRescuePolicy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineRescuePolicyCopyWith<_LineRescuePolicy> get copyWith => __$LineRescuePolicyCopyWithImpl<_LineRescuePolicy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineRescuePolicyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineRescuePolicy&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.maxUsd, maxUsd) || other.maxUsd == maxUsd)&&(identical(other.leadDays, leadDays) || other.leadDays == leadDays)&&(identical(other.warnLeadDays, warnLeadDays) || other.warnLeadDays == warnLeadDays)&&(identical(other.lastWarnedAt, lastWarnedAt) || other.lastWarnedAt == lastWarnedAt)&&(identical(other.lastRescueAt, lastRescueAt) || other.lastRescueAt == lastRescueAt)&&(identical(other.lastRescueExecutionId, lastRescueExecutionId) || other.lastRescueExecutionId == lastRescueExecutionId)&&(identical(other.rescueCount, rescueCount) || other.rescueCount == rescueCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,userId,maxUsd,leadDays,warnLeadDays,lastWarnedAt,lastRescueAt,lastRescueExecutionId,rescueCount,createdAt,updatedAt);

@override
String toString() {
  return 'LineRescuePolicy(simLineId: $simLineId, userId: $userId, maxUsd: $maxUsd, leadDays: $leadDays, warnLeadDays: $warnLeadDays, lastWarnedAt: $lastWarnedAt, lastRescueAt: $lastRescueAt, lastRescueExecutionId: $lastRescueExecutionId, rescueCount: $rescueCount, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$LineRescuePolicyCopyWith<$Res> implements $LineRescuePolicyCopyWith<$Res> {
  factory _$LineRescuePolicyCopyWith(_LineRescuePolicy value, $Res Function(_LineRescuePolicy) _then) = __$LineRescuePolicyCopyWithImpl;
@override @useResult
$Res call({
 String simLineId, String userId, double maxUsd, int leadDays, int warnLeadDays, DateTime? lastWarnedAt, DateTime? lastRescueAt, String? lastRescueExecutionId, int rescueCount, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$LineRescuePolicyCopyWithImpl<$Res>
    implements _$LineRescuePolicyCopyWith<$Res> {
  __$LineRescuePolicyCopyWithImpl(this._self, this._then);

  final _LineRescuePolicy _self;
  final $Res Function(_LineRescuePolicy) _then;

/// Create a copy of LineRescuePolicy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? simLineId = null,Object? userId = null,Object? maxUsd = null,Object? leadDays = null,Object? warnLeadDays = null,Object? lastWarnedAt = freezed,Object? lastRescueAt = freezed,Object? lastRescueExecutionId = freezed,Object? rescueCount = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_LineRescuePolicy(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,maxUsd: null == maxUsd ? _self.maxUsd : maxUsd // ignore: cast_nullable_to_non_nullable
as double,leadDays: null == leadDays ? _self.leadDays : leadDays // ignore: cast_nullable_to_non_nullable
as int,warnLeadDays: null == warnLeadDays ? _self.warnLeadDays : warnLeadDays // ignore: cast_nullable_to_non_nullable
as int,lastWarnedAt: freezed == lastWarnedAt ? _self.lastWarnedAt : lastWarnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRescueAt: freezed == lastRescueAt ? _self.lastRescueAt : lastRescueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRescueExecutionId: freezed == lastRescueExecutionId ? _self.lastRescueExecutionId : lastRescueExecutionId // ignore: cast_nullable_to_non_nullable
as String?,rescueCount: null == rescueCount ? _self.rescueCount : rescueCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
