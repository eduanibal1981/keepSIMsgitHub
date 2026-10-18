// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'second_number_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SecondNumberMessage {

 String get id; String get didId; String get senderNumber; String get recipientNumber; String get body; String? get extractedOtp; bool get isRead; DateTime get receivedAt;
/// Create a copy of SecondNumberMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecondNumberMessageCopyWith<SecondNumberMessage> get copyWith => _$SecondNumberMessageCopyWithImpl<SecondNumberMessage>(this as SecondNumberMessage, _$identity);

  /// Serializes this SecondNumberMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SecondNumberMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.didId, didId) || other.didId == didId)&&(identical(other.senderNumber, senderNumber) || other.senderNumber == senderNumber)&&(identical(other.recipientNumber, recipientNumber) || other.recipientNumber == recipientNumber)&&(identical(other.body, body) || other.body == body)&&(identical(other.extractedOtp, extractedOtp) || other.extractedOtp == extractedOtp)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,didId,senderNumber,recipientNumber,body,extractedOtp,isRead,receivedAt);

@override
String toString() {
  return 'SecondNumberMessage(id: $id, didId: $didId, senderNumber: $senderNumber, recipientNumber: $recipientNumber, body: $body, extractedOtp: $extractedOtp, isRead: $isRead, receivedAt: $receivedAt)';
}


}

