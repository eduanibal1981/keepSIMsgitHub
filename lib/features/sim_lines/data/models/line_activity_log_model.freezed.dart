// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_activity_log_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineActivityLog {

 String get id; String get simLineId; String get userId; String get eventType; String? get description; Map<String, dynamic> get metadata; DateTime get createdAt;
/// Create a copy of LineActivityLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineActivityLogCopyWith<LineActivityLog> get copyWith => _$LineActivityLogCopyWithImpl<LineActivityLog>(this as LineActivityLog, _$identity);

  /// Serializes this LineActivityLog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineActivityLog&&(identical(other.id, id) || other.id == id)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,simLineId,userId,eventType,description,const DeepCollectionEquality().hash(metadata),createdAt);

@override
String toString() {
  return 'LineActivityLog(id: $id, simLineId: $simLineId, userId: $userId, eventType: $eventType, description: $description, metadata: $metadata, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LineActivityLogCopyWith<$Res>  {
  factory $LineActivityLogCopyWith(LineActivityLog value, $Res Function(LineActivityLog) _then) = _$LineActivityLogCopyWithImpl;
@useResult
$Res call({
 String id, String simLineId, String userId, String eventType, String? description, Map<String, dynamic> metadata, DateTime createdAt
});




}
/// @nodoc
class _$LineActivityLogCopyWithImpl<$Res>
    implements $LineActivityLogCopyWith<$Res> {
  _$LineActivityLogCopyWithImpl(this._self, this._then);

  final LineActivityLog _self;
  final $Res Function(LineActivityLog) _then;

/// Create a copy of LineActivityLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? simLineId = null,Object? userId = null,Object? eventType = null,Object? description = freezed,Object? metadata = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LineActivityLog].
extension LineActivityLogPatterns on LineActivityLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineActivityLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineActivityLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineActivityLog value)  $default,){
final _that = this;
switch (_that) {
case _LineActivityLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineActivityLog value)?  $default,){
final _that = this;
switch (_that) {
case _LineActivityLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String simLineId,  String userId,  String eventType,  String? description,  Map<String, dynamic> metadata,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineActivityLog() when $default != null:
return $default(_that.id,_that.simLineId,_that.userId,_that.eventType,_that.description,_that.metadata,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String simLineId,  String userId,  String eventType,  String? description,  Map<String, dynamic> metadata,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LineActivityLog():
return $default(_that.id,_that.simLineId,_that.userId,_that.eventType,_that.description,_that.metadata,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String simLineId,  String userId,  String eventType,  String? description,  Map<String, dynamic> metadata,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LineActivityLog() when $default != null:
return $default(_that.id,_that.simLineId,_that.userId,_that.eventType,_that.description,_that.metadata,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _LineActivityLog extends LineActivityLog {
  const _LineActivityLog({required this.id, required this.simLineId, required this.userId, required this.eventType, this.description, final  Map<String, dynamic> metadata = const {}, required this.createdAt}): _metadata = metadata,super._();
  factory _LineActivityLog.fromJson(Map<String, dynamic> json) => _$LineActivityLogFromJson(json);

@override final  String id;
@override final  String simLineId;
@override final  String userId;
@override final  String eventType;
@override final  String? description;
 final  Map<String, dynamic> _metadata;
@override@JsonKey() Map<String, dynamic> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}

@override final  DateTime createdAt;

/// Create a copy of LineActivityLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineActivityLogCopyWith<_LineActivityLog> get copyWith => __$LineActivityLogCopyWithImpl<_LineActivityLog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineActivityLogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineActivityLog&&(identical(other.id, id) || other.id == id)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,simLineId,userId,eventType,description,const DeepCollectionEquality().hash(_metadata),createdAt);

@override
String toString() {
  return 'LineActivityLog(id: $id, simLineId: $simLineId, userId: $userId, eventType: $eventType, description: $description, metadata: $metadata, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LineActivityLogCopyWith<$Res> implements $LineActivityLogCopyWith<$Res> {
  factory _$LineActivityLogCopyWith(_LineActivityLog value, $Res Function(_LineActivityLog) _then) = __$LineActivityLogCopyWithImpl;
@override @useResult
$Res call({
 String id, String simLineId, String userId, String eventType, String? description, Map<String, dynamic> metadata, DateTime createdAt
});




}
/// @nodoc
class __$LineActivityLogCopyWithImpl<$Res>
    implements _$LineActivityLogCopyWith<$Res> {
  __$LineActivityLogCopyWithImpl(this._self, this._then);

  final _LineActivityLog _self;
  final $Res Function(_LineActivityLog) _then;

/// Create a copy of LineActivityLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? simLineId = null,Object? userId = null,Object? eventType = null,Object? description = freezed,Object? metadata = null,Object? createdAt = null,}) {
  return _then(_LineActivityLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
