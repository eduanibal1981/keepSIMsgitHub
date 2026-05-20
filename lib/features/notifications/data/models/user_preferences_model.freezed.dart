// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_preferences_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserPreferences {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'quiet_hours_start') String? get quietHoursStart;@JsonKey(name: 'quiet_hours_end') String? get quietHoursEnd;@JsonKey(name: 'weekly_digest_enabled') bool get weeklyDigestEnabled;@JsonKey(name: 'travel_mode_enabled') bool get travelModeEnabled;@JsonKey(name: 'biometric_enabled') bool get biometricEnabled;@JsonKey(name: 'transaction_pin_hash') String? get transactionPinHash; String get theme; String get language;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPreferencesCopyWith<UserPreferences> get copyWith => _$UserPreferencesCopyWithImpl<UserPreferences>(this as UserPreferences, _$identity);

  /// Serializes this UserPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPreferences&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.quietHoursStart, quietHoursStart) || other.quietHoursStart == quietHoursStart)&&(identical(other.quietHoursEnd, quietHoursEnd) || other.quietHoursEnd == quietHoursEnd)&&(identical(other.weeklyDigestEnabled, weeklyDigestEnabled) || other.weeklyDigestEnabled == weeklyDigestEnabled)&&(identical(other.travelModeEnabled, travelModeEnabled) || other.travelModeEnabled == travelModeEnabled)&&(identical(other.biometricEnabled, biometricEnabled) || other.biometricEnabled == biometricEnabled)&&(identical(other.transactionPinHash, transactionPinHash) || other.transactionPinHash == transactionPinHash)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,quietHoursStart,quietHoursEnd,weeklyDigestEnabled,travelModeEnabled,biometricEnabled,transactionPinHash,theme,language,createdAt,updatedAt);

@override
String toString() {
  return 'UserPreferences(id: $id, userId: $userId, quietHoursStart: $quietHoursStart, quietHoursEnd: $quietHoursEnd, weeklyDigestEnabled: $weeklyDigestEnabled, travelModeEnabled: $travelModeEnabled, biometricEnabled: $biometricEnabled, transactionPinHash: $transactionPinHash, theme: $theme, language: $language, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $UserPreferencesCopyWith<$Res>  {
  factory $UserPreferencesCopyWith(UserPreferences value, $Res Function(UserPreferences) _then) = _$UserPreferencesCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'quiet_hours_start') String? quietHoursStart,@JsonKey(name: 'quiet_hours_end') String? quietHoursEnd,@JsonKey(name: 'weekly_digest_enabled') bool weeklyDigestEnabled,@JsonKey(name: 'travel_mode_enabled') bool travelModeEnabled,@JsonKey(name: 'biometric_enabled') bool biometricEnabled,@JsonKey(name: 'transaction_pin_hash') String? transactionPinHash, String theme, String language,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$UserPreferencesCopyWithImpl<$Res>
    implements $UserPreferencesCopyWith<$Res> {
  _$UserPreferencesCopyWithImpl(this._self, this._then);

  final UserPreferences _self;
  final $Res Function(UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? quietHoursStart = freezed,Object? quietHoursEnd = freezed,Object? weeklyDigestEnabled = null,Object? travelModeEnabled = null,Object? biometricEnabled = null,Object? transactionPinHash = freezed,Object? theme = null,Object? language = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,quietHoursStart: freezed == quietHoursStart ? _self.quietHoursStart : quietHoursStart // ignore: cast_nullable_to_non_nullable
as String?,quietHoursEnd: freezed == quietHoursEnd ? _self.quietHoursEnd : quietHoursEnd // ignore: cast_nullable_to_non_nullable
as String?,weeklyDigestEnabled: null == weeklyDigestEnabled ? _self.weeklyDigestEnabled : weeklyDigestEnabled // ignore: cast_nullable_to_non_nullable
as bool,travelModeEnabled: null == travelModeEnabled ? _self.travelModeEnabled : travelModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,biometricEnabled: null == biometricEnabled ? _self.biometricEnabled : biometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,transactionPinHash: freezed == transactionPinHash ? _self.transactionPinHash : transactionPinHash // ignore: cast_nullable_to_non_nullable
as String?,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPreferences].
extension UserPreferencesPatterns on UserPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPreferences value)  $default,){
final _that = this;
switch (_that) {
case _UserPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'quiet_hours_start')  String? quietHoursStart, @JsonKey(name: 'quiet_hours_end')  String? quietHoursEnd, @JsonKey(name: 'weekly_digest_enabled')  bool weeklyDigestEnabled, @JsonKey(name: 'travel_mode_enabled')  bool travelModeEnabled, @JsonKey(name: 'biometric_enabled')  bool biometricEnabled, @JsonKey(name: 'transaction_pin_hash')  String? transactionPinHash,  String theme,  String language, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.id,_that.userId,_that.quietHoursStart,_that.quietHoursEnd,_that.weeklyDigestEnabled,_that.travelModeEnabled,_that.biometricEnabled,_that.transactionPinHash,_that.theme,_that.language,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'quiet_hours_start')  String? quietHoursStart, @JsonKey(name: 'quiet_hours_end')  String? quietHoursEnd, @JsonKey(name: 'weekly_digest_enabled')  bool weeklyDigestEnabled, @JsonKey(name: 'travel_mode_enabled')  bool travelModeEnabled, @JsonKey(name: 'biometric_enabled')  bool biometricEnabled, @JsonKey(name: 'transaction_pin_hash')  String? transactionPinHash,  String theme,  String language, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _UserPreferences():
return $default(_that.id,_that.userId,_that.quietHoursStart,_that.quietHoursEnd,_that.weeklyDigestEnabled,_that.travelModeEnabled,_that.biometricEnabled,_that.transactionPinHash,_that.theme,_that.language,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'quiet_hours_start')  String? quietHoursStart, @JsonKey(name: 'quiet_hours_end')  String? quietHoursEnd, @JsonKey(name: 'weekly_digest_enabled')  bool weeklyDigestEnabled, @JsonKey(name: 'travel_mode_enabled')  bool travelModeEnabled, @JsonKey(name: 'biometric_enabled')  bool biometricEnabled, @JsonKey(name: 'transaction_pin_hash')  String? transactionPinHash,  String theme,  String language, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _UserPreferences() when $default != null:
return $default(_that.id,_that.userId,_that.quietHoursStart,_that.quietHoursEnd,_that.weeklyDigestEnabled,_that.travelModeEnabled,_that.biometricEnabled,_that.transactionPinHash,_that.theme,_that.language,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserPreferences implements UserPreferences {
  const _UserPreferences({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'quiet_hours_start') this.quietHoursStart, @JsonKey(name: 'quiet_hours_end') this.quietHoursEnd, @JsonKey(name: 'weekly_digest_enabled') this.weeklyDigestEnabled = true, @JsonKey(name: 'travel_mode_enabled') this.travelModeEnabled = false, @JsonKey(name: 'biometric_enabled') this.biometricEnabled = false, @JsonKey(name: 'transaction_pin_hash') this.transactionPinHash, this.theme = 'system', this.language = 'en', @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _UserPreferences.fromJson(Map<String, dynamic> json) => _$UserPreferencesFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'quiet_hours_start') final  String? quietHoursStart;
@override@JsonKey(name: 'quiet_hours_end') final  String? quietHoursEnd;
@override@JsonKey(name: 'weekly_digest_enabled') final  bool weeklyDigestEnabled;
@override@JsonKey(name: 'travel_mode_enabled') final  bool travelModeEnabled;
@override@JsonKey(name: 'biometric_enabled') final  bool biometricEnabled;
@override@JsonKey(name: 'transaction_pin_hash') final  String? transactionPinHash;
@override@JsonKey() final  String theme;
@override@JsonKey() final  String language;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPreferencesCopyWith<_UserPreferences> get copyWith => __$UserPreferencesCopyWithImpl<_UserPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPreferences&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.quietHoursStart, quietHoursStart) || other.quietHoursStart == quietHoursStart)&&(identical(other.quietHoursEnd, quietHoursEnd) || other.quietHoursEnd == quietHoursEnd)&&(identical(other.weeklyDigestEnabled, weeklyDigestEnabled) || other.weeklyDigestEnabled == weeklyDigestEnabled)&&(identical(other.travelModeEnabled, travelModeEnabled) || other.travelModeEnabled == travelModeEnabled)&&(identical(other.biometricEnabled, biometricEnabled) || other.biometricEnabled == biometricEnabled)&&(identical(other.transactionPinHash, transactionPinHash) || other.transactionPinHash == transactionPinHash)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,quietHoursStart,quietHoursEnd,weeklyDigestEnabled,travelModeEnabled,biometricEnabled,transactionPinHash,theme,language,createdAt,updatedAt);

