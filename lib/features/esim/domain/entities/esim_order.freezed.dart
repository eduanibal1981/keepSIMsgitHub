// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'esim_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EsimOrder {

 String get id; String get userId; String get provider; String get bundleName; int get quantity; double get wholesalePriceUsd; double get retailPriceUsd; double get markupPercent; String get status; String? get providerOrderRef; String? get errorMessage; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of EsimOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimOrderCopyWith<EsimOrder> get copyWith => _$EsimOrderCopyWithImpl<EsimOrder>(this as EsimOrder, _$identity);

  /// Serializes this EsimOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.bundleName, bundleName) || other.bundleName == bundleName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.wholesalePriceUsd, wholesalePriceUsd) || other.wholesalePriceUsd == wholesalePriceUsd)&&(identical(other.retailPriceUsd, retailPriceUsd) || other.retailPriceUsd == retailPriceUsd)&&(identical(other.markupPercent, markupPercent) || other.markupPercent == markupPercent)&&(identical(other.status, status) || other.status == status)&&(identical(other.providerOrderRef, providerOrderRef) || other.providerOrderRef == providerOrderRef)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,provider,bundleName,quantity,wholesalePriceUsd,retailPriceUsd,markupPercent,status,providerOrderRef,errorMessage,createdAt,updatedAt);

