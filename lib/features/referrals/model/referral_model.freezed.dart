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
mixin _$Referral {

 String get id; String get referrerId; String get referredId; String get referralCode; double get rewardAmount; bool get referrerCredited; bool get referredCredited; DateTime? get createdAt;// Joined referred friend's profile details
 UserProfile? get referredProfile;
/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReferralCopyWith<Referral> get copyWith => _$ReferralCopyWithImpl<Referral>(this as Referral, _$identity);

  /// Serializes this Referral to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Referral&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredId, referredId) || other.referredId == referredId)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.referrerCredited, referrerCredited) || other.referrerCredited == referrerCredited)&&(identical(other.referredCredited, referredCredited) || other.referredCredited == referredCredited)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.referredProfile, referredProfile) || other.referredProfile == referredProfile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredId,referralCode,rewardAmount,referrerCredited,referredCredited,createdAt,referredProfile);

@override
String toString() {
  return 'Referral(id: $id, referrerId: $referrerId, referredId: $referredId, referralCode: $referralCode, rewardAmount: $rewardAmount, referrerCredited: $referrerCredited, referredCredited: $referredCredited, createdAt: $createdAt, referredProfile: $referredProfile)';
}


}

/// @nodoc
abstract mixin class $ReferralCopyWith<$Res>  {
  factory $ReferralCopyWith(Referral value, $Res Function(Referral) _then) = _$ReferralCopyWithImpl;
@useResult
$Res call({
 String id, String referrerId, String referredId, String referralCode, double rewardAmount, bool referrerCredited, bool referredCredited, DateTime? createdAt, UserProfile? referredProfile
});


$UserProfileCopyWith<$Res>? get referredProfile;

}
/// @nodoc
class _$ReferralCopyWithImpl<$Res>
    implements $ReferralCopyWith<$Res> {
  _$ReferralCopyWithImpl(this._self, this._then);

  final Referral _self;
  final $Res Function(Referral) _then;

/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? referrerId = null,Object? referredId = null,Object? referralCode = null,Object? rewardAmount = null,Object? referrerCredited = null,Object? referredCredited = null,Object? createdAt = freezed,Object? referredProfile = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredId: null == referredId ? _self.referredId : referredId // ignore: cast_nullable_to_non_nullable
as String,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as double,referrerCredited: null == referrerCredited ? _self.referrerCredited : referrerCredited // ignore: cast_nullable_to_non_nullable
as bool,referredCredited: null == referredCredited ? _self.referredCredited : referredCredited // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,referredProfile: freezed == referredProfile ? _self.referredProfile : referredProfile // ignore: cast_nullable_to_non_nullable
as UserProfile?,
  ));
}
/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res>? get referredProfile {
    if (_self.referredProfile == null) {
    return null;
  }

  return $UserProfileCopyWith<$Res>(_self.referredProfile!, (value) {
    return _then(_self.copyWith(referredProfile: value));
  });
}
}