/// @nodoc
abstract mixin class $SecondNumberMessageCopyWith<$Res>  {
  factory $SecondNumberMessageCopyWith(SecondNumberMessage value, $Res Function(SecondNumberMessage) _then) = _$SecondNumberMessageCopyWithImpl;
@useResult
$Res call({
 String id, String didId, String senderNumber, String recipientNumber, String body, String? extractedOtp, bool isRead, DateTime receivedAt
});




}
/// @nodoc
class _$SecondNumberMessageCopyWithImpl<$Res>
    implements $SecondNumberMessageCopyWith<$Res> {
  _$SecondNumberMessageCopyWithImpl(this._self, this._then);

  final SecondNumberMessage _self;
  final $Res Function(SecondNumberMessage) _then;

/// Create a copy of SecondNumberMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? didId = null,Object? senderNumber = null,Object? recipientNumber = null,Object? body = null,Object? extractedOtp = freezed,Object? isRead = null,Object? receivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,didId: null == didId ? _self.didId : didId // ignore: cast_nullable_to_non_nullable
as String,senderNumber: null == senderNumber ? _self.senderNumber : senderNumber // ignore: cast_nullable_to_non_nullable
as String,recipientNumber: null == recipientNumber ? _self.recipientNumber : recipientNumber // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,extractedOtp: freezed == extractedOtp ? _self.extractedOtp : extractedOtp // ignore: cast_nullable_to_non_nullable
as String?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SecondNumberMessage].
extension SecondNumberMessagePatterns on SecondNumberMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SecondNumberMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SecondNumberMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SecondNumberMessage value)  $default,){
final _that = this;
switch (_that) {
case _SecondNumberMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SecondNumberMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SecondNumberMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String didId,  String senderNumber,  String recipientNumber,  String body,  String? extractedOtp,  bool isRead,  DateTime receivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SecondNumberMessage() when $default != null:
return $default(_that.id,_that.didId,_that.senderNumber,_that.recipientNumber,_that.body,_that.extractedOtp,_that.isRead,_that.receivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String didId,  String senderNumber,  String recipientNumber,  String body,  String? extractedOtp,  bool isRead,  DateTime receivedAt)  $default,) {final _that = this;
switch (_that) {
case _SecondNumberMessage():
return $default(_that.id,_that.didId,_that.senderNumber,_that.recipientNumber,_that.body,_that.extractedOtp,_that.isRead,_that.receivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String didId,  String senderNumber,  String recipientNumber,  String body,  String? extractedOtp,  bool isRead,  DateTime receivedAt)?  $default,) {final _that = this;
switch (_that) {
case _SecondNumberMessage() when $default != null:
return $default(_that.id,_that.didId,_that.senderNumber,_that.recipientNumber,_that.body,_that.extractedOtp,_that.isRead,_that.receivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _SecondNumberMessage implements SecondNumberMessage {
  const _SecondNumberMessage({required this.id, required this.didId, required this.senderNumber, required this.recipientNumber, required this.body, this.extractedOtp, this.isRead = false, required this.receivedAt});
  factory _SecondNumberMessage.fromJson(Map<String, dynamic> json) => _$SecondNumberMessageFromJson(json);

@override final  String id;
@override final  String didId;
@override final  String senderNumber;
@override final  String recipientNumber;
@override final  String body;
@override final  String? extractedOtp;
@override@JsonKey() final  bool isRead;
@override final  DateTime receivedAt;

/// Create a copy of SecondNumberMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecondNumberMessageCopyWith<_SecondNumberMessage> get copyWith => __$SecondNumberMessageCopyWithImpl<_SecondNumberMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SecondNumberMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecondNumberMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.didId, didId) || other.didId == didId)&&(identical(other.senderNumber, senderNumber) || other.senderNumber == senderNumber)&&(identical(other.recipientNumber, recipientNumber) || other.recipientNumber == recipientNumber)&&(identical(other.body, body) || other.body == body)&&(identical(other.extractedOtp, extractedOtp) || other.extractedOtp == extractedOtp)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,didId,senderNumber,recipientNumber,body,extractedOtp,isRead,receivedAt);

@override
String toString() {
  return 'SecondNumberMessage(id: $id, didId: $didId, senderNumber: $senderNumber, recipientNumber: $recipientNumber, body: $body, extractedOtp: $extractedOtp, isRead: $isRead, receivedAt: $receivedAt)';
}


}

/// @nodoc
abstract mixin class _$SecondNumberMessageCopyWith<$Res> implements $SecondNumberMessageCopyWith<$Res> {
  factory _$SecondNumberMessageCopyWith(_SecondNumberMessage value, $Res Function(_SecondNumberMessage) _then) = __$SecondNumberMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String didId, String senderNumber, String recipientNumber, String body, String? extractedOtp, bool isRead, DateTime receivedAt
});




}
/// @nodoc
class __$SecondNumberMessageCopyWithImpl<$Res>
    implements _$SecondNumberMessageCopyWith<$Res> {
  __$SecondNumberMessageCopyWithImpl(this._self, this._then);

  final _SecondNumberMessage _self;
  final $Res Function(_SecondNumberMessage) _then;

/// Create a copy of SecondNumberMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? didId = null,Object? senderNumber = null,Object? recipientNumber = null,Object? body = null,Object? extractedOtp = freezed,Object? isRead = null,Object? receivedAt = null,}) {
  return _then(_SecondNumberMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,didId: null == didId ? _self.didId : didId // ignore: cast_nullable_to_non_nullable
as String,senderNumber: null == senderNumber ? _self.senderNumber : senderNumber // ignore: cast_nullable_to_non_nullable
as String,recipientNumber: null == recipientNumber ? _self.recipientNumber : recipientNumber // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,extractedOtp: freezed == extractedOtp ? _self.extractedOtp : extractedOtp // ignore: cast_nullable_to_non_nullable
as String?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SecondNumberOrder {

 String get id; String get state; String get phoneNumber; String? get didId;
/// Create a copy of SecondNumberOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecondNumberOrderCopyWith<SecondNumberOrder> get copyWith => _$SecondNumberOrderCopyWithImpl<SecondNumberOrder>(this as SecondNumberOrder, _$identity);

  /// Serializes this SecondNumberOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SecondNumberOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.state, state) || other.state == state)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.didId, didId) || other.didId == didId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,state,phoneNumber,didId);

@override
String toString() {
  return 'SecondNumberOrder(id: $id, state: $state, phoneNumber: $phoneNumber, didId: $didId)';
}


}

/// @nodoc
abstract mixin class $SecondNumberOrderCopyWith<$Res>  {
  factory $SecondNumberOrderCopyWith(SecondNumberOrder value, $Res Function(SecondNumberOrder) _then) = _$SecondNumberOrderCopyWithImpl;
@useResult
$Res call({
 String id, String state, String phoneNumber, String? didId
});




}
/// @nodoc
class _$SecondNumberOrderCopyWithImpl<$Res>
    implements $SecondNumberOrderCopyWith<$Res> {
  _$SecondNumberOrderCopyWithImpl(this._self, this._then);

  final SecondNumberOrder _self;
  final $Res Function(SecondNumberOrder) _then;

/// Create a copy of SecondNumberOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? state = null,Object? phoneNumber = null,Object? didId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,didId: freezed == didId ? _self.didId : didId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SecondNumberOrder].
extension SecondNumberOrderPatterns on SecondNumberOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SecondNumberOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SecondNumberOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SecondNumberOrder value)  $default,){
final _that = this;
switch (_that) {
case _SecondNumberOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SecondNumberOrder value)?  $default,){
final _that = this;
switch (_that) {
case _SecondNumberOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String state,  String phoneNumber,  String? didId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SecondNumberOrder() when $default != null:
return $default(_that.id,_that.state,_that.phoneNumber,_that.didId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String state,  String phoneNumber,  String? didId)  $default,) {final _that = this;
switch (_that) {
case _SecondNumberOrder():
return $default(_that.id,_that.state,_that.phoneNumber,_that.didId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String state,  String phoneNumber,  String? didId)?  $default,) {final _that = this;
switch (_that) {
case _SecondNumberOrder() when $default != null:
return $default(_that.id,_that.state,_that.phoneNumber,_that.didId);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _SecondNumberOrder extends SecondNumberOrder {
  const _SecondNumberOrder({required this.id, required this.state, required this.phoneNumber, this.didId}): super._();
  factory _SecondNumberOrder.fromJson(Map<String, dynamic> json) => _$SecondNumberOrderFromJson(json);

@override final  String id;
@override final  String state;
@override final  String phoneNumber;
@override final  String? didId;

/// Create a copy of SecondNumberOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecondNumberOrderCopyWith<_SecondNumberOrder> get copyWith => __$SecondNumberOrderCopyWithImpl<_SecondNumberOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SecondNumberOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecondNumberOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.state, state) || other.state == state)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.didId, didId) || other.didId == didId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,state,phoneNumber,didId);

@override
String toString() {
  return 'SecondNumberOrder(id: $id, state: $state, phoneNumber: $phoneNumber, didId: $didId)';
}


}

/// @nodoc
abstract mixin class _$SecondNumberOrderCopyWith<$Res> implements $SecondNumberOrderCopyWith<$Res> {
  factory _$SecondNumberOrderCopyWith(_SecondNumberOrder value, $Res Function(_SecondNumberOrder) _then) = __$SecondNumberOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String state, String phoneNumber, String? didId
});




}
/// @nodoc
class __$SecondNumberOrderCopyWithImpl<$Res>
    implements _$SecondNumberOrderCopyWith<$Res> {
  __$SecondNumberOrderCopyWithImpl(this._self, this._then);

  final _SecondNumberOrder _self;
  final $Res Function(_SecondNumberOrder) _then;

/// Create a copy of SecondNumberOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? state = null,Object? phoneNumber = null,Object? didId = freezed,}) {
  return _then(_SecondNumberOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,didId: freezed == didId ? _self.didId : didId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
