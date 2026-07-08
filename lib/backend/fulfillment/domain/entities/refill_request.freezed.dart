// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'refill_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RefillRequest {

 String get id;@JsonKey(name: 'corporate_line_id') String get corporateLineId; String get source; double get amount; String get status;@JsonKey(name: 'fulfillment_method_used') String? get fulfillmentMethodUsed;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of RefillRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RefillRequestCopyWith<RefillRequest> get copyWith => _$RefillRequestCopyWithImpl<RefillRequest>(this as RefillRequest, _$identity);

  /// Serializes this RefillRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RefillRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.corporateLineId, corporateLineId) || other.corporateLineId == corporateLineId)&&(identical(other.source, source) || other.source == source)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.fulfillmentMethodUsed, fulfillmentMethodUsed) || other.fulfillmentMethodUsed == fulfillmentMethodUsed)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,corporateLineId,source,amount,status,fulfillmentMethodUsed,createdAt,updatedAt);

@override
String toString() {
  return 'RefillRequest(id: $id, corporateLineId: $corporateLineId, source: $source, amount: $amount, status: $status, fulfillmentMethodUsed: $fulfillmentMethodUsed, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $RefillRequestCopyWith<$Res>  {
  factory $RefillRequestCopyWith(RefillRequest value, $Res Function(RefillRequest) _then) = _$RefillRequestCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'corporate_line_id') String corporateLineId, String source, double amount, String status,@JsonKey(name: 'fulfillment_method_used') String? fulfillmentMethodUsed,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$RefillRequestCopyWithImpl<$Res>
    implements $RefillRequestCopyWith<$Res> {
  _$RefillRequestCopyWithImpl(this._self, this._then);

  final RefillRequest _self;
  final $Res Function(RefillRequest) _then;

/// Create a copy of RefillRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? corporateLineId = null,Object? source = null,Object? amount = null,Object? status = null,Object? fulfillmentMethodUsed = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,corporateLineId: null == corporateLineId ? _self.corporateLineId : corporateLineId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fulfillmentMethodUsed: freezed == fulfillmentMethodUsed ? _self.fulfillmentMethodUsed : fulfillmentMethodUsed // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [RefillRequest].
extension RefillRequestPatterns on RefillRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RefillRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RefillRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RefillRequest value)  $default,){
final _that = this;
switch (_that) {
case _RefillRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RefillRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RefillRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'corporate_line_id')  String corporateLineId,  String source,  double amount,  String status, @JsonKey(name: 'fulfillment_method_used')  String? fulfillmentMethodUsed, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RefillRequest() when $default != null:
return $default(_that.id,_that.corporateLineId,_that.source,_that.amount,_that.status,_that.fulfillmentMethodUsed,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'corporate_line_id')  String corporateLineId,  String source,  double amount,  String status, @JsonKey(name: 'fulfillment_method_used')  String? fulfillmentMethodUsed, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _RefillRequest():
return $default(_that.id,_that.corporateLineId,_that.source,_that.amount,_that.status,_that.fulfillmentMethodUsed,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'corporate_line_id')  String corporateLineId,  String source,  double amount,  String status, @JsonKey(name: 'fulfillment_method_used')  String? fulfillmentMethodUsed, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _RefillRequest() when $default != null:
return $default(_that.id,_that.corporateLineId,_that.source,_that.amount,_that.status,_that.fulfillmentMethodUsed,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RefillRequest implements RefillRequest {
  const _RefillRequest({required this.id, @JsonKey(name: 'corporate_line_id') required this.corporateLineId, required this.source, required this.amount, required this.status, @JsonKey(name: 'fulfillment_method_used') this.fulfillmentMethodUsed, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _RefillRequest.fromJson(Map<String, dynamic> json) => _$RefillRequestFromJson(json);

@override final  String id;
@override@JsonKey(name: 'corporate_line_id') final  String corporateLineId;
@override final  String source;
@override final  double amount;
@override final  String status;
@override@JsonKey(name: 'fulfillment_method_used') final  String? fulfillmentMethodUsed;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of RefillRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefillRequestCopyWith<_RefillRequest> get copyWith => __$RefillRequestCopyWithImpl<_RefillRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RefillRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefillRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.corporateLineId, corporateLineId) || other.corporateLineId == corporateLineId)&&(identical(other.source, source) || other.source == source)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.fulfillmentMethodUsed, fulfillmentMethodUsed) || other.fulfillmentMethodUsed == fulfillmentMethodUsed)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,corporateLineId,source,amount,status,fulfillmentMethodUsed,createdAt,updatedAt);

@override
String toString() {
  return 'RefillRequest(id: $id, corporateLineId: $corporateLineId, source: $source, amount: $amount, status: $status, fulfillmentMethodUsed: $fulfillmentMethodUsed, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$RefillRequestCopyWith<$Res> implements $RefillRequestCopyWith<$Res> {
  factory _$RefillRequestCopyWith(_RefillRequest value, $Res Function(_RefillRequest) _then) = __$RefillRequestCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'corporate_line_id') String corporateLineId, String source, double amount, String status,@JsonKey(name: 'fulfillment_method_used') String? fulfillmentMethodUsed,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$RefillRequestCopyWithImpl<$Res>
    implements _$RefillRequestCopyWith<$Res> {
  __$RefillRequestCopyWithImpl(this._self, this._then);

  final _RefillRequest _self;
  final $Res Function(_RefillRequest) _then;

/// Create a copy of RefillRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? corporateLineId = null,Object? source = null,Object? amount = null,Object? status = null,Object? fulfillmentMethodUsed = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_RefillRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,corporateLineId: null == corporateLineId ? _self.corporateLineId : corporateLineId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fulfillmentMethodUsed: freezed == fulfillmentMethodUsed ? _self.fulfillmentMethodUsed : fulfillmentMethodUsed // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