@override
String toString() {
  return 'EsimOrder(id: $id, userId: $userId, provider: $provider, bundleName: $bundleName, quantity: $quantity, wholesalePriceUsd: $wholesalePriceUsd, retailPriceUsd: $retailPriceUsd, markupPercent: $markupPercent, status: $status, providerOrderRef: $providerOrderRef, errorMessage: $errorMessage, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $EsimOrderCopyWith<$Res>  {
  factory $EsimOrderCopyWith(EsimOrder value, $Res Function(EsimOrder) _then) = _$EsimOrderCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String provider, String bundleName, int quantity, double wholesalePriceUsd, double retailPriceUsd, double markupPercent, String status, String? providerOrderRef, String? errorMessage, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$EsimOrderCopyWithImpl<$Res>
    implements $EsimOrderCopyWith<$Res> {
  _$EsimOrderCopyWithImpl(this._self, this._then);

  final EsimOrder _self;
  final $Res Function(EsimOrder) _then;

/// Create a copy of EsimOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? provider = null,Object? bundleName = null,Object? quantity = null,Object? wholesalePriceUsd = null,Object? retailPriceUsd = null,Object? markupPercent = null,Object? status = null,Object? providerOrderRef = freezed,Object? errorMessage = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,bundleName: null == bundleName ? _self.bundleName : bundleName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,wholesalePriceUsd: null == wholesalePriceUsd ? _self.wholesalePriceUsd : wholesalePriceUsd // ignore: cast_nullable_to_non_nullable
as double,retailPriceUsd: null == retailPriceUsd ? _self.retailPriceUsd : retailPriceUsd // ignore: cast_nullable_to_non_nullable
as double,markupPercent: null == markupPercent ? _self.markupPercent : markupPercent // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,providerOrderRef: freezed == providerOrderRef ? _self.providerOrderRef : providerOrderRef // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimOrder].
extension EsimOrderPatterns on EsimOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimOrder value)  $default,){
final _that = this;
switch (_that) {
case _EsimOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimOrder value)?  $default,){
final _that = this;
switch (_that) {
case _EsimOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String provider,  String bundleName,  int quantity,  double wholesalePriceUsd,  double retailPriceUsd,  double markupPercent,  String status,  String? providerOrderRef,  String? errorMessage,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimOrder() when $default != null:
return $default(_that.id,_that.userId,_that.provider,_that.bundleName,_that.quantity,_that.wholesalePriceUsd,_that.retailPriceUsd,_that.markupPercent,_that.status,_that.providerOrderRef,_that.errorMessage,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String provider,  String bundleName,  int quantity,  double wholesalePriceUsd,  double retailPriceUsd,  double markupPercent,  String status,  String? providerOrderRef,  String? errorMessage,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _EsimOrder():
return $default(_that.id,_that.userId,_that.provider,_that.bundleName,_that.quantity,_that.wholesalePriceUsd,_that.retailPriceUsd,_that.markupPercent,_that.status,_that.providerOrderRef,_that.errorMessage,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String provider,  String bundleName,  int quantity,  double wholesalePriceUsd,  double retailPriceUsd,  double markupPercent,  String status,  String? providerOrderRef,  String? errorMessage,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _EsimOrder() when $default != null:
return $default(_that.id,_that.userId,_that.provider,_that.bundleName,_that.quantity,_that.wholesalePriceUsd,_that.retailPriceUsd,_that.markupPercent,_that.status,_that.providerOrderRef,_that.errorMessage,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimOrder implements EsimOrder {
  const _EsimOrder({required this.id, required this.userId, required this.provider, required this.bundleName, required this.quantity, required this.wholesalePriceUsd, required this.retailPriceUsd, required this.markupPercent, required this.status, this.providerOrderRef, this.errorMessage, required this.createdAt, required this.updatedAt});
  factory _EsimOrder.fromJson(Map<String, dynamic> json) => _$EsimOrderFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String provider;
@override final  String bundleName;
@override final  int quantity;
@override final  double wholesalePriceUsd;
@override final  double retailPriceUsd;
@override final  double markupPercent;
@override final  String status;
@override final  String? providerOrderRef;
@override final  String? errorMessage;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of EsimOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimOrderCopyWith<_EsimOrder> get copyWith => __$EsimOrderCopyWithImpl<_EsimOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.bundleName, bundleName) || other.bundleName == bundleName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.wholesalePriceUsd, wholesalePriceUsd) || other.wholesalePriceUsd == wholesalePriceUsd)&&(identical(other.retailPriceUsd, retailPriceUsd) || other.retailPriceUsd == retailPriceUsd)&&(identical(other.markupPercent, markupPercent) || other.markupPercent == markupPercent)&&(identical(other.status, status) || other.status == status)&&(identical(other.providerOrderRef, providerOrderRef) || other.providerOrderRef == providerOrderRef)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,provider,bundleName,quantity,wholesalePriceUsd,retailPriceUsd,markupPercent,status,providerOrderRef,errorMessage,createdAt,updatedAt);

@override
String toString() {
  return 'EsimOrder(id: $id, userId: $userId, provider: $provider, bundleName: $bundleName, quantity: $quantity, wholesalePriceUsd: $wholesalePriceUsd, retailPriceUsd: $retailPriceUsd, markupPercent: $markupPercent, status: $status, providerOrderRef: $providerOrderRef, errorMessage: $errorMessage, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$EsimOrderCopyWith<$Res> implements $EsimOrderCopyWith<$Res> {
  factory _$EsimOrderCopyWith(_EsimOrder value, $Res Function(_EsimOrder) _then) = __$EsimOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String provider, String bundleName, int quantity, double wholesalePriceUsd, double retailPriceUsd, double markupPercent, String status, String? providerOrderRef, String? errorMessage, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$EsimOrderCopyWithImpl<$Res>
    implements _$EsimOrderCopyWith<$Res> {
  __$EsimOrderCopyWithImpl(this._self, this._then);

  final _EsimOrder _self;
  final $Res Function(_EsimOrder) _then;

/// Create a copy of EsimOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? provider = null,Object? bundleName = null,Object? quantity = null,Object? wholesalePriceUsd = null,Object? retailPriceUsd = null,Object? markupPercent = null,Object? status = null,Object? providerOrderRef = freezed,Object? errorMessage = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_EsimOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,bundleName: null == bundleName ? _self.bundleName : bundleName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,wholesalePriceUsd: null == wholesalePriceUsd ? _self.wholesalePriceUsd : wholesalePriceUsd // ignore: cast_nullable_to_non_nullable
as double,retailPriceUsd: null == retailPriceUsd ? _self.retailPriceUsd : retailPriceUsd // ignore: cast_nullable_to_non_nullable
as double,markupPercent: null == markupPercent ? _self.markupPercent : markupPercent // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,providerOrderRef: freezed == providerOrderRef ? _self.providerOrderRef : providerOrderRef // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