/// Adds pattern-matching-related methods to [Referral].
extension ReferralPatterns on Referral {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Referral value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Referral() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Referral value)  $default,){
final _that = this;
switch (_that) {
case _Referral():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Referral value)?  $default,){
final _that = this;
switch (_that) {
case _Referral() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredId,  String referralCode,  double rewardAmount,  bool referrerCredited,  bool referredCredited,  DateTime? createdAt,  UserProfile? referredProfile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Referral() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredId,_that.referralCode,_that.rewardAmount,_that.referrerCredited,_that.referredCredited,_that.createdAt,_that.referredProfile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String referrerId,  String referredId,  String referralCode,  double rewardAmount,  bool referrerCredited,  bool referredCredited,  DateTime? createdAt,  UserProfile? referredProfile)  $default,) {final _that = this;
switch (_that) {
case _Referral():
return $default(_that.id,_that.referrerId,_that.referredId,_that.referralCode,_that.rewardAmount,_that.referrerCredited,_that.referredCredited,_that.createdAt,_that.referredProfile);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String referrerId,  String referredId,  String referralCode,  double rewardAmount,  bool referrerCredited,  bool referredCredited,  DateTime? createdAt,  UserProfile? referredProfile)?  $default,) {final _that = this;
switch (_that) {
case _Referral() when $default != null:
return $default(_that.id,_that.referrerId,_that.referredId,_that.referralCode,_that.rewardAmount,_that.referrerCredited,_that.referredCredited,_that.createdAt,_that.referredProfile);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Referral implements Referral {
  const _Referral({required this.id, required this.referrerId, required this.referredId, required this.referralCode, required this.rewardAmount, required this.referrerCredited, required this.referredCredited, this.createdAt, this.referredProfile});
  factory _Referral.fromJson(Map<String, dynamic> json) => _$ReferralFromJson(json);

@override final  String id;
@override final  String referrerId;
@override final  String referredId;
@override final  String referralCode;
@override final  double rewardAmount;
@override final  bool referrerCredited;
@override final  bool referredCredited;
@override final  DateTime? createdAt;
// Joined referred friend's profile details
@override final  UserProfile? referredProfile;

/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReferralCopyWith<_Referral> get copyWith => __$ReferralCopyWithImpl<_Referral>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReferralToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Referral&&(identical(other.id, id) || other.id == id)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referredId, referredId) || other.referredId == referredId)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount)&&(identical(other.referrerCredited, referrerCredited) || other.referrerCredited == referrerCredited)&&(identical(other.referredCredited, referredCredited) || other.referredCredited == referredCredited)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.referredProfile, referredProfile) || other.referredProfile == referredProfile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,referrerId,referredId,referralCode,rewardAmount,referrerCredited,referredCredited,createdAt,referredProfile);

@override
String toString() {
  return 'Referral(id: $id, referrerId: $referrerId, referredId: $referredId, referralCode: $referralCode, rewardAmount: $rewardAmount, referrerCredited: $referrerCredited, referredCredited: $referredCredited, createdAt: $createdAt, referredProfile: $referredProfile)';
}


}

/// @nodoc
abstract mixin class _$ReferralCopyWith<$Res> implements $ReferralCopyWith<$Res> {
  factory _$ReferralCopyWith(_Referral value, $Res Function(_Referral) _then) = __$ReferralCopyWithImpl;
@override @useResult
$Res call({
 String id, String referrerId, String referredId, String referralCode, double rewardAmount, bool referrerCredited, bool referredCredited, DateTime? createdAt, UserProfile? referredProfile
});


@override $UserProfileCopyWith<$Res>? get referredProfile;

}
/// @nodoc
class __$ReferralCopyWithImpl<$Res>
    implements _$ReferralCopyWith<$Res> {
  __$ReferralCopyWithImpl(this._self, this._then);

  final _Referral _self;
  final $Res Function(_Referral) _then;

/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? referrerId = null,Object? referredId = null,Object? referralCode = null,Object? rewardAmount = null,Object? referrerCredited = null,Object? referredCredited = null,Object? createdAt = freezed,Object? referredProfile = freezed,}) {
  return _then(_Referral(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,referrerId: null == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as String,referredId: null == referredId ? _self.referredId : referredId // ignore: cast_nullable_to_non_nullable
as String,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,rewardAmount: null == rewardAmount ? _self.rewardAmount : rewardAmount // ignore: cast_nullable_to_non_nullable
as double,referrerCredited: null == referrerCredited ? _self.referrerCredited : referrerCredited // ignore: cast_nullable_to_non_nullable
as bool,referredCredited: null == referredCredited ? _self.referredCredited : referredCredited // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,referredProfile: freezed == referredProfile ? _self.referredProfile : referredProfile // ignore: cast_nullable_to_non_nullable
as UserProfile?,
  ));
}

/// Create a copy of Referral
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserProfileCopyWith<$Res>? get referredProfile {
    if (_self.referredProfile == null) {
    return null;
  }

  return $UserProfileCopyWith<$Res>(_self.referredProfile!, (value) {
    return _then(_self.copyWith(referredProfile: value));
  });
}
}

// dart format on
