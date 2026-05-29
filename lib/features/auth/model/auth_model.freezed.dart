// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfile {

 String get id; String get email; String? get fullName; String? get avatarUrl; String? get phone; String? get homeCountryCode; String get preferredCurrency; bool get isPowerUser; String? get referralCode; String? get referredBy; bool get onboardingCompleted; String get subscriptionTier; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.homeCountryCode, homeCountryCode) || other.homeCountryCode == homeCountryCode)&&(identical(other.preferredCurrency, preferredCurrency) || other.preferredCurrency == preferredCurrency)&&(identical(other.isPowerUser, isPowerUser) || other.isPowerUser == isPowerUser)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.referredBy, referredBy) || other.referredBy == referredBy)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,fullName,avatarUrl,phone,homeCountryCode,preferredCurrency,isPowerUser,referralCode,referredBy,onboardingCompleted,subscriptionTier,createdAt,updatedAt);

@override
String toString() {
  return 'UserProfile(id: $id, email: $email, fullName: $fullName, avatarUrl: $avatarUrl, phone: $phone, homeCountryCode: $homeCountryCode, preferredCurrency: $preferredCurrency, isPowerUser: $isPowerUser, referralCode: $referralCode, referredBy: $referredBy, onboardingCompleted: $onboardingCompleted, subscriptionTier: $subscriptionTier, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String email, String? fullName, String? avatarUrl, String? phone, String? homeCountryCode, String preferredCurrency, bool isPowerUser, String? referralCode, String? referredBy, bool onboardingCompleted, String subscriptionTier, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? fullName = freezed,Object? avatarUrl = freezed,Object? phone = freezed,Object? homeCountryCode = freezed,Object? preferredCurrency = null,Object? isPowerUser = null,Object? referralCode = freezed,Object? referredBy = freezed,Object? onboardingCompleted = null,Object? subscriptionTier = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,homeCountryCode: freezed == homeCountryCode ? _self.homeCountryCode : homeCountryCode // ignore: cast_nullable_to_non_nullable
as String?,preferredCurrency: null == preferredCurrency ? _self.preferredCurrency : preferredCurrency // ignore: cast_nullable_to_non_nullable
as String,isPowerUser: null == isPowerUser ? _self.isPowerUser : isPowerUser // ignore: cast_nullable_to_non_nullable
as bool,referralCode: freezed == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String?,referredBy: freezed == referredBy ? _self.referredBy : referredBy // ignore: cast_nullable_to_non_nullable
as String?,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  String? fullName,  String? avatarUrl,  String? phone,  String? homeCountryCode,  String preferredCurrency,  bool isPowerUser,  String? referralCode,  String? referredBy,  bool onboardingCompleted,  String subscriptionTier,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.avatarUrl,_that.phone,_that.homeCountryCode,_that.preferredCurrency,_that.isPowerUser,_that.referralCode,_that.referredBy,_that.onboardingCompleted,_that.subscriptionTier,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  String? fullName,  String? avatarUrl,  String? phone,  String? homeCountryCode,  String preferredCurrency,  bool isPowerUser,  String? referralCode,  String? referredBy,  bool onboardingCompleted,  String subscriptionTier,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.email,_that.fullName,_that.avatarUrl,_that.phone,_that.homeCountryCode,_that.preferredCurrency,_that.isPowerUser,_that.referralCode,_that.referredBy,_that.onboardingCompleted,_that.subscriptionTier,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  String? fullName,  String? avatarUrl,  String? phone,  String? homeCountryCode,  String preferredCurrency,  bool isPowerUser,  String? referralCode,  String? referredBy,  bool onboardingCompleted,  String subscriptionTier,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.avatarUrl,_that.phone,_that.homeCountryCode,_that.preferredCurrency,_that.isPowerUser,_that.referralCode,_that.referredBy,_that.onboardingCompleted,_that.subscriptionTier,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _UserProfile implements UserProfile {
  const _UserProfile({this.id = '', this.email = '', this.fullName, this.avatarUrl, this.phone, this.homeCountryCode, this.preferredCurrency = 'USD', this.isPowerUser = false, this.referralCode, this.referredBy, this.onboardingCompleted = false, this.subscriptionTier = 'standard', this.createdAt, this.updatedAt});
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String email;
@override final  String? fullName;
@override final  String? avatarUrl;
@override final  String? phone;
@override final  String? homeCountryCode;
@override@JsonKey() final  String preferredCurrency;
@override@JsonKey() final  bool isPowerUser;
@override final  String? referralCode;
@override final  String? referredBy;
@override@JsonKey() final  bool onboardingCompleted;
@override@JsonKey() final  String subscriptionTier;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.homeCountryCode, homeCountryCode) || other.homeCountryCode == homeCountryCode)&&(identical(other.preferredCurrency, preferredCurrency) || other.preferredCurrency == preferredCurrency)&&(identical(other.isPowerUser, isPowerUser) || other.isPowerUser == isPowerUser)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.referredBy, referredBy) || other.referredBy == referredBy)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,fullName,avatarUrl,phone,homeCountryCode,preferredCurrency,isPowerUser,referralCode,referredBy,onboardingCompleted,subscriptionTier,createdAt,updatedAt);

@override
String toString() {
  return 'UserProfile(id: $id, email: $email, fullName: $fullName, avatarUrl: $avatarUrl, phone: $phone, homeCountryCode: $homeCountryCode, preferredCurrency: $preferredCurrency, isPowerUser: $isPowerUser, referralCode: $referralCode, referredBy: $referredBy, onboardingCompleted: $onboardingCompleted, subscriptionTier: $subscriptionTier, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, String? fullName, String? avatarUrl, String? phone, String? homeCountryCode, String preferredCurrency, bool isPowerUser, String? referralCode, String? referredBy, bool onboardingCompleted, String subscriptionTier, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? fullName = freezed,Object? avatarUrl = freezed,Object? phone = freezed,Object? homeCountryCode = freezed,Object? preferredCurrency = null,Object? isPowerUser = null,Object? referralCode = freezed,Object? referredBy = freezed,Object? onboardingCompleted = null,Object? subscriptionTier = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: freezed == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,homeCountryCode: freezed == homeCountryCode ? _self.homeCountryCode : homeCountryCode // ignore: cast_nullable_to_non_nullable
as String?,preferredCurrency: null == preferredCurrency ? _self.preferredCurrency : preferredCurrency // ignore: cast_nullable_to_non_nullable
as String,isPowerUser: null == isPowerUser ? _self.isPowerUser : isPowerUser // ignore: cast_nullable_to_non_nullable
as bool,referralCode: freezed == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String?,referredBy: freezed == referredBy ? _self.referredBy : referredBy // ignore: cast_nullable_to_non_nullable
as String?,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
