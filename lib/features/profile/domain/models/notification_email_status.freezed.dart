// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_email_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationEmailStatus {

 String? get accountEmail; bool get accountEmailVerified; String? get currentEmail; String? get alternateEmail; String? get pendingEmail;
/// Create a copy of NotificationEmailStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationEmailStatusCopyWith<NotificationEmailStatus> get copyWith => _$NotificationEmailStatusCopyWithImpl<NotificationEmailStatus>(this as NotificationEmailStatus, _$identity);

  /// Serializes this NotificationEmailStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationEmailStatus&&(identical(other.accountEmail, accountEmail) || other.accountEmail == accountEmail)&&(identical(other.accountEmailVerified, accountEmailVerified) || other.accountEmailVerified == accountEmailVerified)&&(identical(other.currentEmail, currentEmail) || other.currentEmail == currentEmail)&&(identical(other.alternateEmail, alternateEmail) || other.alternateEmail == alternateEmail)&&(identical(other.pendingEmail, pendingEmail) || other.pendingEmail == pendingEmail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountEmail,accountEmailVerified,currentEmail,alternateEmail,pendingEmail);

@override
String toString() {
  return 'NotificationEmailStatus(accountEmail: $accountEmail, accountEmailVerified: $accountEmailVerified, currentEmail: $currentEmail, alternateEmail: $alternateEmail, pendingEmail: $pendingEmail)';
}


}

