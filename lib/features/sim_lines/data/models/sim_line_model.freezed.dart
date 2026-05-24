// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sim_line_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SimLine {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'phone_number') String get phoneNumber; String? get nickname;@JsonKey(name: 'avatar_icon') String get avatarIcon;@JsonKey(name: 'country_id') String? get countryId;@JsonKey(name: 'carrier_id') String? get carrierId;@JsonKey(name: 'carrier_rule_id') String? get carrierRuleId; String get status;@JsonKey(name: 'verification_status') String get verificationStatus;@JsonKey(name: 'health_score') int get healthScore;@JsonKey(name: 'last_topup_at') DateTime? get lastTopupAt;@JsonKey(name: 'next_topup_due') DateTime? get nextTopupDue;@JsonKey(name: 'validity_expires_at') DateTime? get validityExpiresAt;@JsonKey(name: 'protection_tier') String get protectionTier;@JsonKey(name: 'is_auto_detected') bool get isAutoDetected;@JsonKey(name: 'is_home_mode') bool get isHomeMode;@JsonKey(name: 'household_id') String? get householdId;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of SimLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimLineCopyWith<SimLine> get copyWith => _$SimLineCopyWithImpl<SimLine>(this as SimLine, _$identity);

  /// Serializes this SimLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimLine&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.avatarIcon, avatarIcon) || other.avatarIcon == avatarIcon)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierRuleId, carrierRuleId) || other.carrierRuleId == carrierRuleId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.healthScore, healthScore) || other.healthScore == healthScore)&&(identical(other.lastTopupAt, lastTopupAt) || other.lastTopupAt == lastTopupAt)&&(identical(other.nextTopupDue, nextTopupDue) || other.nextTopupDue == nextTopupDue)&&(identical(other.validityExpiresAt, validityExpiresAt) || other.validityExpiresAt == validityExpiresAt)&&(identical(other.protectionTier, protectionTier) || other.protectionTier == protectionTier)&&(identical(other.isAutoDetected, isAutoDetected) || other.isAutoDetected == isAutoDetected)&&(identical(other.isHomeMode, isHomeMode) || other.isHomeMode == isHomeMode)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,phoneNumber,nickname,avatarIcon,countryId,carrierId,carrierRuleId,status,verificationStatus,healthScore,lastTopupAt,nextTopupDue,validityExpiresAt,protectionTier,isAutoDetected,isHomeMode,householdId,createdAt,updatedAt]);

