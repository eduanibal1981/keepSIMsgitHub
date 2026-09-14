// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_topup_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduledTopup {

 String get id; String get simLineId; String get userId; double get amount; String get currency; int get frequencyDays; DateTime get nextExecutionAt; DateTime? get lastExecutionAt; bool get isActive; int get retryCount; int get maxRetries; String get status; String get scheduleType; DateTime? get createdAt; DateTime? get updatedAt; String? get offerId; int? get offerValue; double? get baseCostUsd; double? get appFeeUsd; String? get pricingTier; int? get feeRuleVersion;
/// Create a copy of ScheduledTopup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledTopupCopyWith<ScheduledTopup> get copyWith => _$ScheduledTopupCopyWithImpl<ScheduledTopup>(this as ScheduledTopup, _$identity);

  /// Serializes this ScheduledTopup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledTopup&&(identical(other.id, id) || other.id == id)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.frequencyDays, frequencyDays) || other.frequencyDays == frequencyDays)&&(identical(other.nextExecutionAt, nextExecutionAt) || other.nextExecutionAt == nextExecutionAt)&&(identical(other.lastExecutionAt, lastExecutionAt) || other.lastExecutionAt == lastExecutionAt)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.status, status) || other.status == status)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.offerValue, offerValue) || other.offerValue == offerValue)&&(identical(other.baseCostUsd, baseCostUsd) || other.baseCostUsd == baseCostUsd)&&(identical(other.appFeeUsd, appFeeUsd) || other.appFeeUsd == appFeeUsd)&&(identical(other.pricingTier, pricingTier) || other.pricingTier == pricingTier)&&(identical(other.feeRuleVersion, feeRuleVersion) || other.feeRuleVersion == feeRuleVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,simLineId,userId,amount,currency,frequencyDays,nextExecutionAt,lastExecutionAt,isActive,retryCount,maxRetries,status,scheduleType,createdAt,updatedAt,offerId,offerValue,baseCostUsd,appFeeUsd,pricingTier,feeRuleVersion]);

@override
String toString() {
  return 'ScheduledTopup(id: $id, simLineId: $simLineId, userId: $userId, amount: $amount, currency: $currency, frequencyDays: $frequencyDays, nextExecutionAt: $nextExecutionAt, lastExecutionAt: $lastExecutionAt, isActive: $isActive, retryCount: $retryCount, maxRetries: $maxRetries, status: $status, scheduleType: $scheduleType, createdAt: $createdAt, updatedAt: $updatedAt, offerId: $offerId, offerValue: $offerValue, baseCostUsd: $baseCostUsd, appFeeUsd: $appFeeUsd, pricingTier: $pricingTier, feeRuleVersion: $feeRuleVersion)';
}


}