/// @nodoc
abstract mixin class $NotificationEmailStatusCopyWith<$Res>  {
  factory $NotificationEmailStatusCopyWith(NotificationEmailStatus value, $Res Function(NotificationEmailStatus) _then) = _$NotificationEmailStatusCopyWithImpl;
@useResult
$Res call({
 String? accountEmail, bool accountEmailVerified, String? currentEmail, String? alternateEmail, String? pendingEmail
});




}
/// @nodoc
class _$NotificationEmailStatusCopyWithImpl<$Res>
    implements $NotificationEmailStatusCopyWith<$Res> {
  _$NotificationEmailStatusCopyWithImpl(this._self, this._then);

  final NotificationEmailStatus _self;
  final $Res Function(NotificationEmailStatus) _then;

/// Create a copy of NotificationEmailStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountEmail = freezed,Object? accountEmailVerified = null,Object? currentEmail = freezed,Object? alternateEmail = freezed,Object? pendingEmail = freezed,}) {
  return _then(_self.copyWith(
accountEmail: freezed == accountEmail ? _self.accountEmail : accountEmail // ignore: cast_nullable_to_non_nullable
as String?,accountEmailVerified: null == accountEmailVerified ? _self.accountEmailVerified : accountEmailVerified // ignore: cast_nullable_to_non_nullable
as bool,currentEmail: freezed == currentEmail ? _self.currentEmail : currentEmail // ignore: cast_nullable_to_non_nullable
as String?,alternateEmail: freezed == alternateEmail ? _self.alternateEmail : alternateEmail // ignore: cast_nullable_to_non_nullable
as String?,pendingEmail: freezed == pendingEmail ? _self.pendingEmail : pendingEmail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationEmailStatus].
extension NotificationEmailStatusPatterns on NotificationEmailStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationEmailStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationEmailStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationEmailStatus value)  $default,){
final _that = this;
switch (_that) {
case _NotificationEmailStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationEmailStatus value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationEmailStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? accountEmail,  bool accountEmailVerified,  String? currentEmail,  String? alternateEmail,  String? pendingEmail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationEmailStatus() when $default != null:
return $default(_that.accountEmail,_that.accountEmailVerified,_that.currentEmail,_that.alternateEmail,_that.pendingEmail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? accountEmail,  bool accountEmailVerified,  String? currentEmail,  String? alternateEmail,  String? pendingEmail)  $default,) {final _that = this;
switch (_that) {
case _NotificationEmailStatus():
return $default(_that.accountEmail,_that.accountEmailVerified,_that.currentEmail,_that.alternateEmail,_that.pendingEmail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? accountEmail,  bool accountEmailVerified,  String? currentEmail,  String? alternateEmail,  String? pendingEmail)?  $default,) {final _that = this;
switch (_that) {
case _NotificationEmailStatus() when $default != null:
return $default(_that.accountEmail,_that.accountEmailVerified,_that.currentEmail,_that.alternateEmail,_that.pendingEmail);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _NotificationEmailStatus implements NotificationEmailStatus {
  const _NotificationEmailStatus({this.accountEmail, this.accountEmailVerified = false, this.currentEmail, this.alternateEmail, this.pendingEmail});
  factory _NotificationEmailStatus.fromJson(Map<String, dynamic> json) => _$NotificationEmailStatusFromJson(json);

@override final  String? accountEmail;
@override@JsonKey() final  bool accountEmailVerified;
@override final  String? currentEmail;
@override final  String? alternateEmail;
@override final  String? pendingEmail;

/// Create a copy of NotificationEmailStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationEmailStatusCopyWith<_NotificationEmailStatus> get copyWith => __$NotificationEmailStatusCopyWithImpl<_NotificationEmailStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationEmailStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationEmailStatus&&(identical(other.accountEmail, accountEmail) || other.accountEmail == accountEmail)&&(identical(other.accountEmailVerified, accountEmailVerified) || other.accountEmailVerified == accountEmailVerified)&&(identical(other.currentEmail, currentEmail) || other.currentEmail == currentEmail)&&(identical(other.alternateEmail, alternateEmail) || other.alternateEmail == alternateEmail)&&(identical(other.pendingEmail, pendingEmail) || other.pendingEmail == pendingEmail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountEmail,accountEmailVerified,currentEmail,alternateEmail,pendingEmail);

@override
String toString() {
  return 'NotificationEmailStatus(accountEmail: $accountEmail, accountEmailVerified: $accountEmailVerified, currentEmail: $currentEmail, alternateEmail: $alternateEmail, pendingEmail: $pendingEmail)';
}


}

/// @nodoc
abstract mixin class _$NotificationEmailStatusCopyWith<$Res> implements $NotificationEmailStatusCopyWith<$Res> {
  factory _$NotificationEmailStatusCopyWith(_NotificationEmailStatus value, $Res Function(_NotificationEmailStatus) _then) = __$NotificationEmailStatusCopyWithImpl;
@override @useResult
$Res call({
 String? accountEmail, bool accountEmailVerified, String? currentEmail, String? alternateEmail, String? pendingEmail
});




}
/// @nodoc
class __$NotificationEmailStatusCopyWithImpl<$Res>
    implements _$NotificationEmailStatusCopyWith<$Res> {
  __$NotificationEmailStatusCopyWithImpl(this._self, this._then);

  final _NotificationEmailStatus _self;
  final $Res Function(_NotificationEmailStatus) _then;

/// Create a copy of NotificationEmailStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountEmail = freezed,Object? accountEmailVerified = null,Object? currentEmail = freezed,Object? alternateEmail = freezed,Object? pendingEmail = freezed,}) {
  return _then(_NotificationEmailStatus(
accountEmail: freezed == accountEmail ? _self.accountEmail : accountEmail // ignore: cast_nullable_to_non_nullable
as String?,accountEmailVerified: null == accountEmailVerified ? _self.accountEmailVerified : accountEmailVerified // ignore: cast_nullable_to_non_nullable
as bool,currentEmail: freezed == currentEmail ? _self.currentEmail : currentEmail // ignore: cast_nullable_to_non_nullable
as String?,alternateEmail: freezed == alternateEmail ? _self.alternateEmail : alternateEmail // ignore: cast_nullable_to_non_nullable
as String?,pendingEmail: freezed == pendingEmail ? _self.pendingEmail : pendingEmail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
