// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'alert_setting_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AlertSetting {

 String get id;@JsonKey(name: 'user_id') String get userId; String get category;@JsonKey(name: 'is_enabled') bool get isEnabled; List<String> get channels;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of AlertSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertSettingCopyWith<AlertSetting> get copyWith => _$AlertSettingCopyWithImpl<AlertSetting>(this as AlertSetting, _$identity);

  /// Serializes this AlertSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.category, category) || other.category == category)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&const DeepCollectionEquality().equals(other.channels, channels)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,category,isEnabled,const DeepCollectionEquality().hash(channels),createdAt);

@override
String toString() {
  return 'AlertSetting(id: $id, userId: $userId, category: $category, isEnabled: $isEnabled, channels: $channels, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AlertSettingCopyWith<$Res>  {
  factory $AlertSettingCopyWith(AlertSetting value, $Res Function(AlertSetting) _then) = _$AlertSettingCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String category,@JsonKey(name: 'is_enabled') bool isEnabled, List<String> channels,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$AlertSettingCopyWithImpl<$Res>
    implements $AlertSettingCopyWith<$Res> {
  _$AlertSettingCopyWithImpl(this._self, this._then);

  final AlertSetting _self;
  final $Res Function(AlertSetting) _then;

/// Create a copy of AlertSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? category = null,Object? isEnabled = null,Object? channels = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AlertSetting].
extension AlertSettingPatterns on AlertSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertSetting value)  $default,){
final _that = this;
switch (_that) {
case _AlertSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertSetting value)?  $default,){
final _that = this;
switch (_that) {
case _AlertSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String category, @JsonKey(name: 'is_enabled')  bool isEnabled,  List<String> channels, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertSetting() when $default != null:
return $default(_that.id,_that.userId,_that.category,_that.isEnabled,_that.channels,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String category, @JsonKey(name: 'is_enabled')  bool isEnabled,  List<String> channels, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _AlertSetting():
return $default(_that.id,_that.userId,_that.category,_that.isEnabled,_that.channels,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  String category, @JsonKey(name: 'is_enabled')  bool isEnabled,  List<String> channels, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AlertSetting() when $default != null:
return $default(_that.id,_that.userId,_that.category,_that.isEnabled,_that.channels,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlertSetting implements AlertSetting {
  const _AlertSetting({required this.id, @JsonKey(name: 'user_id') required this.userId, required this.category, @JsonKey(name: 'is_enabled') this.isEnabled = true, final  List<String> channels = const ['push'], @JsonKey(name: 'created_at') this.createdAt}): _channels = channels;
  factory _AlertSetting.fromJson(Map<String, dynamic> json) => _$AlertSettingFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String category;
@override@JsonKey(name: 'is_enabled') final  bool isEnabled;
 final  List<String> _channels;
@override@JsonKey() List<String> get channels {
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_channels);
}

@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of AlertSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertSettingCopyWith<_AlertSetting> get copyWith => __$AlertSettingCopyWithImpl<_AlertSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlertSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.category, category) || other.category == category)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&const DeepCollectionEquality().equals(other._channels, _channels)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,category,isEnabled,const DeepCollectionEquality().hash(_channels),createdAt);

@override
String toString() {
  return 'AlertSetting(id: $id, userId: $userId, category: $category, isEnabled: $isEnabled, channels: $channels, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AlertSettingCopyWith<$Res> implements $AlertSettingCopyWith<$Res> {
  factory _$AlertSettingCopyWith(_AlertSetting value, $Res Function(_AlertSetting) _then) = __$AlertSettingCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String category,@JsonKey(name: 'is_enabled') bool isEnabled, List<String> channels,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$AlertSettingCopyWithImpl<$Res>
    implements _$AlertSettingCopyWith<$Res> {
  __$AlertSettingCopyWithImpl(this._self, this._then);

  final _AlertSetting _self;
  final $Res Function(_AlertSetting) _then;

/// Create a copy of AlertSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? category = null,Object? isEnabled = null,Object? channels = null,Object? createdAt = freezed,}) {
  return _then(_AlertSetting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
