// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_alarm_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceAlarmStatus {

 bool get supported; bool get enabled; bool get exactAlarmAllowed; bool get notificationsAllowed; int get scheduledCount; String get timeZone; int get alarmHour; int get alarmMinute;
/// Create a copy of DeviceAlarmStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceAlarmStatusCopyWith<DeviceAlarmStatus> get copyWith => _$DeviceAlarmStatusCopyWithImpl<DeviceAlarmStatus>(this as DeviceAlarmStatus, _$identity);

  /// Serializes this DeviceAlarmStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceAlarmStatus&&(identical(other.supported, supported) || other.supported == supported)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.exactAlarmAllowed, exactAlarmAllowed) || other.exactAlarmAllowed == exactAlarmAllowed)&&(identical(other.notificationsAllowed, notificationsAllowed) || other.notificationsAllowed == notificationsAllowed)&&(identical(other.scheduledCount, scheduledCount) || other.scheduledCount == scheduledCount)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.alarmHour, alarmHour) || other.alarmHour == alarmHour)&&(identical(other.alarmMinute, alarmMinute) || other.alarmMinute == alarmMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supported,enabled,exactAlarmAllowed,notificationsAllowed,scheduledCount,timeZone,alarmHour,alarmMinute);

@override
String toString() {
  return 'DeviceAlarmStatus(supported: $supported, enabled: $enabled, exactAlarmAllowed: $exactAlarmAllowed, notificationsAllowed: $notificationsAllowed, scheduledCount: $scheduledCount, timeZone: $timeZone, alarmHour: $alarmHour, alarmMinute: $alarmMinute)';
}


}

