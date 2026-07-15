// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'carrier_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Carrier {

 String get id;@JsonKey(name: 'country_id') String get countryId; String get name;@JsonKey(name: 'logo_url') String? get logoUrl;@JsonKey(name: 'reloadly_operator_id') int? get reloadlyOperatorId;@JsonKey(name: 'is_supported') bool get isSupported;@JsonKey(name: 'fulfillment_gateway') String? get fulfillmentGateway;@JsonKey(name: 'api_provider') String? get apiProvider;@JsonKey(name: 'default_refill_amount', fromJson: _parseDouble) double get defaultRefillAmount;@JsonKey(name: 'gateway_phone_number') String? get gatewayPhoneNumber;
/// Create a copy of Carrier
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CarrierCopyWith<Carrier> get copyWith => _$CarrierCopyWithImpl<Carrier>(this as Carrier, _$identity);

  /// Serializes this Carrier to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Carrier&&(identical(other.id, id) || other.id == id)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.reloadlyOperatorId, reloadlyOperatorId) || other.reloadlyOperatorId == reloadlyOperatorId)&&(identical(other.isSupported, isSupported) || other.isSupported == isSupported)&&(identical(other.fulfillmentGateway, fulfillmentGateway) || other.fulfillmentGateway == fulfillmentGateway)&&(identical(other.apiProvider, apiProvider) || other.apiProvider == apiProvider)&&(identical(other.defaultRefillAmount, defaultRefillAmount) || other.defaultRefillAmount == defaultRefillAmount)&&(identical(other.gatewayPhoneNumber, gatewayPhoneNumber) || other.gatewayPhoneNumber == gatewayPhoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,countryId,name,logoUrl,reloadlyOperatorId,isSupported,fulfillmentGateway,apiProvider,defaultRefillAmount,gatewayPhoneNumber);

@override
String toString() {
  return 'Carrier(id: $id, countryId: $countryId, name: $name, logoUrl: $logoUrl, reloadlyOperatorId: $reloadlyOperatorId, isSupported: $isSupported, fulfillmentGateway: $fulfillmentGateway, apiProvider: $apiProvider, defaultRefillAmount: $defaultRefillAmount, gatewayPhoneNumber: $gatewayPhoneNumber)';
}


}

