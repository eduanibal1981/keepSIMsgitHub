// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'referral_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReferredFriend {

 String get id; String get referrerId; String get referredUserId; String get code; DateTime? get createdAt; String? get displayName; String? get avatarUrl;
/// Create a copy of ReferredFriend
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferredFriendCopyWith<ReferredFriend> get copyWith => _$ReferredFriendCopyWithImpl<ReferredFriend>(this as ReferredFriend, _$identity);

  /// Serializes this ReferredFriend to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferredFriend&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredUserId, referredUserId) || other.referredUserId == referredUserId)&&(identical(other.code, code) || other.code == code)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredUserId,code,createdAt,displayName,avatarUrl);

@override
String toString() {
  return 'ReferredFriend(id: $id, referrerId: $referrerId, referredUserId: $referredUserId, code: $code, createdAt: $createdAt, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $ReferredFriendCopyWith<$Res>  {
  factory $ReferredFriendCopyWith(ReferredFriend value, $Res Function(ReferredFriend) _then) = _$ReferredFriendCopyWithImpl;
@useResult
$Res call({
 String id, String referrerId, String referredUserId, String code, DateTime? createdAt, String? displayName, String? avatarUrl
});




}
/// @nodoc
class _$ReferredFriendCopyWithImpl<$Res>
    implements $ReferredFriendCopyWith<$Res> {
  _$ReferredFriendCopyWithImpl(this._self, this._then);

  final ReferredFriend _self;
  final $Res Function(ReferredFriend) _then;

/// Create a copy of ReferredFriend
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? referrerId = null,Object? referredUserId = null,Object? code = null,Object? createdAt = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredUserId: null == referredUserId ? _self.referredUserId : referredUserId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferredFriend].
extension ReferredFriendPatterns on ReferredFriend {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferredFriend value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferredFriend() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferredFriend value)  $default,){
final _that = this;
switch (_that) {
case _ReferredFriend():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferredFriend value)?  $default,){
final _that = this;
switch (_that) {
case _ReferredFriend() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredUserId,  String code,  DateTime? createdAt,  String? displayName,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferredFriend() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.code,_that.createdAt,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredUserId,  String code,  DateTime? createdAt,  String? displayName,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _ReferredFriend():
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.code,_that.createdAt,_that.displayName,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String referrerId,  String referredUserId,  String code,  DateTime? createdAt,  String? displayName,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _ReferredFriend() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.code,_that.createdAt,_that.displayName,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ReferredFriend implements ReferredFriend {
  const _ReferredFriend({required this.id, required this.referrerId, required this.referredUserId, required this.code, this.createdAt, this.displayName, this.avatarUrl});
  factory _ReferredFriend.fromJson(Map<String, dynamic> json) => _$ReferredFriendFromJson(json);

@override final  String id;
@override final  String referrerId;
@override final  String referredUserId;
@override final  String code;
@override final  DateTime? createdAt;
@override final  String? displayName;
@override final  String? avatarUrl;

/// Create a copy of ReferredFriend
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferredFriendCopyWith<_ReferredFriend> get copyWith => __$ReferredFriendCopyWithImpl<_ReferredFriend>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferredFriendToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferredFriend&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredUserId, referredUserId) || other.referredUserId == referredUserId)&&(identical(other.code, code) || other.code == code)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredUserId,code,createdAt,displayName,avatarUrl);