@override
String toString() {
  return 'UserPreferences(id: $id, userId: $userId, quietHoursStart: $quietHoursStart, quietHoursEnd: $quietHoursEnd, weeklyDigestEnabled: $weeklyDigestEnabled, travelModeEnabled: $travelModeEnabled, biometricEnabled: $biometricEnabled, transactionPinHash: $transactionPinHash, theme: $theme, language: $language, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$UserPreferencesCopyWith<$Res> implements $UserPreferencesCopyWith<$Res> {
  factory _$UserPreferencesCopyWith(_UserPreferences value, $Res Function(_UserPreferences) _then) = __$UserPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'quiet_hours_start') String? quietHoursStart,@JsonKey(name: 'quiet_hours_end') String? quietHoursEnd,@JsonKey(name: 'weekly_digest_enabled') bool weeklyDigestEnabled,@JsonKey(name: 'travel_mode_enabled') bool travelModeEnabled,@JsonKey(name: 'biometric_enabled') bool biometricEnabled,@JsonKey(name: 'transaction_pin_hash') String? transactionPinHash, String theme, String language,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$UserPreferencesCopyWithImpl<$Res>
    implements _$UserPreferencesCopyWith<$Res> {
  __$UserPreferencesCopyWithImpl(this._self, this._then);

  final _UserPreferences _self;
  final $Res Function(_UserPreferences) _then;

/// Create a copy of UserPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? quietHoursStart = freezed,Object? quietHoursEnd = freezed,Object? weeklyDigestEnabled = null,Object? travelModeEnabled = null,Object? biometricEnabled = null,Object? transactionPinHash = freezed,Object? theme = null,Object? language = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_UserPreferences(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,quietHoursStart: freezed == quietHoursStart ? _self.quietHoursStart : quietHoursStart // ignore: cast_nullable_to_non_nullable
as String?,quietHoursEnd: freezed == quietHoursEnd ? _self.quietHoursEnd : quietHoursEnd // ignore: cast_nullable_to_non_nullable
as String?,weeklyDigestEnabled: null == weeklyDigestEnabled ? _self.weeklyDigestEnabled : weeklyDigestEnabled // ignore: cast_nullable_to_non_nullable
as bool,travelModeEnabled: null == travelModeEnabled ? _self.travelModeEnabled : travelModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,biometricEnabled: null == biometricEnabled ? _self.biometricEnabled : biometricEnabled // ignore: cast_nullable_to_non_nullable
as bool,transactionPinHash: freezed == transactionPinHash ? _self.transactionPinHash : transactionPinHash // ignore: cast_nullable_to_non_nullable
as String?,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
