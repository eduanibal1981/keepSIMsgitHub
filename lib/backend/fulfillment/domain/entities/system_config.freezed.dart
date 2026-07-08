// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SystemConfig {

@JsonKey(name: 'config_key') String get configKey;@JsonKey(name: 'config_value') String get configValue;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of SystemConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemConfigCopyWith<SystemConfig> get copyWith => _$SystemConfigCopyWithImpl<SystemConfig>(this as SystemConfig, _$identity);

  /// Serializes this SystemConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemConfig&&(identical(other.configKey, configKey) || other.configKey == configKey)&&(identical(other.configValue, configValue) || other.configValue == configValue)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,configKey,configValue,createdAt,updatedAt);

@override
String toString() {
  return 'SystemConfig(configKey: $configKey, configValue: $configValue, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SystemConfigCopyWith<$Res>  {
  factory $SystemConfigCopyWith(SystemConfig value, $Res Function(SystemConfig) _then) = _$SystemConfigCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'config_key') String configKey,@JsonKey(name: 'config_value') String configValue,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$SystemConfigCopyWithImpl<$Res>
    implements $SystemConfigCopyWith<$Res> {
  _$SystemConfigCopyWithImpl(this._self, this._then);

  final SystemConfig _self;
  final $Res Function(SystemConfig) _then;

/// Create a copy of SystemConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? configKey = null,Object? configValue = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
configKey: null == configKey ? _self.configKey : configKey // ignore: cast_nullable_to_non_nullable
as String,configValue: null == configValue ? _self.configValue : configValue // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemConfig].
extension SystemConfigPatterns on SystemConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemConfig value)  $default,){
final _that = this;
switch (_that) {
case _SystemConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemConfig value)?  $default,){
final _that = this;
switch (_that) {
case _SystemConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'config_key')  String configKey, @JsonKey(name: 'config_value')  String configValue, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemConfig() when $default != null:
return $default(_that.configKey,_that.configValue,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'config_key')  String configKey, @JsonKey(name: 'config_value')  String configValue, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SystemConfig():
return $default(_that.configKey,_that.configValue,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'config_key')  String configKey, @JsonKey(name: 'config_value')  String configValue, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SystemConfig() when $default != null:
return $default(_that.configKey,_that.configValue,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemConfig implements SystemConfig {
  const _SystemConfig({@JsonKey(name: 'config_key') required this.configKey, @JsonKey(name: 'config_value') required this.configValue, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _SystemConfig.fromJson(Map<String, dynamic> json) => _$SystemConfigFromJson(json);

@override@JsonKey(name: 'config_key') final  String configKey;
@override@JsonKey(name: 'config_value') final  String configValue;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of SystemConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemConfigCopyWith<_SystemConfig> get copyWith => __$SystemConfigCopyWithImpl<_SystemConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemConfig&&(identical(other.configKey, configKey) || other.configKey == configKey)&&(identical(other.configValue, configValue) || other.configValue == configValue)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,configKey,configValue,createdAt,updatedAt);

@override
String toString() {
  return 'SystemConfig(configKey: $configKey, configValue: $configValue, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SystemConfigCopyWith<$Res> implements $SystemConfigCopyWith<$Res> {
  factory _$SystemConfigCopyWith(_SystemConfig value, $Res Function(_SystemConfig) _then) = __$SystemConfigCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'config_key') String configKey,@JsonKey(name: 'config_value') String configValue,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$SystemConfigCopyWithImpl<$Res>
    implements _$SystemConfigCopyWith<$Res> {
  __$SystemConfigCopyWithImpl(this._self, this._then);

  final _SystemConfig _self;
  final $Res Function(_SystemConfig) _then;

/// Create a copy of SystemConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? configKey = null,Object? configValue = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_SystemConfig(
configKey: null == configKey ? _self.configKey : configKey // ignore: cast_nullable_to_non_nullable
as String,configValue: null == configValue ? _self.configValue : configValue // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