@override
String toString() {
  return 'ReferredFriend(id: $id, referrerId: $referrerId, referredUserId: $referredUserId, code: $code, createdAt: $createdAt, displayName: $displayName, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$ReferredFriendCopyWith<$Res> implements $ReferredFriendCopyWith<$Res> {
  factory _$ReferredFriendCopyWith(_ReferredFriend value, $Res Function(_ReferredFriend) _then) = __$ReferredFriendCopyWithImpl;
@override @useResult
$Res call({
 String id, String referrerId, String referredUserId, String code, DateTime? createdAt, String? displayName, String? avatarUrl
});




}
/// @nodoc
class __$ReferredFriendCopyWithImpl<$Res>
    implements _$ReferredFriendCopyWith<$Res> {
  __$ReferredFriendCopyWithImpl(this._self, this._then);

  final _ReferredFriend _self;
  final $Res Function(_ReferredFriend) _then;

/// Create a copy of ReferredFriend
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? referrerId = null,Object? referredUserId = null,Object? code = null,Object? createdAt = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,}) {
  return _then(_ReferredFriend(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredUserId: null == referredUserId ? _self.referredUserId : referredUserId // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ReferralPointEntry {

 String get id; String get referrerId; String get referredUserId; String? get simLineId; int get points; String get source; DateTime? get createdAt;
/// Create a copy of ReferralPointEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferralPointEntryCopyWith<ReferralPointEntry> get copyWith => _$ReferralPointEntryCopyWithImpl<ReferralPointEntry>(this as ReferralPointEntry, _$identity);

  /// Serializes this ReferralPointEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferralPointEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredUserId, referredUserId) || other.referredUserId == referredUserId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.points, points) || other.points == points)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredUserId,simLineId,points,source,createdAt);

@override
String toString() {
  return 'ReferralPointEntry(id: $id, referrerId: $referrerId, referredUserId: $referredUserId, simLineId: $simLineId, points: $points, source: $source, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReferralPointEntryCopyWith<$Res>  {
  factory $ReferralPointEntryCopyWith(ReferralPointEntry value, $Res Function(ReferralPointEntry) _then) = _$ReferralPointEntryCopyWithImpl;
@useResult
$Res call({
 String id, String referrerId, String referredUserId, String? simLineId, int points, String source, DateTime? createdAt
});




}
/// @nodoc
class _$ReferralPointEntryCopyWithImpl<$Res>
    implements $ReferralPointEntryCopyWith<$Res> {
  _$ReferralPointEntryCopyWithImpl(this._self, this._then);

  final ReferralPointEntry _self;
  final $Res Function(ReferralPointEntry) _then;

/// Create a copy of ReferralPointEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? referrerId = null,Object? referredUserId = null,Object? simLineId = freezed,Object? points = null,Object? source = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredUserId: null == referredUserId ? _self.referredUserId : referredUserId // ignore: cast_nullable_to_non_nullable
as String,simLineId: freezed == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String?,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferralPointEntry].
extension ReferralPointEntryPatterns on ReferralPointEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferralPointEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferralPointEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferralPointEntry value)  $default,){
final _that = this;
switch (_that) {
case _ReferralPointEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferralPointEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ReferralPointEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredUserId,  String? simLineId,  int points,  String source,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferralPointEntry() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.simLineId,_that.points,_that.source,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredUserId,  String? simLineId,  int points,  String source,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ReferralPointEntry():
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.simLineId,_that.points,_that.source,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String referrerId,  String referredUserId,  String? simLineId,  int points,  String source,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ReferralPointEntry() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredUserId,_that.simLineId,_that.points,_that.source,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ReferralPointEntry implements ReferralPointEntry {
  const _ReferralPointEntry({required this.id, required this.referrerId, required this.referredUserId, this.simLineId, required this.points, required this.source, this.createdAt});
  factory _ReferralPointEntry.fromJson(Map<String, dynamic> json) => _$ReferralPointEntryFromJson(json);

@override final  String id;
@override final  String referrerId;
@override final  String referredUserId;
@override final  String? simLineId;
@override final  int points;
@override final  String source;
@override final  DateTime? createdAt;

/// Create a copy of ReferralPointEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferralPointEntryCopyWith<_ReferralPointEntry> get copyWith => __$ReferralPointEntryCopyWithImpl<_ReferralPointEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferralPointEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferralPointEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredUserId, referredUserId) || other.referredUserId == referredUserId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.points, points) || other.points == points)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredUserId,simLineId,points,source,createdAt);

@override
String toString() {
  return 'ReferralPointEntry(id: $id, referrerId: $referrerId, referredUserId: $referredUserId, simLineId: $simLineId, points: $points, source: $source, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReferralPointEntryCopyWith<$Res> implements $ReferralPointEntryCopyWith<$Res> {
  factory _$ReferralPointEntryCopyWith(_ReferralPointEntry value, $Res Function(_ReferralPointEntry) _then) = __$ReferralPointEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String referrerId, String referredUserId, String? simLineId, int points, String source, DateTime? createdAt
});




}
/// @nodoc
class __$ReferralPointEntryCopyWithImpl<$Res>
    implements _$ReferralPointEntryCopyWith<$Res> {
  __$ReferralPointEntryCopyWithImpl(this._self, this._then);

  final _ReferralPointEntry _self;
  final $Res Function(_ReferralPointEntry) _then;

/// Create a copy of ReferralPointEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? referrerId = null,Object? referredUserId = null,Object? simLineId = freezed,Object? points = null,Object? source = null,Object? createdAt = freezed,}) {
  return _then(_ReferralPointEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredUserId: null == referredUserId ? _self.referredUserId : referredUserId // ignore: cast_nullable_to_non_nullable
as String,simLineId: freezed == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String?,points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ReferralRedemptionEntry {

 String get id; String get userId; int get pointsSpent; String? get walletTxnId; DateTime? get createdAt;
/// Create a copy of ReferralRedemptionEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferralRedemptionEntryCopyWith<ReferralRedemptionEntry> get copyWith => _$ReferralRedemptionEntryCopyWithImpl<ReferralRedemptionEntry>(this as ReferralRedemptionEntry, _$identity);

  /// Serializes this ReferralRedemptionEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferralRedemptionEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.pointsSpent, pointsSpent) || other.pointsSpent == pointsSpent)&&(identical(other.walletTxnId, walletTxnId) || other.walletTxnId == walletTxnId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,pointsSpent,walletTxnId,createdAt);

@override
String toString() {
  return 'ReferralRedemptionEntry(id: $id, userId: $userId, pointsSpent: $pointsSpent, walletTxnId: $walletTxnId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReferralRedemptionEntryCopyWith<$Res>  {
  factory $ReferralRedemptionEntryCopyWith(ReferralRedemptionEntry value, $Res Function(ReferralRedemptionEntry) _then) = _$ReferralRedemptionEntryCopyWithImpl;
@useResult
$Res call({
 String id, String userId, int pointsSpent, String? walletTxnId, DateTime? createdAt
});




}
/// @nodoc
class _$ReferralRedemptionEntryCopyWithImpl<$Res>
    implements $ReferralRedemptionEntryCopyWith<$Res> {
  _$ReferralRedemptionEntryCopyWithImpl(this._self, this._then);

  final ReferralRedemptionEntry _self;
  final $Res Function(ReferralRedemptionEntry) _then;

/// Create a copy of ReferralRedemptionEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? pointsSpent = null,Object? walletTxnId = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,pointsSpent: null == pointsSpent ? _self.pointsSpent : pointsSpent // ignore: cast_nullable_to_non_nullable
as int,walletTxnId: freezed == walletTxnId ? _self.walletTxnId : walletTxnId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferralRedemptionEntry].
extension ReferralRedemptionEntryPatterns on ReferralRedemptionEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferralRedemptionEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferralRedemptionEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferralRedemptionEntry value)  $default,){
final _that = this;
switch (_that) {
case _ReferralRedemptionEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferralRedemptionEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ReferralRedemptionEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  int pointsSpent,  String? walletTxnId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferralRedemptionEntry() when $default != null:
return $default(_that.id,_that.userId,_that.pointsSpent,_that.walletTxnId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  int pointsSpent,  String? walletTxnId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ReferralRedemptionEntry():
return $default(_that.id,_that.userId,_that.pointsSpent,_that.walletTxnId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  int pointsSpent,  String? walletTxnId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ReferralRedemptionEntry() when $default != null:
return $default(_that.id,_that.userId,_that.pointsSpent,_that.walletTxnId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ReferralRedemptionEntry implements ReferralRedemptionEntry {
  const _ReferralRedemptionEntry({required this.id, required this.userId, required this.pointsSpent, this.walletTxnId, this.createdAt});
  factory _ReferralRedemptionEntry.fromJson(Map<String, dynamic> json) => _$ReferralRedemptionEntryFromJson(json);

@override final  String id;
@override final  String userId;
@override final  int pointsSpent;
@override final  String? walletTxnId;
@override final  DateTime? createdAt;

/// Create a copy of ReferralRedemptionEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferralRedemptionEntryCopyWith<_ReferralRedemptionEntry> get copyWith => __$ReferralRedemptionEntryCopyWithImpl<_ReferralRedemptionEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferralRedemptionEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferralRedemptionEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.pointsSpent, pointsSpent) || other.pointsSpent == pointsSpent)&&(identical(other.walletTxnId, walletTxnId) || other.walletTxnId == walletTxnId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,pointsSpent,walletTxnId,createdAt);

@override
String toString() {
  return 'ReferralRedemptionEntry(id: $id, userId: $userId, pointsSpent: $pointsSpent, walletTxnId: $walletTxnId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReferralRedemptionEntryCopyWith<$Res> implements $ReferralRedemptionEntryCopyWith<$Res> {
  factory _$ReferralRedemptionEntryCopyWith(_ReferralRedemptionEntry value, $Res Function(_ReferralRedemptionEntry) _then) = __$ReferralRedemptionEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, int pointsSpent, String? walletTxnId, DateTime? createdAt
});




}
/// @nodoc
class __$ReferralRedemptionEntryCopyWithImpl<$Res>
    implements _$ReferralRedemptionEntryCopyWith<$Res> {
  __$ReferralRedemptionEntryCopyWithImpl(this._self, this._then);

  final _ReferralRedemptionEntry _self;
  final $Res Function(_ReferralRedemptionEntry) _then;

/// Create a copy of ReferralRedemptionEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? pointsSpent = null,Object? walletTxnId = freezed,Object? createdAt = freezed,}) {
  return _then(_ReferralRedemptionEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,pointsSpent: null == pointsSpent ? _self.pointsSpent : pointsSpent // ignore: cast_nullable_to_non_nullable
as int,walletTxnId: freezed == walletTxnId ? _self.walletTxnId : walletTxnId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ReferralSummary {

 int get pointsBalance; int get totalPointsEarned; int get pointsSpent; String get referralCode; List<ReferredFriend> get referredFriends; List<ReferralPointEntry> get pointHistory; List<ReferralRedemptionEntry> get redemptions;
/// Create a copy of ReferralSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferralSummaryCopyWith<ReferralSummary> get copyWith => _$ReferralSummaryCopyWithImpl<ReferralSummary>(this as ReferralSummary, _$identity);

  /// Serializes this ReferralSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReferralSummary&&(identical(other.pointsBalance, pointsBalance) || other.pointsBalance == pointsBalance)&&(identical(other.totalPointsEarned, totalPointsEarned) || other.totalPointsEarned == totalPointsEarned)&&(identical(other.pointsSpent, pointsSpent) || other.pointsSpent == pointsSpent)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&const DeepCollectionEquality().equals(other.referredFriends, referredFriends)&&const DeepCollectionEquality().equals(other.pointHistory, pointHistory)&&const DeepCollectionEquality().equals(other.redemptions, redemptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pointsBalance,totalPointsEarned,pointsSpent,referralCode,const DeepCollectionEquality().hash(referredFriends),const DeepCollectionEquality().hash(pointHistory),const DeepCollectionEquality().hash(redemptions));

@override
String toString() {
  return 'ReferralSummary(pointsBalance: $pointsBalance, totalPointsEarned: $totalPointsEarned, pointsSpent: $pointsSpent, referralCode: $referralCode, referredFriends: $referredFriends, pointHistory: $pointHistory, redemptions: $redemptions)';
}


}

/// @nodoc
abstract mixin class $ReferralSummaryCopyWith<$Res>  {
  factory $ReferralSummaryCopyWith(ReferralSummary value, $Res Function(ReferralSummary) _then) = _$ReferralSummaryCopyWithImpl;
@useResult
$Res call({
 int pointsBalance, int totalPointsEarned, int pointsSpent, String referralCode, List<ReferredFriend> referredFriends, List<ReferralPointEntry> pointHistory, List<ReferralRedemptionEntry> redemptions
});




}
/// @nodoc
class _$ReferralSummaryCopyWithImpl<$Res>
    implements $ReferralSummaryCopyWith<$Res> {
  _$ReferralSummaryCopyWithImpl(this._self, this._then);

  final ReferralSummary _self;
  final $Res Function(ReferralSummary) _then;

/// Create a copy of ReferralSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pointsBalance = null,Object? totalPointsEarned = null,Object? pointsSpent = null,Object? referralCode = null,Object? referredFriends = null,Object? pointHistory = null,Object? redemptions = null,}) {
  return _then(_self.copyWith(
pointsBalance: null == pointsBalance ? _self.pointsBalance : pointsBalance // ignore: cast_nullable_to_non_nullable
as int,totalPointsEarned: null == totalPointsEarned ? _self.totalPointsEarned : totalPointsEarned // ignore: cast_nullable_to_non_nullable
as int,pointsSpent: null == pointsSpent ? _self.pointsSpent : pointsSpent // ignore: cast_nullable_to_non_nullable
as int,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referredFriends: null == referredFriends ? _self.referredFriends : referredFriends // ignore: cast_nullable_to_non_nullable
as List<ReferredFriend>,pointHistory: null == pointHistory ? _self.pointHistory : pointHistory // ignore: cast_nullable_to_non_nullable
as List<ReferralPointEntry>,redemptions: null == redemptions ? _self.redemptions : redemptions // ignore: cast_nullable_to_non_nullable
as List<ReferralRedemptionEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReferralSummary].
extension ReferralSummaryPatterns on ReferralSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReferralSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReferralSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReferralSummary value)  $default,){
final _that = this;
switch (_that) {
case _ReferralSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReferralSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ReferralSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int pointsBalance,  int totalPointsEarned,  int pointsSpent,  String referralCode,  List<ReferredFriend> referredFriends,  List<ReferralPointEntry> pointHistory,  List<ReferralRedemptionEntry> redemptions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReferralSummary() when $default != null:
return $default(_that.pointsBalance,_that.totalPointsEarned,_that.pointsSpent,_that.referralCode,_that.referredFriends,_that.pointHistory,_that.redemptions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int pointsBalance,  int totalPointsEarned,  int pointsSpent,  String referralCode,  List<ReferredFriend> referredFriends,  List<ReferralPointEntry> pointHistory,  List<ReferralRedemptionEntry> redemptions)  $default,) {final _that = this;
switch (_that) {
case _ReferralSummary():
return $default(_that.pointsBalance,_that.totalPointsEarned,_that.pointsSpent,_that.referralCode,_that.referredFriends,_that.pointHistory,_that.redemptions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int pointsBalance,  int totalPointsEarned,  int pointsSpent,  String referralCode,  List<ReferredFriend> referredFriends,  List<ReferralPointEntry> pointHistory,  List<ReferralRedemptionEntry> redemptions)?  $default,) {final _that = this;
switch (_that) {
case _ReferralSummary() when $default != null:
return $default(_that.pointsBalance,_that.totalPointsEarned,_that.pointsSpent,_that.referralCode,_that.referredFriends,_that.pointHistory,_that.redemptions);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ReferralSummary implements ReferralSummary {
  const _ReferralSummary({required this.pointsBalance, required this.totalPointsEarned, required this.pointsSpent, required this.referralCode, required final  List<ReferredFriend> referredFriends, required final  List<ReferralPointEntry> pointHistory, required final  List<ReferralRedemptionEntry> redemptions}): _referredFriends = referredFriends,_pointHistory = pointHistory,_redemptions = redemptions;
  factory _ReferralSummary.fromJson(Map<String, dynamic> json) => _$ReferralSummaryFromJson(json);

@override final  int pointsBalance;
@override final  int totalPointsEarned;
@override final  int pointsSpent;
@override final  String referralCode;
 final  List<ReferredFriend> _referredFriends;
@override List<ReferredFriend> get referredFriends {
  if (_referredFriends is EqualUnmodifiableListView) return _referredFriends;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_referredFriends);
}

 final  List<ReferralPointEntry> _pointHistory;
@override List<ReferralPointEntry> get pointHistory {
  if (_pointHistory is EqualUnmodifiableListView) return _pointHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pointHistory);
}

 final  List<ReferralRedemptionEntry> _redemptions;
@override List<ReferralRedemptionEntry> get redemptions {
  if (_redemptions is EqualUnmodifiableListView) return _redemptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_redemptions);
}


/// Create a copy of ReferralSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferralSummaryCopyWith<_ReferralSummary> get copyWith => __$ReferralSummaryCopyWithImpl<_ReferralSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferralSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReferralSummary&&(identical(other.pointsBalance, pointsBalance) || other.pointsBalance == pointsBalance)&&(identical(other.totalPointsEarned, totalPointsEarned) || other.totalPointsEarned == totalPointsEarned)&&(identical(other.pointsSpent, pointsSpent) || other.pointsSpent == pointsSpent)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&const DeepCollectionEquality().equals(other._referredFriends, _referredFriends)&&const DeepCollectionEquality().equals(other._pointHistory, _pointHistory)&&const DeepCollectionEquality().equals(other._redemptions, _redemptions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pointsBalance,totalPointsEarned,pointsSpent,referralCode,const DeepCollectionEquality().hash(_referredFriends),const DeepCollectionEquality().hash(_pointHistory),const DeepCollectionEquality().hash(_redemptions));

@override
String toString() {
  return 'ReferralSummary(pointsBalance: $pointsBalance, totalPointsEarned: $totalPointsEarned, pointsSpent: $pointsSpent, referralCode: $referralCode, referredFriends: $referredFriends, pointHistory: $pointHistory, redemptions: $redemptions)';
}


}

/// @nodoc
abstract mixin class _$ReferralSummaryCopyWith<$Res> implements $ReferralSummaryCopyWith<$Res> {
  factory _$ReferralSummaryCopyWith(_ReferralSummary value, $Res Function(_ReferralSummary) _then) = __$ReferralSummaryCopyWithImpl;
@override @useResult
$Res call({
 int pointsBalance, int totalPointsEarned, int pointsSpent, String referralCode, List<ReferredFriend> referredFriends, List<ReferralPointEntry> pointHistory, List<ReferralRedemptionEntry> redemptions
});




}
/// @nodoc
class __$ReferralSummaryCopyWithImpl<$Res>
    implements _$ReferralSummaryCopyWith<$Res> {
  __$ReferralSummaryCopyWithImpl(this._self, this._then);

  final _ReferralSummary _self;
  final $Res Function(_ReferralSummary) _then;

/// Create a copy of ReferralSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pointsBalance = null,Object? totalPointsEarned = null,Object? pointsSpent = null,Object? referralCode = null,Object? referredFriends = null,Object? pointHistory = null,Object? redemptions = null,}) {
  return _then(_ReferralSummary(
pointsBalance: null == pointsBalance ? _self.pointsBalance : pointsBalance // ignore: cast_nullable_to_non_nullable
as int,totalPointsEarned: null == totalPointsEarned ? _self.totalPointsEarned : totalPointsEarned // ignore: cast_nullable_to_non_nullable
as int,pointsSpent: null == pointsSpent ? _self.pointsSpent : pointsSpent // ignore: cast_nullable_to_non_nullable
as int,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referredFriends: null == referredFriends ? _self._referredFriends : referredFriends // ignore: cast_nullable_to_non_nullable
as List<ReferredFriend>,pointHistory: null == pointHistory ? _self._pointHistory : pointHistory // ignore: cast_nullable_to_non_nullable
as List<ReferralPointEntry>,redemptions: null == redemptions ? _self._redemptions : redemptions // ignore: cast_nullable_to_non_nullable
as List<ReferralRedemptionEntry>,
  ));
}


}

// dart format on
