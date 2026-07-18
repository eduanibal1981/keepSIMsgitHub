// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offline_refill_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CarrierUssdSuggestion {

 String get id;@JsonKey(name: 'carrier_id') String get carrierId;@JsonKey(name: 'plan_name') String get planName; double get cost;@JsonKey(name: 'ussd_code') String get ussdCode;
/// Create a copy of CarrierUssdSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CarrierUssdSuggestionCopyWith<CarrierUssdSuggestion> get copyWith => _$CarrierUssdSuggestionCopyWithImpl<CarrierUssdSuggestion>(this as CarrierUssdSuggestion, _$identity);

  /// Serializes this CarrierUssdSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CarrierUssdSuggestion&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.planName, planName) || other.planName == planName)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.ussdCode, ussdCode) || other.ussdCode == ussdCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,carrierId,planName,cost,ussdCode);

@override
String toString() {
  return 'CarrierUssdSuggestion(id: $id, carrierId: $carrierId, planName: $planName, cost: $cost, ussdCode: $ussdCode)';
}


}

/// @nodoc
abstract mixin class $CarrierUssdSuggestionCopyWith<$Res>  {
  factory $CarrierUssdSuggestionCopyWith(CarrierUssdSuggestion value, $Res Function(CarrierUssdSuggestion) _then) = _$CarrierUssdSuggestionCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'plan_name') String planName, double cost,@JsonKey(name: 'ussd_code') String ussdCode
});




}
/// @nodoc
class _$CarrierUssdSuggestionCopyWithImpl<$Res>
    implements $CarrierUssdSuggestionCopyWith<$Res> {
  _$CarrierUssdSuggestionCopyWithImpl(this._self, this._then);

  final CarrierUssdSuggestion _self;
  final $Res Function(CarrierUssdSuggestion) _then;

/// Create a copy of CarrierUssdSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? carrierId = null,Object? planName = null,Object? cost = null,Object? ussdCode = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,planName: null == planName ? _self.planName : planName // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,ussdCode: null == ussdCode ? _self.ussdCode : ussdCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CarrierUssdSuggestion].
extension CarrierUssdSuggestionPatterns on CarrierUssdSuggestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CarrierUssdSuggestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CarrierUssdSuggestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CarrierUssdSuggestion value)  $default,){
final _that = this;
switch (_that) {
case _CarrierUssdSuggestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CarrierUssdSuggestion value)?  $default,){
final _that = this;
switch (_that) {
case _CarrierUssdSuggestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'plan_name')  String planName,  double cost, @JsonKey(name: 'ussd_code')  String ussdCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CarrierUssdSuggestion() when $default != null:
return $default(_that.id,_that.carrierId,_that.planName,_that.cost,_that.ussdCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'plan_name')  String planName,  double cost, @JsonKey(name: 'ussd_code')  String ussdCode)  $default,) {final _that = this;
switch (_that) {
case _CarrierUssdSuggestion():
return $default(_that.id,_that.carrierId,_that.planName,_that.cost,_that.ussdCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'carrier_id')  String carrierId, @JsonKey(name: 'plan_name')  String planName,  double cost, @JsonKey(name: 'ussd_code')  String ussdCode)?  $default,) {final _that = this;
switch (_that) {
case _CarrierUssdSuggestion() when $default != null:
return $default(_that.id,_that.carrierId,_that.planName,_that.cost,_that.ussdCode);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _CarrierUssdSuggestion implements CarrierUssdSuggestion {
  const _CarrierUssdSuggestion({required this.id, @JsonKey(name: 'carrier_id') required this.carrierId, @JsonKey(name: 'plan_name') required this.planName, required this.cost, @JsonKey(name: 'ussd_code') required this.ussdCode});
  factory _CarrierUssdSuggestion.fromJson(Map<String, dynamic> json) => _$CarrierUssdSuggestionFromJson(json);

@override final  String id;
@override@JsonKey(name: 'carrier_id') final  String carrierId;
@override@JsonKey(name: 'plan_name') final  String planName;
@override final  double cost;
@override@JsonKey(name: 'ussd_code') final  String ussdCode;

/// Create a copy of CarrierUssdSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CarrierUssdSuggestionCopyWith<_CarrierUssdSuggestion> get copyWith => __$CarrierUssdSuggestionCopyWithImpl<_CarrierUssdSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CarrierUssdSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CarrierUssdSuggestion&&(identical(other.id, id) || other.id == id)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.planName, planName) || other.planName == planName)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.ussdCode, ussdCode) || other.ussdCode == ussdCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,carrierId,planName,cost,ussdCode);

@override
String toString() {
  return 'CarrierUssdSuggestion(id: $id, carrierId: $carrierId, planName: $planName, cost: $cost, ussdCode: $ussdCode)';
}


}

/// @nodoc
abstract mixin class _$CarrierUssdSuggestionCopyWith<$Res> implements $CarrierUssdSuggestionCopyWith<$Res> {
  factory _$CarrierUssdSuggestionCopyWith(_CarrierUssdSuggestion value, $Res Function(_CarrierUssdSuggestion) _then) = __$CarrierUssdSuggestionCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'carrier_id') String carrierId,@JsonKey(name: 'plan_name') String planName, double cost,@JsonKey(name: 'ussd_code') String ussdCode
});




}
/// @nodoc
class __$CarrierUssdSuggestionCopyWithImpl<$Res>
    implements _$CarrierUssdSuggestionCopyWith<$Res> {
  __$CarrierUssdSuggestionCopyWithImpl(this._self, this._then);

  final _CarrierUssdSuggestion _self;
  final $Res Function(_CarrierUssdSuggestion) _then;

/// Create a copy of CarrierUssdSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? carrierId = null,Object? planName = null,Object? cost = null,Object? ussdCode = null,}) {
  return _then(_CarrierUssdSuggestion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,carrierId: null == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String,planName: null == planName ? _self.planName : planName // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,ussdCode: null == ussdCode ? _self.ussdCode : ussdCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OfflineRefillSettings {

 String? get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'is_enabled') bool get isEnabled;@JsonKey(name: 'default_refill_amount') double get defaultRefillAmount;@JsonKey(name: 'target_sim_line_id') String? get targetSimLineId;@JsonKey(name: 'custom_phone_number') String? get customPhoneNumber;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of OfflineRefillSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfflineRefillSettingsCopyWith<OfflineRefillSettings> get copyWith => _$OfflineRefillSettingsCopyWithImpl<OfflineRefillSettings>(this as OfflineRefillSettings, _$identity);

  /// Serializes this OfflineRefillSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OfflineRefillSettings&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.defaultRefillAmount, defaultRefillAmount) || other.defaultRefillAmount == defaultRefillAmount)&&(identical(other.targetSimLineId, targetSimLineId) || other.targetSimLineId == targetSimLineId)&&(identical(other.customPhoneNumber, customPhoneNumber) || other.customPhoneNumber == customPhoneNumber)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,isEnabled,defaultRefillAmount,targetSimLineId,customPhoneNumber,createdAt,updatedAt);

@override
String toString() {
  return 'OfflineRefillSettings(id: $id, userId: $userId, isEnabled: $isEnabled, defaultRefillAmount: $defaultRefillAmount, targetSimLineId: $targetSimLineId, customPhoneNumber: $customPhoneNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OfflineRefillSettingsCopyWith<$Res>  {
  factory $OfflineRefillSettingsCopyWith(OfflineRefillSettings value, $Res Function(OfflineRefillSettings) _then) = _$OfflineRefillSettingsCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'is_enabled') bool isEnabled,@JsonKey(name: 'default_refill_amount') double defaultRefillAmount,@JsonKey(name: 'target_sim_line_id') String? targetSimLineId,@JsonKey(name: 'custom_phone_number') String? customPhoneNumber,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$OfflineRefillSettingsCopyWithImpl<$Res>
    implements $OfflineRefillSettingsCopyWith<$Res> {
  _$OfflineRefillSettingsCopyWithImpl(this._self, this._then);

  final OfflineRefillSettings _self;
  final $Res Function(OfflineRefillSettings) _then;

/// Create a copy of OfflineRefillSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? userId = null,Object? isEnabled = null,Object? defaultRefillAmount = null,Object? targetSimLineId = freezed,Object? customPhoneNumber = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,defaultRefillAmount: null == defaultRefillAmount ? _self.defaultRefillAmount : defaultRefillAmount // ignore: cast_nullable_to_non_nullable
as double,targetSimLineId: freezed == targetSimLineId ? _self.targetSimLineId : targetSimLineId // ignore: cast_nullable_to_non_nullable
as String?,customPhoneNumber: freezed == customPhoneNumber ? _self.customPhoneNumber : customPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OfflineRefillSettings].
extension OfflineRefillSettingsPatterns on OfflineRefillSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OfflineRefillSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OfflineRefillSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OfflineRefillSettings value)  $default,){
final _that = this;
switch (_that) {
case _OfflineRefillSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OfflineRefillSettings value)?  $default,){
final _that = this;
switch (_that) {
case _OfflineRefillSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'default_refill_amount')  double defaultRefillAmount, @JsonKey(name: 'target_sim_line_id')  String? targetSimLineId, @JsonKey(name: 'custom_phone_number')  String? customPhoneNumber, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OfflineRefillSettings() when $default != null:
return $default(_that.id,_that.userId,_that.isEnabled,_that.defaultRefillAmount,_that.targetSimLineId,_that.customPhoneNumber,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'default_refill_amount')  double defaultRefillAmount, @JsonKey(name: 'target_sim_line_id')  String? targetSimLineId, @JsonKey(name: 'custom_phone_number')  String? customPhoneNumber, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OfflineRefillSettings():
return $default(_that.id,_that.userId,_that.isEnabled,_that.defaultRefillAmount,_that.targetSimLineId,_that.customPhoneNumber,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'default_refill_amount')  double defaultRefillAmount, @JsonKey(name: 'target_sim_line_id')  String? targetSimLineId, @JsonKey(name: 'custom_phone_number')  String? customPhoneNumber, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OfflineRefillSettings() when $default != null:
return $default(_that.id,_that.userId,_that.isEnabled,_that.defaultRefillAmount,_that.targetSimLineId,_that.customPhoneNumber,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _OfflineRefillSettings implements OfflineRefillSettings {
  const _OfflineRefillSettings({this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'is_enabled') this.isEnabled = true, @JsonKey(name: 'default_refill_amount') this.defaultRefillAmount = 10.00, @JsonKey(name: 'target_sim_line_id') this.targetSimLineId, @JsonKey(name: 'custom_phone_number') this.customPhoneNumber, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _OfflineRefillSettings.fromJson(Map<String, dynamic> json) => _$OfflineRefillSettingsFromJson(json);

@override final  String? id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'is_enabled') final  bool isEnabled;
@override@JsonKey(name: 'default_refill_amount') final  double defaultRefillAmount;
@override@JsonKey(name: 'target_sim_line_id') final  String? targetSimLineId;
@override@JsonKey(name: 'custom_phone_number') final  String? customPhoneNumber;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of OfflineRefillSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfflineRefillSettingsCopyWith<_OfflineRefillSettings> get copyWith => __$OfflineRefillSettingsCopyWithImpl<_OfflineRefillSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OfflineRefillSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OfflineRefillSettings&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.defaultRefillAmount, defaultRefillAmount) || other.defaultRefillAmount == defaultRefillAmount)&&(identical(other.targetSimLineId, targetSimLineId) || other.targetSimLineId == targetSimLineId)&&(identical(other.customPhoneNumber, customPhoneNumber) || other.customPhoneNumber == customPhoneNumber)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,isEnabled,defaultRefillAmount,targetSimLineId,customPhoneNumber,createdAt,updatedAt);