/// @nodoc
abstract mixin class $ScheduledTopupCopyWith<$Res>  {
  factory $ScheduledTopupCopyWith(ScheduledTopup value, $Res Function(ScheduledTopup) _then) = _$ScheduledTopupCopyWithImpl;
@useResult
$Res call({
 String id, String simLineId, String userId, double amount, String currency, int frequencyDays, DateTime nextExecutionAt, DateTime? lastExecutionAt, bool isActive, int retryCount, int maxRetries, String status, String scheduleType, DateTime? createdAt, DateTime? updatedAt, String? offerId, int? offerValue, double? baseCostUsd, double? appFeeUsd, String? pricingTier, int? feeRuleVersion
});




}
/// @nodoc
class _$ScheduledTopupCopyWithImpl<$Res>
    implements $ScheduledTopupCopyWith<$Res> {
  _$ScheduledTopupCopyWithImpl(this._self, this._then);

  final ScheduledTopup _self;
  final $Res Function(ScheduledTopup) _then;

/// Create a copy of ScheduledTopup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? simLineId = null,Object? userId = null,Object? amount = null,Object? currency = null,Object? frequencyDays = null,Object? nextExecutionAt = null,Object? lastExecutionAt = freezed,Object? isActive = null,Object? retryCount = null,Object? maxRetries = null,Object? status = null,Object? scheduleType = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? offerId = freezed,Object? offerValue = freezed,Object? baseCostUsd = freezed,Object? appFeeUsd = freezed,Object? pricingTier = freezed,Object? feeRuleVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,frequencyDays: null == frequencyDays ? _self.frequencyDays : frequencyDays // ignore: cast_nullable_to_non_nullable
as int,nextExecutionAt: null == nextExecutionAt ? _self.nextExecutionAt : nextExecutionAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastExecutionAt: freezed == lastExecutionAt ? _self.lastExecutionAt : lastExecutionAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,offerId: freezed == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String?,offerValue: freezed == offerValue ? _self.offerValue : offerValue // ignore: cast_nullable_to_non_nullable
as int?,baseCostUsd: freezed == baseCostUsd ? _self.baseCostUsd : baseCostUsd // ignore: cast_nullable_to_non_nullable
as double?,appFeeUsd: freezed == appFeeUsd ? _self.appFeeUsd : appFeeUsd // ignore: cast_nullable_to_non_nullable
as double?,pricingTier: freezed == pricingTier ? _self.pricingTier : pricingTier // ignore: cast_nullable_to_non_nullable
as String?,feeRuleVersion: freezed == feeRuleVersion ? _self.feeRuleVersion : feeRuleVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduledTopup].
extension ScheduledTopupPatterns on ScheduledTopup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduledTopup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduledTopup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduledTopup value)  $default,){
final _that = this;
switch (_that) {
case _ScheduledTopup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduledTopup value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduledTopup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String simLineId,  String userId,  double amount,  String currency,  int frequencyDays,  DateTime nextExecutionAt,  DateTime? lastExecutionAt,  bool isActive,  int retryCount,  int maxRetries,  String status,  String scheduleType,  DateTime? createdAt,  DateTime? updatedAt,  String? offerId,  int? offerValue,  double? baseCostUsd,  double? appFeeUsd,  String? pricingTier,  int? feeRuleVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduledTopup() when $default != null:
return $default(_that.id,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.frequencyDays,_that.nextExecutionAt,_that.lastExecutionAt,_that.isActive,_that.retryCount,_that.maxRetries,_that.status,_that.scheduleType,_that.createdAt,_that.updatedAt,_that.offerId,_that.offerValue,_that.baseCostUsd,_that.appFeeUsd,_that.pricingTier,_that.feeRuleVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String simLineId,  String userId,  double amount,  String currency,  int frequencyDays,  DateTime nextExecutionAt,  DateTime? lastExecutionAt,  bool isActive,  int retryCount,  int maxRetries,  String status,  String scheduleType,  DateTime? createdAt,  DateTime? updatedAt,  String? offerId,  int? offerValue,  double? baseCostUsd,  double? appFeeUsd,  String? pricingTier,  int? feeRuleVersion)  $default,) {final _that = this;
switch (_that) {
case _ScheduledTopup():
return $default(_that.id,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.frequencyDays,_that.nextExecutionAt,_that.lastExecutionAt,_that.isActive,_that.retryCount,_that.maxRetries,_that.status,_that.scheduleType,_that.createdAt,_that.updatedAt,_that.offerId,_that.offerValue,_that.baseCostUsd,_that.appFeeUsd,_that.pricingTier,_that.feeRuleVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String simLineId,  String userId,  double amount,  String currency,  int frequencyDays,  DateTime nextExecutionAt,  DateTime? lastExecutionAt,  bool isActive,  int retryCount,  int maxRetries,  String status,  String scheduleType,  DateTime? createdAt,  DateTime? updatedAt,  String? offerId,  int? offerValue,  double? baseCostUsd,  double? appFeeUsd,  String? pricingTier,  int? feeRuleVersion)?  $default,) {final _that = this;
switch (_that) {
case _ScheduledTopup() when $default != null:
return $default(_that.id,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.frequencyDays,_that.nextExecutionAt,_that.lastExecutionAt,_that.isActive,_that.retryCount,_that.maxRetries,_that.status,_that.scheduleType,_that.createdAt,_that.updatedAt,_that.offerId,_that.offerValue,_that.baseCostUsd,_that.appFeeUsd,_that.pricingTier,_that.feeRuleVersion);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ScheduledTopup implements ScheduledTopup {
  const _ScheduledTopup({required this.id, required this.simLineId, required this.userId, required this.amount, this.currency = 'USD', required this.frequencyDays, required this.nextExecutionAt, this.lastExecutionAt, this.isActive = true, this.retryCount = 0, this.maxRetries = 4, this.status = 'active', this.scheduleType = 'notify', this.createdAt, this.updatedAt, this.offerId, this.offerValue, this.baseCostUsd, this.appFeeUsd, this.pricingTier, this.feeRuleVersion});
  factory _ScheduledTopup.fromJson(Map<String, dynamic> json) => _$ScheduledTopupFromJson(json);

@override final  String id;
@override final  String simLineId;
@override final  String userId;
@override final  double amount;
@override@JsonKey() final  String currency;
@override final  int frequencyDays;
@override final  DateTime nextExecutionAt;
@override final  DateTime? lastExecutionAt;
@override@JsonKey() final  bool isActive;
@override@JsonKey() final  int retryCount;
@override@JsonKey() final  int maxRetries;
@override@JsonKey() final  String status;
@override@JsonKey() final  String scheduleType;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
@override final  String? offerId;
@override final  int? offerValue;
@override final  double? baseCostUsd;
@override final  double? appFeeUsd;
@override final  String? pricingTier;
@override final  int? feeRuleVersion;

/// Create a copy of ScheduledTopup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduledTopupCopyWith<_ScheduledTopup> get copyWith => __$ScheduledTopupCopyWithImpl<_ScheduledTopup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledTopupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduledTopup&&(identical(other.id, id) || other.id == id)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.frequencyDays, frequencyDays) || other.frequencyDays == frequencyDays)&&(identical(other.nextExecutionAt, nextExecutionAt) || other.nextExecutionAt == nextExecutionAt)&&(identical(other.lastExecutionAt, lastExecutionAt) || other.lastExecutionAt == lastExecutionAt)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.maxRetries, maxRetries) || other.maxRetries == maxRetries)&&(identical(other.status, status) || other.status == status)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.offerValue, offerValue) || other.offerValue == offerValue)&&(identical(other.baseCostUsd, baseCostUsd) || other.baseCostUsd == baseCostUsd)&&(identical(other.appFeeUsd, appFeeUsd) || other.appFeeUsd == appFeeUsd)&&(identical(other.pricingTier, pricingTier) || other.pricingTier == pricingTier)&&(identical(other.feeRuleVersion, feeRuleVersion) || other.feeRuleVersion == feeRuleVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,simLineId,userId,amount,currency,frequencyDays,nextExecutionAt,lastExecutionAt,isActive,retryCount,maxRetries,status,scheduleType,createdAt,updatedAt,offerId,offerValue,baseCostUsd,appFeeUsd,pricingTier,feeRuleVersion]);

@override
String toString() {
  return 'ScheduledTopup(id: $id, simLineId: $simLineId, userId: $userId, amount: $amount, currency: $currency, frequencyDays: $frequencyDays, nextExecutionAt: $nextExecutionAt, lastExecutionAt: $lastExecutionAt, isActive: $isActive, retryCount: $retryCount, maxRetries: $maxRetries, status: $status, scheduleType: $scheduleType, createdAt: $createdAt, updatedAt: $updatedAt, offerId: $offerId, offerValue: $offerValue, baseCostUsd: $baseCostUsd, appFeeUsd: $appFeeUsd, pricingTier: $pricingTier, feeRuleVersion: $feeRuleVersion)';
}


}

/// @nodoc
abstract mixin class _$ScheduledTopupCopyWith<$Res> implements $ScheduledTopupCopyWith<$Res> {
  factory _$ScheduledTopupCopyWith(_ScheduledTopup value, $Res Function(_ScheduledTopup) _then) = __$ScheduledTopupCopyWithImpl;
@override @useResult
$Res call({
 String id, String simLineId, String userId, double amount, String currency, int frequencyDays, DateTime nextExecutionAt, DateTime? lastExecutionAt, bool isActive, int retryCount, int maxRetries, String status, String scheduleType, DateTime? createdAt, DateTime? updatedAt, String? offerId, int? offerValue, double? baseCostUsd, double? appFeeUsd, String? pricingTier, int? feeRuleVersion
});




}
/// @nodoc
class __$ScheduledTopupCopyWithImpl<$Res>
    implements _$ScheduledTopupCopyWith<$Res> {
  __$ScheduledTopupCopyWithImpl(this._self, this._then);

  final _ScheduledTopup _self;
  final $Res Function(_ScheduledTopup) _then;

/// Create a copy of ScheduledTopup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? simLineId = null,Object? userId = null,Object? amount = null,Object? currency = null,Object? frequencyDays = null,Object? nextExecutionAt = null,Object? lastExecutionAt = freezed,Object? isActive = null,Object? retryCount = null,Object? maxRetries = null,Object? status = null,Object? scheduleType = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? offerId = freezed,Object? offerValue = freezed,Object? baseCostUsd = freezed,Object? appFeeUsd = freezed,Object? pricingTier = freezed,Object? feeRuleVersion = freezed,}) {
  return _then(_ScheduledTopup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,frequencyDays: null == frequencyDays ? _self.frequencyDays : frequencyDays // ignore: cast_nullable_to_non_nullable
as int,nextExecutionAt: null == nextExecutionAt ? _self.nextExecutionAt : nextExecutionAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastExecutionAt: freezed == lastExecutionAt ? _self.lastExecutionAt : lastExecutionAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,maxRetries: null == maxRetries ? _self.maxRetries : maxRetries // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,offerId: freezed == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String?,offerValue: freezed == offerValue ? _self.offerValue : offerValue // ignore: cast_nullable_to_non_nullable
as int?,baseCostUsd: freezed == baseCostUsd ? _self.baseCostUsd : baseCostUsd // ignore: cast_nullable_to_non_nullable
as double?,appFeeUsd: freezed == appFeeUsd ? _self.appFeeUsd : appFeeUsd // ignore: cast_nullable_to_non_nullable
as double?,pricingTier: freezed == pricingTier ? _self.pricingTier : pricingTier // ignore: cast_nullable_to_non_nullable
as String?,feeRuleVersion: freezed == feeRuleVersion ? _self.feeRuleVersion : feeRuleVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
