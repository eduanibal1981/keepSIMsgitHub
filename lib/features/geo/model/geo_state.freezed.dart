// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geo_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GeoState {

 String get currentCountry; String get currentIsoCode; bool get travelModeEnabled; bool get promptFreeze; bool get promptResume; List<String> get logs; bool get isProcessing;
/// Create a copy of GeoState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoStateCopyWith<GeoState> get copyWith => _$GeoStateCopyWithImpl<GeoState>(this as GeoState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoState&&(identical(other.currentCountry, currentCountry) || other.currentCountry == currentCountry)&&(identical(other.currentIsoCode, currentIsoCode) || other.currentIsoCode == currentIsoCode)&&(identical(other.travelModeEnabled, travelModeEnabled) || other.travelModeEnabled == travelModeEnabled)&&(identical(other.promptFreeze, promptFreeze) || other.promptFreeze == promptFreeze)&&(identical(other.promptResume, promptResume) || other.promptResume == promptResume)&&const DeepCollectionEquality().equals(other.logs, logs)&&(identical(other.isProcessing, isProcessing) || other.isProcessing == isProcessing));
}


@override
int get hashCode => Object.hash(runtimeType,currentCountry,currentIsoCode,travelModeEnabled,promptFreeze,promptResume,const DeepCollectionEquality().hash(logs),isProcessing);

@override
String toString() {
  return 'GeoState(currentCountry: $currentCountry, currentIsoCode: $currentIsoCode, travelModeEnabled: $travelModeEnabled, promptFreeze: $promptFreeze, promptResume: $promptResume, logs: $logs, isProcessing: $isProcessing)';
}


}

/// @nodoc
abstract mixin class $GeoStateCopyWith<$Res>  {
  factory $GeoStateCopyWith(GeoState value, $Res Function(GeoState) _then) = _$GeoStateCopyWithImpl;
@useResult
$Res call({
 String currentCountry, String currentIsoCode, bool travelModeEnabled, bool promptFreeze, bool promptResume, List<String> logs, bool isProcessing
});




}
/// @nodoc
class _$GeoStateCopyWithImpl<$Res>
    implements $GeoStateCopyWith<$Res> {
  _$GeoStateCopyWithImpl(this._self, this._then);

  final GeoState _self;
  final $Res Function(GeoState) _then;

/// Create a copy of GeoState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentCountry = null,Object? currentIsoCode = null,Object? travelModeEnabled = null,Object? promptFreeze = null,Object? promptResume = null,Object? logs = null,Object? isProcessing = null,}) {
  return _then(_self.copyWith(
currentCountry: null == currentCountry ? _self.currentCountry : currentCountry // ignore: cast_nullable_to_non_nullable
as String,currentIsoCode: null == currentIsoCode ? _self.currentIsoCode : currentIsoCode // ignore: cast_nullable_to_non_nullable
as String,travelModeEnabled: null == travelModeEnabled ? _self.travelModeEnabled : travelModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,promptFreeze: null == promptFreeze ? _self.promptFreeze : promptFreeze // ignore: cast_nullable_to_non_nullable
as bool,promptResume: null == promptResume ? _self.promptResume : promptResume // ignore: cast_nullable_to_non_nullable
as bool,logs: null == logs ? _self.logs : logs // ignore: cast_nullable_to_non_nullable
as List<String>,isProcessing: null == isProcessing ? _self.isProcessing : isProcessing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoState].
extension GeoStatePatterns on GeoState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoState value)  $default,){
final _that = this;
switch (_that) {
case _GeoState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoState value)?  $default,){
final _that = this;
switch (_that) {
case _GeoState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String currentCountry,  String currentIsoCode,  bool travelModeEnabled,  bool promptFreeze,  bool promptResume,  List<String> logs,  bool isProcessing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoState() when $default != null:
return $default(_that.currentCountry,_that.currentIsoCode,_that.travelModeEnabled,_that.promptFreeze,_that.promptResume,_that.logs,_that.isProcessing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String currentCountry,  String currentIsoCode,  bool travelModeEnabled,  bool promptFreeze,  bool promptResume,  List<String> logs,  bool isProcessing)  $default,) {final _that = this;
switch (_that) {
case _GeoState():
return $default(_that.currentCountry,_that.currentIsoCode,_that.travelModeEnabled,_that.promptFreeze,_that.promptResume,_that.logs,_that.isProcessing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String currentCountry,  String currentIsoCode,  bool travelModeEnabled,  bool promptFreeze,  bool promptResume,  List<String> logs,  bool isProcessing)?  $default,) {final _that = this;
switch (_that) {
case _GeoState() when $default != null:
return $default(_that.currentCountry,_that.currentIsoCode,_that.travelModeEnabled,_that.promptFreeze,_that.promptResume,_that.logs,_that.isProcessing);case _:
  return null;

}
}

}

/// @nodoc


class _GeoState implements GeoState {
  const _GeoState({required this.currentCountry, required this.currentIsoCode, this.travelModeEnabled = false, this.promptFreeze = false, this.promptResume = false, final  List<String> logs = const [], this.isProcessing = false}): _logs = logs;
  

@override final  String currentCountry;
@override final  String currentIsoCode;
@override@JsonKey() final  bool travelModeEnabled;
@override@JsonKey() final  bool promptFreeze;
@override@JsonKey() final  bool promptResume;
 final  List<String> _logs;
@override@JsonKey() List<String> get logs {
  if (_logs is EqualUnmodifiableListView) return _logs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_logs);
}

@override@JsonKey() final  bool isProcessing;

/// Create a copy of GeoState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoStateCopyWith<_GeoState> get copyWith => __$GeoStateCopyWithImpl<_GeoState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoState&&(identical(other.currentCountry, currentCountry) || other.currentCountry == currentCountry)&&(identical(other.currentIsoCode, currentIsoCode) || other.currentIsoCode == currentIsoCode)&&(identical(other.travelModeEnabled, travelModeEnabled) || other.travelModeEnabled == travelModeEnabled)&&(identical(other.promptFreeze, promptFreeze) || other.promptFreeze == promptFreeze)&&(identical(other.promptResume, promptResume) || other.promptResume == promptResume)&&const DeepCollectionEquality().equals(other._logs, _logs)&&(identical(other.isProcessing, isProcessing) || other.isProcessing == isProcessing));
}