@override
String toString() {
  return 'SimLine(id: $id, userId: $userId, phoneNumber: $phoneNumber, nickname: $nickname, avatarIcon: $avatarIcon, countryId: $countryId, carrierId: $carrierId, carrierRuleId: $carrierRuleId, status: $status, verificationStatus: $verificationStatus, healthScore: $healthScore, lastTopupAt: $lastTopupAt, nextTopupDue: $nextTopupDue, validityExpiresAt: $validityExpiresAt, protectionTier: $protectionTier, isAutoDetected: $isAutoDetected, isHomeMode: $isHomeMode, householdId: $householdId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SimLineCopyWith<$Res>  {
  factory $SimLineCopyWith(SimLine value, $Res Function(SimLine) _then) = _$SimLineCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'phone_number') String phoneNumber, String? nickname,@JsonKey(name: 'avatar_icon') String avatarIcon,@JsonKey(name: 'country_id') String? countryId,@JsonKey(name: 'carrier_id') String? carrierId,@JsonKey(name: 'carrier_rule_id') String? carrierRuleId, String status,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'health_score') int healthScore,@JsonKey(name: 'last_topup_at') DateTime? lastTopupAt,@JsonKey(name: 'next_topup_due') DateTime? nextTopupDue,@JsonKey(name: 'validity_expires_at') DateTime? validityExpiresAt,@JsonKey(name: 'protection_tier') String protectionTier,@JsonKey(name: 'is_auto_detected') bool isAutoDetected,@JsonKey(name: 'is_home_mode') bool isHomeMode,@JsonKey(name: 'household_id') String? householdId,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$SimLineCopyWithImpl<$Res>
    implements $SimLineCopyWith<$Res> {
  _$SimLineCopyWithImpl(this._self, this._then);

  final SimLine _self;
  final $Res Function(SimLine) _then;

/// Create a copy of SimLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? phoneNumber = null,Object? nickname = freezed,Object? avatarIcon = null,Object? countryId = freezed,Object? carrierId = freezed,Object? carrierRuleId = freezed,Object? status = null,Object? verificationStatus = null,Object? healthScore = null,Object? lastTopupAt = freezed,Object? nextTopupDue = freezed,Object? validityExpiresAt = freezed,Object? protectionTier = null,Object? isAutoDetected = null,Object? isHomeMode = null,Object? householdId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,avatarIcon: null == avatarIcon ? _self.avatarIcon : avatarIcon // ignore: cast_nullable_to_non_nullable
as String,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String?,carrierId: freezed == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String?,carrierRuleId: freezed == carrierRuleId ? _self.carrierRuleId : carrierRuleId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,healthScore: null == healthScore ? _self.healthScore : healthScore // ignore: cast_nullable_to_non_nullable
as int,lastTopupAt: freezed == lastTopupAt ? _self.lastTopupAt : lastTopupAt // ignore: cast_nullable_to_non_nullable
as DateTime?,nextTopupDue: freezed == nextTopupDue ? _self.nextTopupDue : nextTopupDue // ignore: cast_nullable_to_non_nullable
as DateTime?,validityExpiresAt: freezed == validityExpiresAt ? _self.validityExpiresAt : validityExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,protectionTier: null == protectionTier ? _self.protectionTier : protectionTier // ignore: cast_nullable_to_non_nullable
as String,isAutoDetected: null == isAutoDetected ? _self.isAutoDetected : isAutoDetected // ignore: cast_nullable_to_non_nullable
as bool,isHomeMode: null == isHomeMode ? _self.isHomeMode : isHomeMode // ignore: cast_nullable_to_non_nullable
as bool,householdId: freezed == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SimLine].
extension SimLinePatterns on SimLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimLine value)  $default,){
final _that = this;
switch (_that) {
case _SimLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimLine value)?  $default,){
final _that = this;
switch (_that) {
case _SimLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'avatar_icon')  String avatarIcon, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_rule_id')  String? carrierRuleId,  String status, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'health_score')  int healthScore, @JsonKey(name: 'last_topup_at')  DateTime? lastTopupAt, @JsonKey(name: 'next_topup_due')  DateTime? nextTopupDue, @JsonKey(name: 'validity_expires_at')  DateTime? validityExpiresAt, @JsonKey(name: 'protection_tier')  String protectionTier, @JsonKey(name: 'is_auto_detected')  bool isAutoDetected, @JsonKey(name: 'is_home_mode')  bool isHomeMode, @JsonKey(name: 'household_id')  String? householdId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimLine() when $default != null:
return $default(_that.id,_that.userId,_that.phoneNumber,_that.nickname,_that.avatarIcon,_that.countryId,_that.carrierId,_that.carrierRuleId,_that.status,_that.verificationStatus,_that.healthScore,_that.lastTopupAt,_that.nextTopupDue,_that.validityExpiresAt,_that.protectionTier,_that.isAutoDetected,_that.isHomeMode,_that.householdId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'avatar_icon')  String avatarIcon, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_rule_id')  String? carrierRuleId,  String status, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'health_score')  int healthScore, @JsonKey(name: 'last_topup_at')  DateTime? lastTopupAt, @JsonKey(name: 'next_topup_due')  DateTime? nextTopupDue, @JsonKey(name: 'validity_expires_at')  DateTime? validityExpiresAt, @JsonKey(name: 'protection_tier')  String protectionTier, @JsonKey(name: 'is_auto_detected')  bool isAutoDetected, @JsonKey(name: 'is_home_mode')  bool isHomeMode, @JsonKey(name: 'household_id')  String? householdId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SimLine():
return $default(_that.id,_that.userId,_that.phoneNumber,_that.nickname,_that.avatarIcon,_that.countryId,_that.carrierId,_that.carrierRuleId,_that.status,_that.verificationStatus,_that.healthScore,_that.lastTopupAt,_that.nextTopupDue,_that.validityExpiresAt,_that.protectionTier,_that.isAutoDetected,_that.isHomeMode,_that.householdId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'avatar_icon')  String avatarIcon, @JsonKey(name: 'country_id')  String? countryId, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_rule_id')  String? carrierRuleId,  String status, @JsonKey(name: 'verification_status')  String verificationStatus, @JsonKey(name: 'health_score')  int healthScore, @JsonKey(name: 'last_topup_at')  DateTime? lastTopupAt, @JsonKey(name: 'next_topup_due')  DateTime? nextTopupDue, @JsonKey(name: 'validity_expires_at')  DateTime? validityExpiresAt, @JsonKey(name: 'protection_tier')  String protectionTier, @JsonKey(name: 'is_auto_detected')  bool isAutoDetected, @JsonKey(name: 'is_home_mode')  bool isHomeMode, @JsonKey(name: 'household_id')  String? householdId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SimLine() when $default != null:
return $default(_that.id,_that.userId,_that.phoneNumber,_that.nickname,_that.avatarIcon,_that.countryId,_that.carrierId,_that.carrierRuleId,_that.status,_that.verificationStatus,_that.healthScore,_that.lastTopupAt,_that.nextTopupDue,_that.validityExpiresAt,_that.protectionTier,_that.isAutoDetected,_that.isHomeMode,_that.householdId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimLine implements SimLine {
  const _SimLine({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'phone_number') required this.phoneNumber, this.nickname, @JsonKey(name: 'avatar_icon') this.avatarIcon = 'sim_card', @JsonKey(name: 'country_id') this.countryId, @JsonKey(name: 'carrier_id') this.carrierId, @JsonKey(name: 'carrier_rule_id') this.carrierRuleId, this.status = 'active', @JsonKey(name: 'verification_status') this.verificationStatus = 'unverified', @JsonKey(name: 'health_score') this.healthScore = 100, @JsonKey(name: 'last_topup_at') this.lastTopupAt, @JsonKey(name: 'next_topup_due') this.nextTopupDue, @JsonKey(name: 'validity_expires_at') this.validityExpiresAt, @JsonKey(name: 'protection_tier') this.protectionTier = 'standard', @JsonKey(name: 'is_auto_detected') this.isAutoDetected = false, @JsonKey(name: 'is_home_mode') this.isHomeMode = false, @JsonKey(name: 'household_id') this.householdId, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _SimLine.fromJson(Map<String, dynamic> json) => _$SimLineFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override final  String? nickname;
@override@JsonKey(name: 'avatar_icon') final  String avatarIcon;
@override@JsonKey(name: 'country_id') final  String? countryId;
@override@JsonKey(name: 'carrier_id') final  String? carrierId;
@override@JsonKey(name: 'carrier_rule_id') final  String? carrierRuleId;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'verification_status') final  String verificationStatus;
@override@JsonKey(name: 'health_score') final  int healthScore;
@override@JsonKey(name: 'last_topup_at') final  DateTime? lastTopupAt;
@override@JsonKey(name: 'next_topup_due') final  DateTime? nextTopupDue;
@override@JsonKey(name: 'validity_expires_at') final  DateTime? validityExpiresAt;
@override@JsonKey(name: 'protection_tier') final  String protectionTier;
@override@JsonKey(name: 'is_auto_detected') final  bool isAutoDetected;
@override@JsonKey(name: 'is_home_mode') final  bool isHomeMode;
@override@JsonKey(name: 'household_id') final  String? householdId;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of SimLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimLineCopyWith<_SimLine> get copyWith => __$SimLineCopyWithImpl<_SimLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimLine&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.avatarIcon, avatarIcon) || other.avatarIcon == avatarIcon)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierRuleId, carrierRuleId) || other.carrierRuleId == carrierRuleId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.healthScore, healthScore) || other.healthScore == healthScore)&&(identical(other.lastTopupAt, lastTopupAt) || other.lastTopupAt == lastTopupAt)&&(identical(other.nextTopupDue, nextTopupDue) || other.nextTopupDue == nextTopupDue)&&(identical(other.validityExpiresAt, validityExpiresAt) || other.validityExpiresAt == validityExpiresAt)&&(identical(other.protectionTier, protectionTier) || other.protectionTier == protectionTier)&&(identical(other.isAutoDetected, isAutoDetected) || other.isAutoDetected == isAutoDetected)&&(identical(other.isHomeMode, isHomeMode) || other.isHomeMode == isHomeMode)&&(identical(other.householdId, householdId) || other.householdId == householdId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,phoneNumber,nickname,avatarIcon,countryId,carrierId,carrierRuleId,status,verificationStatus,healthScore,lastTopupAt,nextTopupDue,validityExpiresAt,protectionTier,isAutoDetected,isHomeMode,householdId,createdAt,updatedAt]);

