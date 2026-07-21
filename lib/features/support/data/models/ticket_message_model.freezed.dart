// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TicketMessage {

 String get id; String get ticketId; String get userId; String get sender; String get message; List<Map<String, dynamic>> get attachments; DateTime get createdAt;
/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketMessageCopyWith<TicketMessage> get copyWith => _$TicketMessageCopyWithImpl<TicketMessage>(this as TicketMessage, _$identity);

  /// Serializes this TicketMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,userId,sender,message,const DeepCollectionEquality().hash(attachments),createdAt);

@override
String toString() {
  return 'TicketMessage(id: $id, ticketId: $ticketId, userId: $userId, sender: $sender, message: $message, attachments: $attachments, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $TicketMessageCopyWith<$Res>  {
  factory $TicketMessageCopyWith(TicketMessage value, $Res Function(TicketMessage) _then) = _$TicketMessageCopyWithImpl;
@useResult
$Res call({
 String id, String ticketId, String userId, String sender, String message, List<Map<String, dynamic>> attachments, DateTime createdAt
});




}
/// @nodoc
class _$TicketMessageCopyWithImpl<$Res>
    implements $TicketMessageCopyWith<$Res> {
  _$TicketMessageCopyWithImpl(this._self, this._then);

  final TicketMessage _self;
  final $Res Function(TicketMessage) _then;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticketId = null,Object? userId = null,Object? sender = null,Object? message = null,Object? attachments = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [TicketMessage].
extension TicketMessagePatterns on TicketMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketMessage value)  $default,){
final _that = this;
switch (_that) {
case _TicketMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketMessage value)?  $default,){
final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticketId,  String userId,  String sender,  String message,  List<Map<String, dynamic>> attachments,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
return $default(_that.id,_that.ticketId,_that.userId,_that.sender,_that.message,_that.attachments,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticketId,  String userId,  String sender,  String message,  List<Map<String, dynamic>> attachments,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _TicketMessage():
return $default(_that.id,_that.ticketId,_that.userId,_that.sender,_that.message,_that.attachments,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticketId,  String userId,  String sender,  String message,  List<Map<String, dynamic>> attachments,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _TicketMessage() when $default != null:
return $default(_that.id,_that.ticketId,_that.userId,_that.sender,_that.message,_that.attachments,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _TicketMessage extends TicketMessage {
  const _TicketMessage({required this.id, required this.ticketId, required this.userId, required this.sender, required this.message, final  List<Map<String, dynamic>> attachments = const [], required this.createdAt}): _attachments = attachments,super._();
  factory _TicketMessage.fromJson(Map<String, dynamic> json) => _$TicketMessageFromJson(json);

@override final  String id;
@override final  String ticketId;
@override final  String userId;
@override final  String sender;
@override final  String message;
 final  List<Map<String, dynamic>> _attachments;
@override@JsonKey() List<Map<String, dynamic>> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  DateTime createdAt;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketMessageCopyWith<_TicketMessage> get copyWith => __$TicketMessageCopyWithImpl<_TicketMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TicketMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticketId,userId,sender,message,const DeepCollectionEquality().hash(_attachments),createdAt);

@override
String toString() {
  return 'TicketMessage(id: $id, ticketId: $ticketId, userId: $userId, sender: $sender, message: $message, attachments: $attachments, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$TicketMessageCopyWith<$Res> implements $TicketMessageCopyWith<$Res> {
  factory _$TicketMessageCopyWith(_TicketMessage value, $Res Function(_TicketMessage) _then) = __$TicketMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticketId, String userId, String sender, String message, List<Map<String, dynamic>> attachments, DateTime createdAt
});




}
/// @nodoc
class __$TicketMessageCopyWithImpl<$Res>
    implements _$TicketMessageCopyWith<$Res> {
  __$TicketMessageCopyWithImpl(this._self, this._then);

  final _TicketMessage _self;
  final $Res Function(_TicketMessage) _then;

/// Create a copy of TicketMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticketId = null,Object? userId = null,Object? sender = null,Object? message = null,Object? attachments = null,Object? createdAt = null,}) {
  return _then(_TicketMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
