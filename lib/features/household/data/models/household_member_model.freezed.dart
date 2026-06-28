// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'household_member_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HouseholdMember {

 String get id;@JsonKey(name: 'owner_id') String get ownerId;@JsonKey(name: 'member_email') String get memberEmail;@JsonKey(name: 'member_id') String? get memberId; String get role;@JsonKey(name: 'invite_status') String get inviteStatus;@JsonKey(name: 'invited_at') DateTime get invitedAt;@JsonKey(name: 'accepted_at') DateTime? get acceptedAt;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'owner_name') String? get ownerName;@JsonKey(name: 'member_name') String? get memberName;@JsonKey(name: 'member_avatar') String? get memberAvatar;
/// Create a copy of HouseholdMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HouseholdMemberCopyWith<HouseholdMember> get copyWith => _$HouseholdMemberCopyWithImpl<HouseholdMember>(this as HouseholdMember, _$identity);

  /// Serializes this HouseholdMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HouseholdMember&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.memberEmail, memberEmail) || other.memberEmail == memberEmail)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteStatus, inviteStatus) || other.inviteStatus == inviteStatus)&&(identical(other.invitedAt, invitedAt) || other.invitedAt == invitedAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAvatar, memberAvatar) || other.memberAvatar == memberAvatar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerId,memberEmail,memberId,role,inviteStatus,invitedAt,acceptedAt,createdAt,ownerName,memberName,memberAvatar);

@override
String toString() {
  return 'HouseholdMember(id: $id, ownerId: $ownerId, memberEmail: $memberEmail, memberId: $memberId, role: $role, inviteStatus: $inviteStatus, invitedAt: $invitedAt, acceptedAt: $acceptedAt, createdAt: $createdAt, ownerName: $ownerName, memberName: $memberName, memberAvatar: $memberAvatar)';
}


}

/// @nodoc
abstract mixin class $HouseholdMemberCopyWith<$Res>  {
  factory $HouseholdMemberCopyWith(HouseholdMember value, $Res Function(HouseholdMember) _then) = _$HouseholdMemberCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'owner_id') String ownerId,@JsonKey(name: 'member_email') String memberEmail,@JsonKey(name: 'member_id') String? memberId, String role,@JsonKey(name: 'invite_status') String inviteStatus,@JsonKey(name: 'invited_at') DateTime invitedAt,@JsonKey(name: 'accepted_at') DateTime? acceptedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'owner_name') String? ownerName,@JsonKey(name: 'member_name') String? memberName,@JsonKey(name: 'member_avatar') String? memberAvatar
});




}
/// @nodoc
class _$HouseholdMemberCopyWithImpl<$Res>
    implements $HouseholdMemberCopyWith<$Res> {
  _$HouseholdMemberCopyWithImpl(this._self, this._then);

  final HouseholdMember _self;
  final $Res Function(HouseholdMember) _then;

/// Create a copy of HouseholdMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerId = null,Object? memberEmail = null,Object? memberId = freezed,Object? role = null,Object? inviteStatus = null,Object? invitedAt = null,Object? acceptedAt = freezed,Object? createdAt = null,Object? ownerName = freezed,Object? memberName = freezed,Object? memberAvatar = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,memberEmail: null == memberEmail ? _self.memberEmail : memberEmail // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,inviteStatus: null == inviteStatus ? _self.inviteStatus : inviteStatus // ignore: cast_nullable_to_non_nullable
as String,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,memberName: freezed == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String?,memberAvatar: freezed == memberAvatar ? _self.memberAvatar : memberAvatar // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [HouseholdMember].
extension HouseholdMemberPatterns on HouseholdMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HouseholdMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HouseholdMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HouseholdMember value)  $default,){
final _that = this;
switch (_that) {
case _HouseholdMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HouseholdMember value)?  $default,){
final _that = this;
switch (_that) {
case _HouseholdMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'owner_id')  String ownerId, @JsonKey(name: 'member_email')  String memberEmail, @JsonKey(name: 'member_id')  String? memberId,  String role, @JsonKey(name: 'invite_status')  String inviteStatus, @JsonKey(name: 'invited_at')  DateTime invitedAt, @JsonKey(name: 'accepted_at')  DateTime? acceptedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'owner_name')  String? ownerName, @JsonKey(name: 'member_name')  String? memberName, @JsonKey(name: 'member_avatar')  String? memberAvatar)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HouseholdMember() when $default != null:
return $default(_that.id,_that.ownerId,_that.memberEmail,_that.memberId,_that.role,_that.inviteStatus,_that.invitedAt,_that.acceptedAt,_that.createdAt,_that.ownerName,_that.memberName,_that.memberAvatar);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'owner_id')  String ownerId, @JsonKey(name: 'member_email')  String memberEmail, @JsonKey(name: 'member_id')  String? memberId,  String role, @JsonKey(name: 'invite_status')  String inviteStatus, @JsonKey(name: 'invited_at')  DateTime invitedAt, @JsonKey(name: 'accepted_at')  DateTime? acceptedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'owner_name')  String? ownerName, @JsonKey(name: 'member_name')  String? memberName, @JsonKey(name: 'member_avatar')  String? memberAvatar)  $default,) {final _that = this;
switch (_that) {
case _HouseholdMember():
return $default(_that.id,_that.ownerId,_that.memberEmail,_that.memberId,_that.role,_that.inviteStatus,_that.invitedAt,_that.acceptedAt,_that.createdAt,_that.ownerName,_that.memberName,_that.memberAvatar);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'owner_id')  String ownerId, @JsonKey(name: 'member_email')  String memberEmail, @JsonKey(name: 'member_id')  String? memberId,  String role, @JsonKey(name: 'invite_status')  String inviteStatus, @JsonKey(name: 'invited_at')  DateTime invitedAt, @JsonKey(name: 'accepted_at')  DateTime? acceptedAt, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'owner_name')  String? ownerName, @JsonKey(name: 'member_name')  String? memberName, @JsonKey(name: 'member_avatar')  String? memberAvatar)?  $default,) {final _that = this;
switch (_that) {
case _HouseholdMember() when $default != null:
return $default(_that.id,_that.ownerId,_that.memberEmail,_that.memberId,_that.role,_that.inviteStatus,_that.invitedAt,_that.acceptedAt,_that.createdAt,_that.ownerName,_that.memberName,_that.memberAvatar);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HouseholdMember implements HouseholdMember {
  const _HouseholdMember({required this.id, @JsonKey(name: 'owner_id') required this.ownerId, @JsonKey(name: 'member_email') required this.memberEmail, @JsonKey(name: 'member_id') this.memberId, required this.role, @JsonKey(name: 'invite_status') required this.inviteStatus, @JsonKey(name: 'invited_at') required this.invitedAt, @JsonKey(name: 'accepted_at') this.acceptedAt, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'owner_name') this.ownerName, @JsonKey(name: 'member_name') this.memberName, @JsonKey(name: 'member_avatar') this.memberAvatar});
  factory _HouseholdMember.fromJson(Map<String, dynamic> json) => _$HouseholdMemberFromJson(json);

@override final  String id;
@override@JsonKey(name: 'owner_id') final  String ownerId;
@override@JsonKey(name: 'member_email') final  String memberEmail;
@override@JsonKey(name: 'member_id') final  String? memberId;
@override final  String role;
@override@JsonKey(name: 'invite_status') final  String inviteStatus;
@override@JsonKey(name: 'invited_at') final  DateTime invitedAt;
@override@JsonKey(name: 'accepted_at') final  DateTime? acceptedAt;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'owner_name') final  String? ownerName;
@override@JsonKey(name: 'member_name') final  String? memberName;
@override@JsonKey(name: 'member_avatar') final  String? memberAvatar;

/// Create a copy of HouseholdMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HouseholdMemberCopyWith<_HouseholdMember> get copyWith => __$HouseholdMemberCopyWithImpl<_HouseholdMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HouseholdMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HouseholdMember&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.memberEmail, memberEmail) || other.memberEmail == memberEmail)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteStatus, inviteStatus) || other.inviteStatus == inviteStatus)&&(identical(other.invitedAt, invitedAt) || other.invitedAt == invitedAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.memberAvatar, memberAvatar) || other.memberAvatar == memberAvatar));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerId,memberEmail,memberId,role,inviteStatus,invitedAt,acceptedAt,createdAt,ownerName,memberName,memberAvatar);

@override
String toString() {
  return 'HouseholdMember(id: $id, ownerId: $ownerId, memberEmail: $memberEmail, memberId: $memberId, role: $role, inviteStatus: $inviteStatus, invitedAt: $invitedAt, acceptedAt: $acceptedAt, createdAt: $createdAt, ownerName: $ownerName, memberName: $memberName, memberAvatar: $memberAvatar)';
}


}