@override
int get hashCode => Object.hash(runtimeType,currentCountry,currentIsoCode,travelModeEnabled,promptFreeze,promptResume,const DeepCollectionEquality().hash(_logs),isProcessing);

@override
String toString() {
  return 'GeoState(currentCountry: $currentCountry, currentIsoCode: $currentIsoCode, travelModeEnabled: $travelModeEnabled, promptFreeze: $promptFreeze, promptResume: $promptResume, logs: $logs, isProcessing: $isProcessing)';
}


}

/// @nodoc
abstract mixin class _$GeoStateCopyWith<$Res> implements $GeoStateCopyWith<$Res> {
  factory _$GeoStateCopyWith(_GeoState value, $Res Function(_GeoState) _then) = __$GeoStateCopyWithImpl;
@override @useResult
$Res call({
 String currentCountry, String currentIsoCode, bool travelModeEnabled, bool promptFreeze, bool promptResume, List<String> logs, bool isProcessing
});




}
/// @nodoc
class __$GeoStateCopyWithImpl<$Res>
    implements _$GeoStateCopyWith<$Res> {
  __$GeoStateCopyWithImpl(this._self, this._then);

  final _GeoState _self;
  final $Res Function(_GeoState) _then;

/// Create a copy of GeoState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentCountry = null,Object? currentIsoCode = null,Object? travelModeEnabled = null,Object? promptFreeze = null,Object? promptResume = null,Object? logs = null,Object? isProcessing = null,}) {
  return _then(_GeoState(
currentCountry: null == currentCountry ? _self.currentCountry : currentCountry // ignore: cast_nullable_to_non_nullable
as String,currentIsoCode: null == currentIsoCode ? _self.currentIsoCode : currentIsoCode // ignore: cast_nullable_to_non_nullable
as String,travelModeEnabled: null == travelModeEnabled ? _self.travelModeEnabled : travelModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,promptFreeze: null == promptFreeze ? _self.promptFreeze : promptFreeze // ignore: cast_nullable_to_non_nullable
as bool,promptResume: null == promptResume ? _self.promptResume : promptResume // ignore: cast_nullable_to_non_nullable
as bool,logs: null == logs ? _self._logs : logs // ignore: cast_nullable_to_non_nullable
as List<String>,isProcessing: null == isProcessing ? _self.isProcessing : isProcessing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
