// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'topup_execution_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TopupExecution {

 String get id; String? get scheduledTopupId; String get simLineId; String get userId; double get amount; String get currency; String? get reloadlyTransactionId; String get status; String? get failureReason; String? get retryOf; int? get validityDaysAdded; String? get fulfillmentGateway; String? get apiProvider; String? get executionType; DateTime? get executionTime; DateTime? get executedAt; DateTime? get completedAt; DateTime? get createdAt; String? get pinCode; String? get pinSerial; String? get redeemInstructions;
/// Create a copy of TopupExecution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopupExecutionCopyWith<TopupExecution> get copyWith => _$TopupExecutionCopyWithImpl<TopupExecution>(this as TopupExecution, _$identity);

  /// Serializes this TopupExecution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopupExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduledTopupId, scheduledTopupId) || other.scheduledTopupId == scheduledTopupId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.reloadlyTransactionId, reloadlyTransactionId) || other.reloadlyTransactionId == reloadlyTransactionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.retryOf, retryOf) || other.retryOf == retryOf)&&(identical(other.validityDaysAdded, validityDaysAdded) || other.validityDaysAdded == validityDaysAdded)&&(identical(other.fulfillmentGateway, fulfillmentGateway) || other.fulfillmentGateway == fulfillmentGateway)&&(identical(other.apiProvider, apiProvider) || other.apiProvider == apiProvider)&&(identical(other.executionType, executionType) || other.executionType == executionType)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.executedAt, executedAt) || other.executedAt == executedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.pinCode, pinCode) || other.pinCode == pinCode)&&(identical(other.pinSerial, pinSerial) || other.pinSerial == pinSerial)&&(identical(other.redeemInstructions, redeemInstructions) || other.redeemInstructions == redeemInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,scheduledTopupId,simLineId,userId,amount,currency,reloadlyTransactionId,status,failureReason,retryOf,validityDaysAdded,fulfillmentGateway,apiProvider,executionType,executionTime,executedAt,completedAt,createdAt,pinCode,pinSerial,redeemInstructions]);

@override
String toString() {
  return 'TopupExecution(id: $id, scheduledTopupId: $scheduledTopupId, simLineId: $simLineId, userId: $userId, amount: $amount, currency: $currency, reloadlyTransactionId: $reloadlyTransactionId, status: $status, failureReason: $failureReason, retryOf: $retryOf, validityDaysAdded: $validityDaysAdded, fulfillmentGateway: $fulfillmentGateway, apiProvider: $apiProvider, executionType: $executionType, executionTime: $executionTime, executedAt: $executedAt, completedAt: $completedAt, createdAt: $createdAt, pinCode: $pinCode, pinSerial: $pinSerial, redeemInstructions: $redeemInstructions)';
}


}