/// @nodoc
abstract mixin class _$HouseholdMemberCopyWith<$Res> implements $HouseholdMemberCopyWith<$Res> {
  factory _$HouseholdMemberCopyWith(_HouseholdMember value, $Res Function(_HouseholdMember) _then) = __$HouseholdMemberCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'owner_id') String ownerId,@JsonKey(name: 'member_email') String memberEmail,@JsonKey(name: 'member_id') String? memberId, String role,@JsonKey(name: 'invite_status') String inviteStatus,@JsonKey(name: 'invited_at') DateTime invitedAt,@JsonKey(name: 'accepted_at') DateTime? acceptedAt,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'owner_name') String? ownerName,@JsonKey(name: 'member_name') String? memberName,@JsonKey(name: 'member_avatar') String? memberAvatar
});




}
/// @nodoc
class __$HouseholdMemberCopyWithImpl<$Res>
    implements _$HouseholdMemberCopyWith<$Res> {
  __$HouseholdMemberCopyWithImpl(this._self, this._then);

  final _HouseholdMember _self;
  final $Res Function(_HouseholdMember) _then;

/// Create a copy of HouseholdMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerId = null,Object? memberEmail = null,Object? memberId = freezed,Object? role = null,Object? inviteStatus = null,Object? invitedAt = null,Object? acceptedAt = freezed,Object? createdAt = null,Object? ownerName = freezed,Object? memberName = freezed,Object? memberAvatar = freezed,}) {
  return _then(_HouseholdMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,memberEmail: null == memberEmail ? _self.memberEmail : memberEmail // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,inviteStatus: null == inviteStatus ? _self.inviteStatus : inviteStatus // ignore: cast_nullable_to_non_nullable
as String,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,memberName: freezed == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String?,memberAvatar: freezed == memberAvatar ? _self.memberAvatar : memberAvatar // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