@override
String toString() {
  return 'OfflineRefillSettings(id: $id, userId: $userId, isEnabled: $isEnabled, defaultRefillAmount: $defaultRefillAmount, targetSimLineId: $targetSimLineId, customPhoneNumber: $customPhoneNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OfflineRefillSettingsCopyWith<$Res> implements $OfflineRefillSettingsCopyWith<$Res> {
  factory _$OfflineRefillSettingsCopyWith(_OfflineRefillSettings value, $Res Function(_OfflineRefillSettings) _then) = __$OfflineRefillSettingsCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'is_enabled') bool isEnabled,@JsonKey(name: 'default_refill_amount') double defaultRefillAmount,@JsonKey(name: 'target_sim_line_id') String? targetSimLineId,@JsonKey(name: 'custom_phone_number') String? customPhoneNumber,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$OfflineRefillSettingsCopyWithImpl<$Res>
    implements _$OfflineRefillSettingsCopyWith<$Res> {
  __$OfflineRefillSettingsCopyWithImpl(this._self, this._then);

  final _OfflineRefillSettings _self;
  final $Res Function(_OfflineRefillSettings) _then;

/// Create a copy of OfflineRefillSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? userId = null,Object? isEnabled = null,Object? defaultRefillAmount = null,Object? targetSimLineId = freezed,Object? customPhoneNumber = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_OfflineRefillSettings(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,defaultRefillAmount: null == defaultRefillAmount ? _self.defaultRefillAmount : defaultRefillAmount // ignore: cast_nullable_to_non_nullable
as double,targetSimLineId: freezed == targetSimLineId ? _self.targetSimLineId : targetSimLineId // ignore: cast_nullable_to_non_nullable
as String?,customPhoneNumber: freezed == customPhoneNumber ? _self.customPhoneNumber : customPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$PendingOfflineRefill {

 String get id; String get channel;@JsonKey(name: 'sim_line_id') String get simLineId;@JsonKey(name: 'phone_number') String get phoneNumber; double get amount; String get status;@JsonKey(name: 'launched_at') DateTime get launchedAt;@JsonKey(name: 'execution_id') String? get executionId;@JsonKey(name: 'failure_reason') String? get failureReason;
/// Create a copy of PendingOfflineRefill
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingOfflineRefillCopyWith<PendingOfflineRefill> get copyWith => _$PendingOfflineRefillCopyWithImpl<PendingOfflineRefill>(this as PendingOfflineRefill, _$identity);

  /// Serializes this PendingOfflineRefill to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingOfflineRefill&&(identical(other.id, id) || other.id == id)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.launchedAt, launchedAt) || other.launchedAt == launchedAt)&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channel,simLineId,phoneNumber,amount,status,launchedAt,executionId,failureReason);

@override
String toString() {
  return 'PendingOfflineRefill(id: $id, channel: $channel, simLineId: $simLineId, phoneNumber: $phoneNumber, amount: $amount, status: $status, launchedAt: $launchedAt, executionId: $executionId, failureReason: $failureReason)';
}


}

/// @nodoc
abstract mixin class $PendingOfflineRefillCopyWith<$Res>  {
  factory $PendingOfflineRefillCopyWith(PendingOfflineRefill value, $Res Function(PendingOfflineRefill) _then) = _$PendingOfflineRefillCopyWithImpl;
@useResult
$Res call({
 String id, String channel,@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber, double amount, String status,@JsonKey(name: 'launched_at') DateTime launchedAt,@JsonKey(name: 'execution_id') String? executionId,@JsonKey(name: 'failure_reason') String? failureReason
});




}
/// @nodoc
class _$PendingOfflineRefillCopyWithImpl<$Res>
    implements $PendingOfflineRefillCopyWith<$Res> {
  _$PendingOfflineRefillCopyWithImpl(this._self, this._then);

  final PendingOfflineRefill _self;
  final $Res Function(PendingOfflineRefill) _then;

/// Create a copy of PendingOfflineRefill
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channel = null,Object? simLineId = null,Object? phoneNumber = null,Object? amount = null,Object? status = null,Object? launchedAt = null,Object? executionId = freezed,Object? failureReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,launchedAt: null == launchedAt ? _self.launchedAt : launchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,executionId: freezed == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingOfflineRefill].
extension PendingOfflineRefillPatterns on PendingOfflineRefill {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PendingOfflineRefill value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PendingOfflineRefill() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PendingOfflineRefill value)  $default,){
final _that = this;
switch (_that) {
case _PendingOfflineRefill():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PendingOfflineRefill value)?  $default,){
final _that = this;
switch (_that) {
case _PendingOfflineRefill() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String channel, @JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  double amount,  String status, @JsonKey(name: 'launched_at')  DateTime launchedAt, @JsonKey(name: 'execution_id')  String? executionId, @JsonKey(name: 'failure_reason')  String? failureReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PendingOfflineRefill() when $default != null:
return $default(_that.id,_that.channel,_that.simLineId,_that.phoneNumber,_that.amount,_that.status,_that.launchedAt,_that.executionId,_that.failureReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String channel, @JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  double amount,  String status, @JsonKey(name: 'launched_at')  DateTime launchedAt, @JsonKey(name: 'execution_id')  String? executionId, @JsonKey(name: 'failure_reason')  String? failureReason)  $default,) {final _that = this;
switch (_that) {
case _PendingOfflineRefill():
return $default(_that.id,_that.channel,_that.simLineId,_that.phoneNumber,_that.amount,_that.status,_that.launchedAt,_that.executionId,_that.failureReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String channel, @JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  double amount,  String status, @JsonKey(name: 'launched_at')  DateTime launchedAt, @JsonKey(name: 'execution_id')  String? executionId, @JsonKey(name: 'failure_reason')  String? failureReason)?  $default,) {final _that = this;
switch (_that) {
case _PendingOfflineRefill() when $default != null:
return $default(_that.id,_that.channel,_that.simLineId,_that.phoneNumber,_that.amount,_that.status,_that.launchedAt,_that.executionId,_that.failureReason);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _PendingOfflineRefill implements PendingOfflineRefill {
  const _PendingOfflineRefill({required this.id, required this.channel, @JsonKey(name: 'sim_line_id') required this.simLineId, @JsonKey(name: 'phone_number') required this.phoneNumber, required this.amount, this.status = PendingRefillStatus.sent, @JsonKey(name: 'launched_at') required this.launchedAt, @JsonKey(name: 'execution_id') this.executionId, @JsonKey(name: 'failure_reason') this.failureReason});
  factory _PendingOfflineRefill.fromJson(Map<String, dynamic> json) => _$PendingOfflineRefillFromJson(json);

@override final  String id;
@override final  String channel;
@override@JsonKey(name: 'sim_line_id') final  String simLineId;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override final  double amount;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'launched_at') final  DateTime launchedAt;
@override@JsonKey(name: 'execution_id') final  String? executionId;
@override@JsonKey(name: 'failure_reason') final  String? failureReason;

/// Create a copy of PendingOfflineRefill
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingOfflineRefillCopyWith<_PendingOfflineRefill> get copyWith => __$PendingOfflineRefillCopyWithImpl<_PendingOfflineRefill>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingOfflineRefillToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingOfflineRefill&&(identical(other.id, id) || other.id == id)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.launchedAt, launchedAt) || other.launchedAt == launchedAt)&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channel,simLineId,phoneNumber,amount,status,launchedAt,executionId,failureReason);

@override
String toString() {
  return 'PendingOfflineRefill(id: $id, channel: $channel, simLineId: $simLineId, phoneNumber: $phoneNumber, amount: $amount, status: $status, launchedAt: $launchedAt, executionId: $executionId, failureReason: $failureReason)';
}


}