/// @nodoc
abstract mixin class $TopupExecutionCopyWith<$Res>  {
  factory $TopupExecutionCopyWith(TopupExecution value, $Res Function(TopupExecution) _then) = _$TopupExecutionCopyWithImpl;
@useResult
$Res call({
 String id, String? scheduledTopupId, String simLineId, String userId, double amount, String currency, String? reloadlyTransactionId, String status, String? failureReason, String? retryOf, int? validityDaysAdded, String? fulfillmentGateway, String? apiProvider, String? executionType, DateTime? executionTime, DateTime? executedAt, DateTime? completedAt, DateTime? createdAt, String? pinCode, String? pinSerial, String? redeemInstructions
});




}
/// @nodoc
class _$TopupExecutionCopyWithImpl<$Res>
    implements $TopupExecutionCopyWith<$Res> {
  _$TopupExecutionCopyWithImpl(this._self, this._then);

  final TopupExecution _self;
  final $Res Function(TopupExecution) _then;

/// Create a copy of TopupExecution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scheduledTopupId = freezed,Object? simLineId = null,Object? userId = null,Object? amount = null,Object? currency = null,Object? reloadlyTransactionId = freezed,Object? status = null,Object? failureReason = freezed,Object? retryOf = freezed,Object? validityDaysAdded = freezed,Object? fulfillmentGateway = freezed,Object? apiProvider = freezed,Object? executionType = freezed,Object? executionTime = freezed,Object? executedAt = freezed,Object? completedAt = freezed,Object? createdAt = freezed,Object? pinCode = freezed,Object? pinSerial = freezed,Object? redeemInstructions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scheduledTopupId: freezed == scheduledTopupId ? _self.scheduledTopupId : scheduledTopupId // ignore: cast_nullable_to_non_nullable
as String?,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,reloadlyTransactionId: freezed == reloadlyTransactionId ? _self.reloadlyTransactionId : reloadlyTransactionId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,retryOf: freezed == retryOf ? _self.retryOf : retryOf // ignore: cast_nullable_to_non_nullable
as String?,validityDaysAdded: freezed == validityDaysAdded ? _self.validityDaysAdded : validityDaysAdded // ignore: cast_nullable_to_non_nullable
as int?,fulfillmentGateway: freezed == fulfillmentGateway ? _self.fulfillmentGateway : fulfillmentGateway // ignore: cast_nullable_to_non_nullable
as String?,apiProvider: freezed == apiProvider ? _self.apiProvider : apiProvider // ignore: cast_nullable_to_non_nullable
as String?,executionType: freezed == executionType ? _self.executionType : executionType // ignore: cast_nullable_to_non_nullable
as String?,executionTime: freezed == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as DateTime?,executedAt: freezed == executedAt ? _self.executedAt : executedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pinCode: freezed == pinCode ? _self.pinCode : pinCode // ignore: cast_nullable_to_non_nullable
as String?,pinSerial: freezed == pinSerial ? _self.pinSerial : pinSerial // ignore: cast_nullable_to_non_nullable
as String?,redeemInstructions: freezed == redeemInstructions ? _self.redeemInstructions : redeemInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TopupExecution].
extension TopupExecutionPatterns on TopupExecution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopupExecution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopupExecution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopupExecution value)  $default,){
final _that = this;
switch (_that) {
case _TopupExecution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopupExecution value)?  $default,){
final _that = this;
switch (_that) {
case _TopupExecution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? scheduledTopupId,  String simLineId,  String userId,  double amount,  String currency,  String? reloadlyTransactionId,  String status,  String? failureReason,  String? retryOf,  int? validityDaysAdded,  String? fulfillmentGateway,  String? apiProvider,  String? executionType,  DateTime? executionTime,  DateTime? executedAt,  DateTime? completedAt,  DateTime? createdAt,  String? pinCode,  String? pinSerial,  String? redeemInstructions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopupExecution() when $default != null:
return $default(_that.id,_that.scheduledTopupId,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.reloadlyTransactionId,_that.status,_that.failureReason,_that.retryOf,_that.validityDaysAdded,_that.fulfillmentGateway,_that.apiProvider,_that.executionType,_that.executionTime,_that.executedAt,_that.completedAt,_that.createdAt,_that.pinCode,_that.pinSerial,_that.redeemInstructions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? scheduledTopupId,  String simLineId,  String userId,  double amount,  String currency,  String? reloadlyTransactionId,  String status,  String? failureReason,  String? retryOf,  int? validityDaysAdded,  String? fulfillmentGateway,  String? apiProvider,  String? executionType,  DateTime? executionTime,  DateTime? executedAt,  DateTime? completedAt,  DateTime? createdAt,  String? pinCode,  String? pinSerial,  String? redeemInstructions)  $default,) {final _that = this;
switch (_that) {
case _TopupExecution():
return $default(_that.id,_that.scheduledTopupId,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.reloadlyTransactionId,_that.status,_that.failureReason,_that.retryOf,_that.validityDaysAdded,_that.fulfillmentGateway,_that.apiProvider,_that.executionType,_that.executionTime,_that.executedAt,_that.completedAt,_that.createdAt,_that.pinCode,_that.pinSerial,_that.redeemInstructions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? scheduledTopupId,  String simLineId,  String userId,  double amount,  String currency,  String? reloadlyTransactionId,  String status,  String? failureReason,  String? retryOf,  int? validityDaysAdded,  String? fulfillmentGateway,  String? apiProvider,  String? executionType,  DateTime? executionTime,  DateTime? executedAt,  DateTime? completedAt,  DateTime? createdAt,  String? pinCode,  String? pinSerial,  String? redeemInstructions)?  $default,) {final _that = this;
switch (_that) {
case _TopupExecution() when $default != null:
return $default(_that.id,_that.scheduledTopupId,_that.simLineId,_that.userId,_that.amount,_that.currency,_that.reloadlyTransactionId,_that.status,_that.failureReason,_that.retryOf,_that.validityDaysAdded,_that.fulfillmentGateway,_that.apiProvider,_that.executionType,_that.executionTime,_that.executedAt,_that.completedAt,_that.createdAt,_that.pinCode,_that.pinSerial,_that.redeemInstructions);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _TopupExecution implements TopupExecution {
  const _TopupExecution({required this.id, this.scheduledTopupId, required this.simLineId, required this.userId, required this.amount, this.currency = 'USD', this.reloadlyTransactionId, this.status = 'pending', this.failureReason, this.retryOf, this.validityDaysAdded, this.fulfillmentGateway, this.apiProvider, this.executionType, this.executionTime, this.executedAt, this.completedAt, this.createdAt, this.pinCode, this.pinSerial, this.redeemInstructions});
  factory _TopupExecution.fromJson(Map<String, dynamic> json) => _$TopupExecutionFromJson(json);

@override final  String id;
@override final  String? scheduledTopupId;
@override final  String simLineId;
@override final  String userId;
@override final  double amount;
@override@JsonKey() final  String currency;
@override final  String? reloadlyTransactionId;
@override@JsonKey() final  String status;
@override final  String? failureReason;
@override final  String? retryOf;
@override final  int? validityDaysAdded;
@override final  String? fulfillmentGateway;
@override final  String? apiProvider;
@override final  String? executionType;
@override final  DateTime? executionTime;
@override final  DateTime? executedAt;
@override final  DateTime? completedAt;
@override final  DateTime? createdAt;
@override final  String? pinCode;
@override final  String? pinSerial;
@override final  String? redeemInstructions;

/// Create a copy of TopupExecution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopupExecutionCopyWith<_TopupExecution> get copyWith => __$TopupExecutionCopyWithImpl<_TopupExecution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopupExecutionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopupExecution&&(identical(other.id, id) || other.id == id)&&(identical(other.scheduledTopupId, scheduledTopupId) || other.scheduledTopupId == scheduledTopupId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.reloadlyTransactionId, reloadlyTransactionId) || other.reloadlyTransactionId == reloadlyTransactionId)&&(identical(other.status, status) || other.status == status)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.retryOf, retryOf) || other.retryOf == retryOf)&&(identical(other.validityDaysAdded, validityDaysAdded) || other.validityDaysAdded == validityDaysAdded)&&(identical(other.fulfillmentGateway, fulfillmentGateway) || other.fulfillmentGateway == fulfillmentGateway)&&(identical(other.apiProvider, apiProvider) || other.apiProvider == apiProvider)&&(identical(other.executionType, executionType) || other.executionType == executionType)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.executedAt, executedAt) || other.executedAt == executedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.pinCode, pinCode) || other.pinCode == pinCode)&&(identical(other.pinSerial, pinSerial) || other.pinSerial == pinSerial)&&(identical(other.redeemInstructions, redeemInstructions) || other.redeemInstructions == redeemInstructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,scheduledTopupId,simLineId,userId,amount,currency,reloadlyTransactionId,status,failureReason,retryOf,validityDaysAdded,fulfillmentGateway,apiProvider,executionType,executionTime,executedAt,completedAt,createdAt,pinCode,pinSerial,redeemInstructions]);

@override
String toString() {
  return 'TopupExecution(id: $id, scheduledTopupId: $scheduledTopupId, simLineId: $simLineId, userId: $userId, amount: $amount, currency: $currency, reloadlyTransactionId: $reloadlyTransactionId, status: $status, failureReason: $failureReason, retryOf: $retryOf, validityDaysAdded: $validityDaysAdded, fulfillmentGateway: $fulfillmentGateway, apiProvider: $apiProvider, executionType: $executionType, executionTime: $executionTime, executedAt: $executedAt, completedAt: $completedAt, createdAt: $createdAt, pinCode: $pinCode, pinSerial: $pinSerial, redeemInstructions: $redeemInstructions)';
}


}

/// @nodoc
abstract mixin class _$TopupExecutionCopyWith<$Res> implements $TopupExecutionCopyWith<$Res> {
  factory _$TopupExecutionCopyWith(_TopupExecution value, $Res Function(_TopupExecution) _then) = __$TopupExecutionCopyWithImpl;
@override @useResult
$Res call({
 String id, String? scheduledTopupId, String simLineId, String userId, double amount, String currency, String? reloadlyTransactionId, String status, String? failureReason, String? retryOf, int? validityDaysAdded, String? fulfillmentGateway, String? apiProvider, String? executionType, DateTime? executionTime, DateTime? executedAt, DateTime? completedAt, DateTime? createdAt, String? pinCode, String? pinSerial, String? redeemInstructions
});




}
/// @nodoc
class __$TopupExecutionCopyWithImpl<$Res>
    implements _$TopupExecutionCopyWith<$Res> {
  __$TopupExecutionCopyWithImpl(this._self, this._then);

  final _TopupExecution _self;
  final $Res Function(_TopupExecution) _then;

/// Create a copy of TopupExecution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scheduledTopupId = freezed,Object? simLineId = null,Object? userId = null,Object? amount = null,Object? currency = null,Object? reloadlyTransactionId = freezed,Object? status = null,Object? failureReason = freezed,Object? retryOf = freezed,Object? validityDaysAdded = freezed,Object? fulfillmentGateway = freezed,Object? apiProvider = freezed,Object? executionType = freezed,Object? executionTime = freezed,Object? executedAt = freezed,Object? completedAt = freezed,Object? createdAt = freezed,Object? pinCode = freezed,Object? pinSerial = freezed,Object? redeemInstructions = freezed,}) {
  return _then(_TopupExecution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scheduledTopupId: freezed == scheduledTopupId ? _self.scheduledTopupId : scheduledTopupId // ignore: cast_nullable_to_non_nullable
as String?,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,reloadlyTransactionId: freezed == reloadlyTransactionId ? _self.reloadlyTransactionId : reloadlyTransactionId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,retryOf: freezed == retryOf ? _self.retryOf : retryOf // ignore: cast_nullable_to_non_nullable
as String?,validityDaysAdded: freezed == validityDaysAdded ? _self.validityDaysAdded : validityDaysAdded // ignore: cast_nullable_to_non_nullable
as int?,fulfillmentGateway: freezed == fulfillmentGateway ? _self.fulfillmentGateway : fulfillmentGateway // ignore: cast_nullable_to_non_nullable
as String?,apiProvider: freezed == apiProvider ? _self.apiProvider : apiProvider // ignore: cast_nullable_to_non_nullable
as String?,executionType: freezed == executionType ? _self.executionType : executionType // ignore: cast_nullable_to_non_nullable
as String?,executionTime: freezed == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as DateTime?,executedAt: freezed == executedAt ? _self.executedAt : executedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pinCode: freezed == pinCode ? _self.pinCode : pinCode // ignore: cast_nullable_to_non_nullable
as String?,pinSerial: freezed == pinSerial ? _self.pinSerial : pinSerial // ignore: cast_nullable_to_non_nullable
as String?,redeemInstructions: freezed == redeemInstructions ? _self.redeemInstructions : redeemInstructions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