@override
String toString() {
  return 'SimLine(id: $id, userId: $userId, phoneNumber: $phoneNumber, nickname: $nickname, avatarIcon: $avatarIcon, countryId: $countryId, carrierId: $carrierId, carrierRuleId: $carrierRuleId, status: $status, verificationStatus: $verificationStatus, healthScore: $healthScore, lastTopupAt: $lastTopupAt, nextTopupDue: $nextTopupDue, validityExpiresAt: $validityExpiresAt, protectionTier: $protectionTier, isAutoDetected: $isAutoDetected, isHomeMode: $isHomeMode, householdId: $householdId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SimLineCopyWith<$Res> implements $SimLineCopyWith<$Res> {
  factory _$SimLineCopyWith(_SimLine value, $Res Function(_SimLine) _then) = __$SimLineCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'phone_number') String phoneNumber, String? nickname,@JsonKey(name: 'avatar_icon') String avatarIcon,@JsonKey(name: 'country_id') String? countryId,@JsonKey(name: 'carrier_id') String? carrierId,@JsonKey(name: 'carrier_rule_id') String? carrierRuleId, String status,@JsonKey(name: 'verification_status') String verificationStatus,@JsonKey(name: 'health_score') int healthScore,@JsonKey(name: 'last_topup_at') DateTime? lastTopupAt,@JsonKey(name: 'next_topup_due') DateTime? nextTopupDue,@JsonKey(name: 'validity_expires_at') DateTime? validityExpiresAt,@JsonKey(name: 'protection_tier') String protectionTier,@JsonKey(name: 'is_auto_detected') bool isAutoDetected,@JsonKey(name: 'is_home_mode') bool isHomeMode,@JsonKey(name: 'household_id') String? householdId,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$SimLineCopyWithImpl<$Res>
    implements _$SimLineCopyWith<$Res> {
  __$SimLineCopyWithImpl(this._self, this._then);

  final _SimLine _self;
  final $Res Function(_SimLine) _then;

/// Create a copy of SimLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? phoneNumber = null,Object? nickname = freezed,Object? avatarIcon = null,Object? countryId = freezed,Object? carrierId = freezed,Object? carrierRuleId = freezed,Object? status = null,Object? verificationStatus = null,Object? healthScore = null,Object? lastTopupAt = freezed,Object? nextTopupDue = freezed,Object? validityExpiresAt = freezed,Object? protectionTier = null,Object? isAutoDetected = null,Object? isHomeMode = null,Object? householdId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_SimLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,avatarIcon: null == avatarIcon ? _self.avatarIcon : avatarIcon // ignore: cast_nullable_to_non_nullable
as String,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String?,carrierId: freezed == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String?,carrierRuleId: freezed == carrierRuleId ? _self.carrierRuleId : carrierRuleId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,healthScore: null == healthScore ? _self.healthScore : healthScore // ignore: cast_nullable_to_non_nullable
as int,lastTopupAt: freezed == lastTopupAt ? _self.lastTopupAt : lastTopupAt // ignore: cast_nullable_to_non_nullable
as DateTime?,nextTopupDue: freezed == nextTopupDue ? _self.nextTopupDue : nextTopupDue // ignore: cast_nullable_to_non_nullable
as DateTime?,validityExpiresAt: freezed == validityExpiresAt ? _self.validityExpiresAt : validityExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,protectionTier: null == protectionTier ? _self.protectionTier : protectionTier // ignore: cast_nullable_to_non_nullable
as String,isAutoDetected: null == isAutoDetected ? _self.isAutoDetected : isAutoDetected // ignore: cast_nullable_to_non_nullable
as bool,isHomeMode: null == isHomeMode ? _self.isHomeMode : isHomeMode // ignore: cast_nullable_to_non_nullable
as bool,householdId: freezed == householdId ? _self.householdId : householdId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