/// @nodoc
abstract mixin class $DeviceAlarmStatusCopyWith<$Res>  {
  factory $DeviceAlarmStatusCopyWith(DeviceAlarmStatus value, $Res Function(DeviceAlarmStatus) _then) = _$DeviceAlarmStatusCopyWithImpl;
@useResult
$Res call({
 bool supported, bool enabled, bool exactAlarmAllowed, bool notificationsAllowed, int scheduledCount, String timeZone, int alarmHour, int alarmMinute
});




}
/// @nodoc
class _$DeviceAlarmStatusCopyWithImpl<$Res>
    implements $DeviceAlarmStatusCopyWith<$Res> {
  _$DeviceAlarmStatusCopyWithImpl(this._self, this._then);

  final DeviceAlarmStatus _self;
  final $Res Function(DeviceAlarmStatus) _then;

/// Create a copy of DeviceAlarmStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supported = null,Object? enabled = null,Object? exactAlarmAllowed = null,Object? notificationsAllowed = null,Object? scheduledCount = null,Object? timeZone = null,Object? alarmHour = null,Object? alarmMinute = null,}) {
  return _then(_self.copyWith(
supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,exactAlarmAllowed: null == exactAlarmAllowed ? _self.exactAlarmAllowed : exactAlarmAllowed // ignore: cast_nullable_to_non_nullable
as bool,notificationsAllowed: null == notificationsAllowed ? _self.notificationsAllowed : notificationsAllowed // ignore: cast_nullable_to_non_nullable
as bool,scheduledCount: null == scheduledCount ? _self.scheduledCount : scheduledCount // ignore: cast_nullable_to_non_nullable
as int,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,alarmHour: null == alarmHour ? _self.alarmHour : alarmHour // ignore: cast_nullable_to_non_nullable
as int,alarmMinute: null == alarmMinute ? _self.alarmMinute : alarmMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceAlarmStatus].
extension DeviceAlarmStatusPatterns on DeviceAlarmStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceAlarmStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceAlarmStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceAlarmStatus value)  $default,){
final _that = this;
switch (_that) {
case _DeviceAlarmStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceAlarmStatus value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceAlarmStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool supported,  bool enabled,  bool exactAlarmAllowed,  bool notificationsAllowed,  int scheduledCount,  String timeZone,  int alarmHour,  int alarmMinute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceAlarmStatus() when $default != null:
return $default(_that.supported,_that.enabled,_that.exactAlarmAllowed,_that.notificationsAllowed,_that.scheduledCount,_that.timeZone,_that.alarmHour,_that.alarmMinute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool supported,  bool enabled,  bool exactAlarmAllowed,  bool notificationsAllowed,  int scheduledCount,  String timeZone,  int alarmHour,  int alarmMinute)  $default,) {final _that = this;
switch (_that) {
case _DeviceAlarmStatus():
return $default(_that.supported,_that.enabled,_that.exactAlarmAllowed,_that.notificationsAllowed,_that.scheduledCount,_that.timeZone,_that.alarmHour,_that.alarmMinute);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool supported,  bool enabled,  bool exactAlarmAllowed,  bool notificationsAllowed,  int scheduledCount,  String timeZone,  int alarmHour,  int alarmMinute)?  $default,) {final _that = this;
switch (_that) {
case _DeviceAlarmStatus() when $default != null:
return $default(_that.supported,_that.enabled,_that.exactAlarmAllowed,_that.notificationsAllowed,_that.scheduledCount,_that.timeZone,_that.alarmHour,_that.alarmMinute);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceAlarmStatus implements DeviceAlarmStatus {
  const _DeviceAlarmStatus({this.supported = false, this.enabled = false, this.exactAlarmAllowed = false, this.notificationsAllowed = false, this.scheduledCount = 0, this.timeZone = '', this.alarmHour = 18, this.alarmMinute = 0});
  factory _DeviceAlarmStatus.fromJson(Map<String, dynamic> json) => _$DeviceAlarmStatusFromJson(json);

@override@JsonKey() final  bool supported;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool exactAlarmAllowed;
@override@JsonKey() final  bool notificationsAllowed;
@override@JsonKey() final  int scheduledCount;
@override@JsonKey() final  String timeZone;
@override@JsonKey() final  int alarmHour;
@override@JsonKey() final  int alarmMinute;

/// Create a copy of DeviceAlarmStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceAlarmStatusCopyWith<_DeviceAlarmStatus> get copyWith => __$DeviceAlarmStatusCopyWithImpl<_DeviceAlarmStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceAlarmStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceAlarmStatus&&(identical(other.supported, supported) || other.supported == supported)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.exactAlarmAllowed, exactAlarmAllowed) || other.exactAlarmAllowed == exactAlarmAllowed)&&(identical(other.notificationsAllowed, notificationsAllowed) || other.notificationsAllowed == notificationsAllowed)&&(identical(other.scheduledCount, scheduledCount) || other.scheduledCount == scheduledCount)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.alarmHour, alarmHour) || other.alarmHour == alarmHour)&&(identical(other.alarmMinute, alarmMinute) || other.alarmMinute == alarmMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,supported,enabled,exactAlarmAllowed,notificationsAllowed,scheduledCount,timeZone,alarmHour,alarmMinute);

@override
String toString() {
  return 'DeviceAlarmStatus(supported: $supported, enabled: $enabled, exactAlarmAllowed: $exactAlarmAllowed, notificationsAllowed: $notificationsAllowed, scheduledCount: $scheduledCount, timeZone: $timeZone, alarmHour: $alarmHour, alarmMinute: $alarmMinute)';
}


}

/// @nodoc
abstract mixin class _$DeviceAlarmStatusCopyWith<$Res> implements $DeviceAlarmStatusCopyWith<$Res> {
  factory _$DeviceAlarmStatusCopyWith(_DeviceAlarmStatus value, $Res Function(_DeviceAlarmStatus) _then) = __$DeviceAlarmStatusCopyWithImpl;
@override @useResult
$Res call({
 bool supported, bool enabled, bool exactAlarmAllowed, bool notificationsAllowed, int scheduledCount, String timeZone, int alarmHour, int alarmMinute
});




}
/// @nodoc
class __$DeviceAlarmStatusCopyWithImpl<$Res>
    implements _$DeviceAlarmStatusCopyWith<$Res> {
  __$DeviceAlarmStatusCopyWithImpl(this._self, this._then);

  final _DeviceAlarmStatus _self;
  final $Res Function(_DeviceAlarmStatus) _then;

/// Create a copy of DeviceAlarmStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supported = null,Object? enabled = null,Object? exactAlarmAllowed = null,Object? notificationsAllowed = null,Object? scheduledCount = null,Object? timeZone = null,Object? alarmHour = null,Object? alarmMinute = null,}) {
  return _then(_DeviceAlarmStatus(
supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,exactAlarmAllowed: null == exactAlarmAllowed ? _self.exactAlarmAllowed : exactAlarmAllowed // ignore: cast_nullable_to_non_nullable
as bool,notificationsAllowed: null == notificationsAllowed ? _self.notificationsAllowed : notificationsAllowed // ignore: cast_nullable_to_non_nullable
as bool,scheduledCount: null == scheduledCount ? _self.scheduledCount : scheduledCount // ignore: cast_nullable_to_non_nullable
as int,timeZone: null == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String,alarmHour: null == alarmHour ? _self.alarmHour : alarmHour // ignore: cast_nullable_to_non_nullable
as int,alarmMinute: null == alarmMinute ? _self.alarmMinute : alarmMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeviceAlarmSchedule {

 String get simLineId; String get cycleToken; int get cutoffMillis;
/// Create a copy of DeviceAlarmSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceAlarmScheduleCopyWith<DeviceAlarmSchedule> get copyWith => _$DeviceAlarmScheduleCopyWithImpl<DeviceAlarmSchedule>(this as DeviceAlarmSchedule, _$identity);

  /// Serializes this DeviceAlarmSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceAlarmSchedule&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.cycleToken, cycleToken) || other.cycleToken == cycleToken)&&(identical(other.cutoffMillis, cutoffMillis) || other.cutoffMillis == cutoffMillis));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,cycleToken,cutoffMillis);

@override
String toString() {
  return 'DeviceAlarmSchedule(simLineId: $simLineId, cycleToken: $cycleToken, cutoffMillis: $cutoffMillis)';
}


}

/// @nodoc
abstract mixin class $DeviceAlarmScheduleCopyWith<$Res>  {
  factory $DeviceAlarmScheduleCopyWith(DeviceAlarmSchedule value, $Res Function(DeviceAlarmSchedule) _then) = _$DeviceAlarmScheduleCopyWithImpl;
@useResult
$Res call({
 String simLineId, String cycleToken, int cutoffMillis
});




}
/// @nodoc
class _$DeviceAlarmScheduleCopyWithImpl<$Res>
    implements $DeviceAlarmScheduleCopyWith<$Res> {
  _$DeviceAlarmScheduleCopyWithImpl(this._self, this._then);

  final DeviceAlarmSchedule _self;
  final $Res Function(DeviceAlarmSchedule) _then;

/// Create a copy of DeviceAlarmSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? simLineId = null,Object? cycleToken = null,Object? cutoffMillis = null,}) {
  return _then(_self.copyWith(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,cycleToken: null == cycleToken ? _self.cycleToken : cycleToken // ignore: cast_nullable_to_non_nullable
as String,cutoffMillis: null == cutoffMillis ? _self.cutoffMillis : cutoffMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceAlarmSchedule].
extension DeviceAlarmSchedulePatterns on DeviceAlarmSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceAlarmSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceAlarmSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceAlarmSchedule value)  $default,){
final _that = this;
switch (_that) {
case _DeviceAlarmSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceAlarmSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceAlarmSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String simLineId,  String cycleToken,  int cutoffMillis)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceAlarmSchedule() when $default != null:
return $default(_that.simLineId,_that.cycleToken,_that.cutoffMillis);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String simLineId,  String cycleToken,  int cutoffMillis)  $default,) {final _that = this;
switch (_that) {
case _DeviceAlarmSchedule():
return $default(_that.simLineId,_that.cycleToken,_that.cutoffMillis);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String simLineId,  String cycleToken,  int cutoffMillis)?  $default,) {final _that = this;
switch (_that) {
case _DeviceAlarmSchedule() when $default != null:
return $default(_that.simLineId,_that.cycleToken,_that.cutoffMillis);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceAlarmSchedule implements DeviceAlarmSchedule {
  const _DeviceAlarmSchedule({required this.simLineId, required this.cycleToken, required this.cutoffMillis});
  factory _DeviceAlarmSchedule.fromJson(Map<String, dynamic> json) => _$DeviceAlarmScheduleFromJson(json);

@override final  String simLineId;
@override final  String cycleToken;
@override final  int cutoffMillis;

/// Create a copy of DeviceAlarmSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceAlarmScheduleCopyWith<_DeviceAlarmSchedule> get copyWith => __$DeviceAlarmScheduleCopyWithImpl<_DeviceAlarmSchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceAlarmScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceAlarmSchedule&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.cycleToken, cycleToken) || other.cycleToken == cycleToken)&&(identical(other.cutoffMillis, cutoffMillis) || other.cutoffMillis == cutoffMillis));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,cycleToken,cutoffMillis);

@override
String toString() {
  return 'DeviceAlarmSchedule(simLineId: $simLineId, cycleToken: $cycleToken, cutoffMillis: $cutoffMillis)';
}


}

/// @nodoc
abstract mixin class _$DeviceAlarmScheduleCopyWith<$Res> implements $DeviceAlarmScheduleCopyWith<$Res> {
  factory _$DeviceAlarmScheduleCopyWith(_DeviceAlarmSchedule value, $Res Function(_DeviceAlarmSchedule) _then) = __$DeviceAlarmScheduleCopyWithImpl;
@override @useResult
$Res call({
 String simLineId, String cycleToken, int cutoffMillis
});




}
/// @nodoc
class __$DeviceAlarmScheduleCopyWithImpl<$Res>
    implements _$DeviceAlarmScheduleCopyWith<$Res> {
  __$DeviceAlarmScheduleCopyWithImpl(this._self, this._then);

  final _DeviceAlarmSchedule _self;
  final $Res Function(_DeviceAlarmSchedule) _then;

/// Create a copy of DeviceAlarmSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? simLineId = null,Object? cycleToken = null,Object? cutoffMillis = null,}) {
  return _then(_DeviceAlarmSchedule(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,cycleToken: null == cycleToken ? _self.cycleToken : cycleToken // ignore: cast_nullable_to_non_nullable
as String,cutoffMillis: null == cutoffMillis ? _self.cutoffMillis : cutoffMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