/// @nodoc
abstract mixin class _$PendingOfflineRefillCopyWith<$Res> implements $PendingOfflineRefillCopyWith<$Res> {
  factory _$PendingOfflineRefillCopyWith(_PendingOfflineRefill value, $Res Function(_PendingOfflineRefill) _then) = __$PendingOfflineRefillCopyWithImpl;
@override @useResult
$Res call({
 String id, String channel,@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber, double amount, String status,@JsonKey(name: 'launched_at') DateTime launchedAt,@JsonKey(name: 'execution_id') String? executionId,@JsonKey(name: 'failure_reason') String? failureReason
});




}
/// @nodoc
class __$PendingOfflineRefillCopyWithImpl<$Res>
    implements _$PendingOfflineRefillCopyWith<$Res> {
  __$PendingOfflineRefillCopyWithImpl(this._self, this._then);

  final _PendingOfflineRefill _self;
  final $Res Function(_PendingOfflineRefill) _then;

/// Create a copy of PendingOfflineRefill
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channel = null,Object? simLineId = null,Object? phoneNumber = null,Object? amount = null,Object? status = null,Object? launchedAt = null,Object? executionId = freezed,Object? failureReason = freezed,}) {
  return _then(_PendingOfflineRefill(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,launchedAt: null == launchedAt ? _self.launchedAt : launchedAt // ignore: cast_nullable_to_non_nullable
as DateTime,executionId: freezed == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