/// @nodoc
abstract mixin class $CarrierCopyWith<$Res>  {
  factory $CarrierCopyWith(Carrier value, $Res Function(Carrier) _then) = _$CarrierCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'country_id') String countryId, String name,@JsonKey(name: 'logo_url') String? logoUrl,@JsonKey(name: 'reloadly_operator_id') int? reloadlyOperatorId,@JsonKey(name: 'is_supported') bool isSupported,@JsonKey(name: 'fulfillment_gateway') String? fulfillmentGateway,@JsonKey(name: 'api_provider') String? apiProvider,@JsonKey(name: 'default_refill_amount', fromJson: _parseDouble) double defaultRefillAmount,@JsonKey(name: 'gateway_phone_number') String? gatewayPhoneNumber
});




}
/// @nodoc
class _$CarrierCopyWithImpl<$Res>
    implements $CarrierCopyWith<$Res> {
  _$CarrierCopyWithImpl(this._self, this._then);

  final Carrier _self;
  final $Res Function(Carrier) _then;

/// Create a copy of Carrier
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? countryId = null,Object? name = null,Object? logoUrl = freezed,Object? reloadlyOperatorId = freezed,Object? isSupported = null,Object? fulfillmentGateway = freezed,Object? apiProvider = freezed,Object? defaultRefillAmount = null,Object? gatewayPhoneNumber = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,reloadlyOperatorId: freezed == reloadlyOperatorId ? _self.reloadlyOperatorId : reloadlyOperatorId // ignore: cast_nullable_to_non_nullable
as int?,isSupported: null == isSupported ? _self.isSupported : isSupported // ignore: cast_nullable_to_non_nullable
as bool,fulfillmentGateway: freezed == fulfillmentGateway ? _self.fulfillmentGateway : fulfillmentGateway // ignore: cast_nullable_to_non_nullable
as String?,apiProvider: freezed == apiProvider ? _self.apiProvider : apiProvider // ignore: cast_nullable_to_non_nullable
as String?,defaultRefillAmount: null == defaultRefillAmount ? _self.defaultRefillAmount : defaultRefillAmount // ignore: cast_nullable_to_non_nullable
as double,gatewayPhoneNumber: freezed == gatewayPhoneNumber ? _self.gatewayPhoneNumber : gatewayPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Carrier].
extension CarrierPatterns on Carrier {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Carrier value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Carrier() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Carrier value)  $default,){
final _that = this;
switch (_that) {
case _Carrier():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Carrier value)?  $default,){
final _that = this;
switch (_that) {
case _Carrier() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'country_id')  String countryId,  String name, @JsonKey(name: 'logo_url')  String? logoUrl, @JsonKey(name: 'reloadly_operator_id')  int? reloadlyOperatorId, @JsonKey(name: 'is_supported')  bool isSupported, @JsonKey(name: 'fulfillment_gateway')  String? fulfillmentGateway, @JsonKey(name: 'api_provider')  String? apiProvider, @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble)  double defaultRefillAmount, @JsonKey(name: 'gateway_phone_number')  String? gatewayPhoneNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Carrier() when $default != null:
return $default(_that.id,_that.countryId,_that.name,_that.logoUrl,_that.reloadlyOperatorId,_that.isSupported,_that.fulfillmentGateway,_that.apiProvider,_that.defaultRefillAmount,_that.gatewayPhoneNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'country_id')  String countryId,  String name, @JsonKey(name: 'logo_url')  String? logoUrl, @JsonKey(name: 'reloadly_operator_id')  int? reloadlyOperatorId, @JsonKey(name: 'is_supported')  bool isSupported, @JsonKey(name: 'fulfillment_gateway')  String? fulfillmentGateway, @JsonKey(name: 'api_provider')  String? apiProvider, @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble)  double defaultRefillAmount, @JsonKey(name: 'gateway_phone_number')  String? gatewayPhoneNumber)  $default,) {final _that = this;
switch (_that) {
case _Carrier():
return $default(_that.id,_that.countryId,_that.name,_that.logoUrl,_that.reloadlyOperatorId,_that.isSupported,_that.fulfillmentGateway,_that.apiProvider,_that.defaultRefillAmount,_that.gatewayPhoneNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'country_id')  String countryId,  String name, @JsonKey(name: 'logo_url')  String? logoUrl, @JsonKey(name: 'reloadly_operator_id')  int? reloadlyOperatorId, @JsonKey(name: 'is_supported')  bool isSupported, @JsonKey(name: 'fulfillment_gateway')  String? fulfillmentGateway, @JsonKey(name: 'api_provider')  String? apiProvider, @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble)  double defaultRefillAmount, @JsonKey(name: 'gateway_phone_number')  String? gatewayPhoneNumber)?  $default,) {final _that = this;
switch (_that) {
case _Carrier() when $default != null:
return $default(_that.id,_that.countryId,_that.name,_that.logoUrl,_that.reloadlyOperatorId,_that.isSupported,_that.fulfillmentGateway,_that.apiProvider,_that.defaultRefillAmount,_that.gatewayPhoneNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Carrier implements Carrier {
  const _Carrier({required this.id, @JsonKey(name: 'country_id') required this.countryId, required this.name, @JsonKey(name: 'logo_url') this.logoUrl, @JsonKey(name: 'reloadly_operator_id') this.reloadlyOperatorId, @JsonKey(name: 'is_supported') required this.isSupported, @JsonKey(name: 'fulfillment_gateway') this.fulfillmentGateway, @JsonKey(name: 'api_provider') this.apiProvider, @JsonKey(name: 'default_refill_amount', fromJson: _parseDouble) this.defaultRefillAmount = 5.00, @JsonKey(name: 'gateway_phone_number') this.gatewayPhoneNumber});
  factory _Carrier.fromJson(Map<String, dynamic> json) => _$CarrierFromJson(json);

@override final  String id;
@override@JsonKey(name: 'country_id') final  String countryId;
@override final  String name;
@override@JsonKey(name: 'logo_url') final  String? logoUrl;
@override@JsonKey(name: 'reloadly_operator_id') final  int? reloadlyOperatorId;
@override@JsonKey(name: 'is_supported') final  bool isSupported;
@override@JsonKey(name: 'fulfillment_gateway') final  String? fulfillmentGateway;
@override@JsonKey(name: 'api_provider') final  String? apiProvider;
@override@JsonKey(name: 'default_refill_amount', fromJson: _parseDouble) final  double defaultRefillAmount;
@override@JsonKey(name: 'gateway_phone_number') final  String? gatewayPhoneNumber;

/// Create a copy of Carrier
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CarrierCopyWith<_Carrier> get copyWith => __$CarrierCopyWithImpl<_Carrier>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CarrierToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Carrier&&(identical(other.id, id) || other.id == id)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.reloadlyOperatorId, reloadlyOperatorId) || other.reloadlyOperatorId == reloadlyOperatorId)&&(identical(other.isSupported, isSupported) || other.isSupported == isSupported)&&(identical(other.fulfillmentGateway, fulfillmentGateway) || other.fulfillmentGateway == fulfillmentGateway)&&(identical(other.apiProvider, apiProvider) || other.apiProvider == apiProvider)&&(identical(other.defaultRefillAmount, defaultRefillAmount) || other.defaultRefillAmount == defaultRefillAmount)&&(identical(other.gatewayPhoneNumber, gatewayPhoneNumber) || other.gatewayPhoneNumber == gatewayPhoneNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,countryId,name,logoUrl,reloadlyOperatorId,isSupported,fulfillmentGateway,apiProvider,defaultRefillAmount,gatewayPhoneNumber);

@override
String toString() {
  return 'Carrier(id: $id, countryId: $countryId, name: $name, logoUrl: $logoUrl, reloadlyOperatorId: $reloadlyOperatorId, isSupported: $isSupported, fulfillmentGateway: $fulfillmentGateway, apiProvider: $apiProvider, defaultRefillAmount: $defaultRefillAmount, gatewayPhoneNumber: $gatewayPhoneNumber)';
}


}

/// @nodoc
abstract mixin class _$CarrierCopyWith<$Res> implements $CarrierCopyWith<$Res> {
  factory _$CarrierCopyWith(_Carrier value, $Res Function(_Carrier) _then) = __$CarrierCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'country_id') String countryId, String name,@JsonKey(name: 'logo_url') String? logoUrl,@JsonKey(name: 'reloadly_operator_id') int? reloadlyOperatorId,@JsonKey(name: 'is_supported') bool isSupported,@JsonKey(name: 'fulfillment_gateway') String? fulfillmentGateway,@JsonKey(name: 'api_provider') String? apiProvider,@JsonKey(name: 'default_refill_amount', fromJson: _parseDouble) double defaultRefillAmount,@JsonKey(name: 'gateway_phone_number') String? gatewayPhoneNumber
});




}
/// @nodoc
class __$CarrierCopyWithImpl<$Res>
    implements _$CarrierCopyWith<$Res> {
  __$CarrierCopyWithImpl(this._self, this._then);

  final _Carrier _self;
  final $Res Function(_Carrier) _then;

/// Create a copy of Carrier
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? countryId = null,Object? name = null,Object? logoUrl = freezed,Object? reloadlyOperatorId = freezed,Object? isSupported = null,Object? fulfillmentGateway = freezed,Object? apiProvider = freezed,Object? defaultRefillAmount = null,Object? gatewayPhoneNumber = freezed,}) {
  return _then(_Carrier(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,reloadlyOperatorId: freezed == reloadlyOperatorId ? _self.reloadlyOperatorId : reloadlyOperatorId // ignore: cast_nullable_to_non_nullable
as int?,isSupported: null == isSupported ? _self.isSupported : isSupported // ignore: cast_nullable_to_non_nullable
as bool,fulfillmentGateway: freezed == fulfillmentGateway ? _self.fulfillmentGateway : fulfillmentGateway // ignore: cast_nullable_to_non_nullable
as String?,apiProvider: freezed == apiProvider ? _self.apiProvider : apiProvider // ignore: cast_nullable_to_non_nullable
as String?,defaultRefillAmount: null == defaultRefillAmount ? _self.defaultRefillAmount : defaultRefillAmount // ignore: cast_nullable_to_non_nullable
as double,gatewayPhoneNumber: freezed == gatewayPhoneNumber ? _self.gatewayPhoneNumber : gatewayPhoneNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
