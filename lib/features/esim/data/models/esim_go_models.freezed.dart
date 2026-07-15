// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'esim_go_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EsimGoBundleDto {

 String get name; String get description; int get dataAmount; int get duration; double get price; List<EsimGoCountryDto> get countries; List<EsimGoCountryDto> get roamingEnabled;
/// Create a copy of EsimGoBundleDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimGoBundleDtoCopyWith<EsimGoBundleDto> get copyWith => _$EsimGoBundleDtoCopyWithImpl<EsimGoBundleDto>(this as EsimGoBundleDto, _$identity);

  /// Serializes this EsimGoBundleDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimGoBundleDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.dataAmount, dataAmount) || other.dataAmount == dataAmount)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other.countries, countries)&&const DeepCollectionEquality().equals(other.roamingEnabled, roamingEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,dataAmount,duration,price,const DeepCollectionEquality().hash(countries),const DeepCollectionEquality().hash(roamingEnabled));

@override
String toString() {
  return 'EsimGoBundleDto(name: $name, description: $description, dataAmount: $dataAmount, duration: $duration, price: $price, countries: $countries, roamingEnabled: $roamingEnabled)';
}


}

/// @nodoc
abstract mixin class $EsimGoBundleDtoCopyWith<$Res>  {
  factory $EsimGoBundleDtoCopyWith(EsimGoBundleDto value, $Res Function(EsimGoBundleDto) _then) = _$EsimGoBundleDtoCopyWithImpl;
@useResult
$Res call({
 String name, String description, int dataAmount, int duration, double price, List<EsimGoCountryDto> countries, List<EsimGoCountryDto> roamingEnabled
});




}
/// @nodoc
class _$EsimGoBundleDtoCopyWithImpl<$Res>
    implements $EsimGoBundleDtoCopyWith<$Res> {
  _$EsimGoBundleDtoCopyWithImpl(this._self, this._then);

  final EsimGoBundleDto _self;
  final $Res Function(EsimGoBundleDto) _then;

/// Create a copy of EsimGoBundleDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? dataAmount = null,Object? duration = null,Object? price = null,Object? countries = null,Object? roamingEnabled = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,dataAmount: null == dataAmount ? _self.dataAmount : dataAmount // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,countries: null == countries ? _self.countries : countries // ignore: cast_nullable_to_non_nullable
as List<EsimGoCountryDto>,roamingEnabled: null == roamingEnabled ? _self.roamingEnabled : roamingEnabled // ignore: cast_nullable_to_non_nullable
as List<EsimGoCountryDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimGoBundleDto].
extension EsimGoBundleDtoPatterns on EsimGoBundleDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimGoBundleDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimGoBundleDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimGoBundleDto value)  $default,){
final _that = this;
switch (_that) {
case _EsimGoBundleDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimGoBundleDto value)?  $default,){
final _that = this;
switch (_that) {
case _EsimGoBundleDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  int dataAmount,  int duration,  double price,  List<EsimGoCountryDto> countries,  List<EsimGoCountryDto> roamingEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimGoBundleDto() when $default != null:
return $default(_that.name,_that.description,_that.dataAmount,_that.duration,_that.price,_that.countries,_that.roamingEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  int dataAmount,  int duration,  double price,  List<EsimGoCountryDto> countries,  List<EsimGoCountryDto> roamingEnabled)  $default,) {final _that = this;
switch (_that) {
case _EsimGoBundleDto():
return $default(_that.name,_that.description,_that.dataAmount,_that.duration,_that.price,_that.countries,_that.roamingEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  int dataAmount,  int duration,  double price,  List<EsimGoCountryDto> countries,  List<EsimGoCountryDto> roamingEnabled)?  $default,) {final _that = this;
switch (_that) {
case _EsimGoBundleDto() when $default != null:
return $default(_that.name,_that.description,_that.dataAmount,_that.duration,_that.price,_that.countries,_that.roamingEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimGoBundleDto implements EsimGoBundleDto {
  const _EsimGoBundleDto({required this.name, required this.description, required this.dataAmount, required this.duration, required this.price, final  List<EsimGoCountryDto> countries = const [], final  List<EsimGoCountryDto> roamingEnabled = const []}): _countries = countries,_roamingEnabled = roamingEnabled;
  factory _EsimGoBundleDto.fromJson(Map<String, dynamic> json) => _$EsimGoBundleDtoFromJson(json);

@override final  String name;
@override final  String description;
@override final  int dataAmount;
@override final  int duration;
@override final  double price;
 final  List<EsimGoCountryDto> _countries;
@override@JsonKey() List<EsimGoCountryDto> get countries {
  if (_countries is EqualUnmodifiableListView) return _countries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_countries);
}

 final  List<EsimGoCountryDto> _roamingEnabled;
@override@JsonKey() List<EsimGoCountryDto> get roamingEnabled {
  if (_roamingEnabled is EqualUnmodifiableListView) return _roamingEnabled;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roamingEnabled);
}


/// Create a copy of EsimGoBundleDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimGoBundleDtoCopyWith<_EsimGoBundleDto> get copyWith => __$EsimGoBundleDtoCopyWithImpl<_EsimGoBundleDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimGoBundleDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimGoBundleDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.dataAmount, dataAmount) || other.dataAmount == dataAmount)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other._countries, _countries)&&const DeepCollectionEquality().equals(other._roamingEnabled, _roamingEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,dataAmount,duration,price,const DeepCollectionEquality().hash(_countries),const DeepCollectionEquality().hash(_roamingEnabled));

@override
String toString() {
  return 'EsimGoBundleDto(name: $name, description: $description, dataAmount: $dataAmount, duration: $duration, price: $price, countries: $countries, roamingEnabled: $roamingEnabled)';
}


}

/// @nodoc
abstract mixin class _$EsimGoBundleDtoCopyWith<$Res> implements $EsimGoBundleDtoCopyWith<$Res> {
  factory _$EsimGoBundleDtoCopyWith(_EsimGoBundleDto value, $Res Function(_EsimGoBundleDto) _then) = __$EsimGoBundleDtoCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, int dataAmount, int duration, double price, List<EsimGoCountryDto> countries, List<EsimGoCountryDto> roamingEnabled
});




}
/// @nodoc
class __$EsimGoBundleDtoCopyWithImpl<$Res>
    implements _$EsimGoBundleDtoCopyWith<$Res> {
  __$EsimGoBundleDtoCopyWithImpl(this._self, this._then);

  final _EsimGoBundleDto _self;
  final $Res Function(_EsimGoBundleDto) _then;

/// Create a copy of EsimGoBundleDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? dataAmount = null,Object? duration = null,Object? price = null,Object? countries = null,Object? roamingEnabled = null,}) {
  return _then(_EsimGoBundleDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,dataAmount: null == dataAmount ? _self.dataAmount : dataAmount // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,countries: null == countries ? _self._countries : countries // ignore: cast_nullable_to_non_nullable
as List<EsimGoCountryDto>,roamingEnabled: null == roamingEnabled ? _self._roamingEnabled : roamingEnabled // ignore: cast_nullable_to_non_nullable
as List<EsimGoCountryDto>,
  ));
}


}


/// @nodoc
mixin _$EsimGoCountryDto {

 String get iso; String? get name;
/// Create a copy of EsimGoCountryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimGoCountryDtoCopyWith<EsimGoCountryDto> get copyWith => _$EsimGoCountryDtoCopyWithImpl<EsimGoCountryDto>(this as EsimGoCountryDto, _$identity);

  /// Serializes this EsimGoCountryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimGoCountryDto&&(identical(other.iso, iso) || other.iso == iso)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,iso,name);

@override
String toString() {
  return 'EsimGoCountryDto(iso: $iso, name: $name)';
}


}

/// @nodoc
abstract mixin class $EsimGoCountryDtoCopyWith<$Res>  {
  factory $EsimGoCountryDtoCopyWith(EsimGoCountryDto value, $Res Function(EsimGoCountryDto) _then) = _$EsimGoCountryDtoCopyWithImpl;
@useResult
$Res call({
 String iso, String? name
});




}
/// @nodoc
class _$EsimGoCountryDtoCopyWithImpl<$Res>
    implements $EsimGoCountryDtoCopyWith<$Res> {
  _$EsimGoCountryDtoCopyWithImpl(this._self, this._then);

  final EsimGoCountryDto _self;
  final $Res Function(EsimGoCountryDto) _then;

/// Create a copy of EsimGoCountryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? iso = null,Object? name = freezed,}) {
  return _then(_self.copyWith(
iso: null == iso ? _self.iso : iso // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimGoCountryDto].
extension EsimGoCountryDtoPatterns on EsimGoCountryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimGoCountryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimGoCountryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimGoCountryDto value)  $default,){
final _that = this;
switch (_that) {
case _EsimGoCountryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimGoCountryDto value)?  $default,){
final _that = this;
switch (_that) {
case _EsimGoCountryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String iso,  String? name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimGoCountryDto() when $default != null:
return $default(_that.iso,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String iso,  String? name)  $default,) {final _that = this;
switch (_that) {
case _EsimGoCountryDto():
return $default(_that.iso,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String iso,  String? name)?  $default,) {final _that = this;
switch (_that) {
case _EsimGoCountryDto() when $default != null:
return $default(_that.iso,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimGoCountryDto implements EsimGoCountryDto {
  const _EsimGoCountryDto({required this.iso, this.name});
  factory _EsimGoCountryDto.fromJson(Map<String, dynamic> json) => _$EsimGoCountryDtoFromJson(json);

@override final  String iso;
@override final  String? name;

/// Create a copy of EsimGoCountryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimGoCountryDtoCopyWith<_EsimGoCountryDto> get copyWith => __$EsimGoCountryDtoCopyWithImpl<_EsimGoCountryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimGoCountryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimGoCountryDto&&(identical(other.iso, iso) || other.iso == iso)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,iso,name);

@override
String toString() {
  return 'EsimGoCountryDto(iso: $iso, name: $name)';
}


}

/// @nodoc
abstract mixin class _$EsimGoCountryDtoCopyWith<$Res> implements $EsimGoCountryDtoCopyWith<$Res> {
  factory _$EsimGoCountryDtoCopyWith(_EsimGoCountryDto value, $Res Function(_EsimGoCountryDto) _then) = __$EsimGoCountryDtoCopyWithImpl;
@override @useResult
$Res call({
 String iso, String? name
});




}
/// @nodoc
class __$EsimGoCountryDtoCopyWithImpl<$Res>
    implements _$EsimGoCountryDtoCopyWith<$Res> {
  __$EsimGoCountryDtoCopyWithImpl(this._self, this._then);

  final _EsimGoCountryDto _self;
  final $Res Function(_EsimGoCountryDto) _then;

/// Create a copy of EsimGoCountryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? iso = null,Object? name = freezed,}) {
  return _then(_EsimGoCountryDto(
iso: null == iso ? _self.iso : iso // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$EsimGoOrderRequestDto {

 String get type; bool get assign;@JsonKey(name: 'Order') List<EsimGoOrderItemDto> get order;
/// Create a copy of EsimGoOrderRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimGoOrderRequestDtoCopyWith<EsimGoOrderRequestDto> get copyWith => _$EsimGoOrderRequestDtoCopyWithImpl<EsimGoOrderRequestDto>(this as EsimGoOrderRequestDto, _$identity);

  /// Serializes this EsimGoOrderRequestDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimGoOrderRequestDto&&(identical(other.type, type) || other.type == type)&&(identical(other.assign, assign) || other.assign == assign)&&const DeepCollectionEquality().equals(other.order, order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,assign,const DeepCollectionEquality().hash(order));

@override
String toString() {
  return 'EsimGoOrderRequestDto(type: $type, assign: $assign, order: $order)';
}


}

/// @nodoc
abstract mixin class $EsimGoOrderRequestDtoCopyWith<$Res>  {
  factory $EsimGoOrderRequestDtoCopyWith(EsimGoOrderRequestDto value, $Res Function(EsimGoOrderRequestDto) _then) = _$EsimGoOrderRequestDtoCopyWithImpl;
@useResult
$Res call({
 String type, bool assign,@JsonKey(name: 'Order') List<EsimGoOrderItemDto> order
});




}
/// @nodoc
class _$EsimGoOrderRequestDtoCopyWithImpl<$Res>
    implements $EsimGoOrderRequestDtoCopyWith<$Res> {
  _$EsimGoOrderRequestDtoCopyWithImpl(this._self, this._then);

  final EsimGoOrderRequestDto _self;
  final $Res Function(EsimGoOrderRequestDto) _then;

/// Create a copy of EsimGoOrderRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? assign = null,Object? order = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,assign: null == assign ? _self.assign : assign // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as List<EsimGoOrderItemDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimGoOrderRequestDto].
extension EsimGoOrderRequestDtoPatterns on EsimGoOrderRequestDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimGoOrderRequestDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimGoOrderRequestDto value)  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimGoOrderRequestDto value)?  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  bool assign, @JsonKey(name: 'Order')  List<EsimGoOrderItemDto> order)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto() when $default != null:
return $default(_that.type,_that.assign,_that.order);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  bool assign, @JsonKey(name: 'Order')  List<EsimGoOrderItemDto> order)  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto():
return $default(_that.type,_that.assign,_that.order);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  bool assign, @JsonKey(name: 'Order')  List<EsimGoOrderItemDto> order)?  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderRequestDto() when $default != null:
return $default(_that.type,_that.assign,_that.order);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _EsimGoOrderRequestDto implements EsimGoOrderRequestDto {
  const _EsimGoOrderRequestDto({required this.type, required this.assign, @JsonKey(name: 'Order') required final  List<EsimGoOrderItemDto> order}): _order = order;
  factory _EsimGoOrderRequestDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderRequestDtoFromJson(json);

@override final  String type;
@override final  bool assign;
 final  List<EsimGoOrderItemDto> _order;
@override@JsonKey(name: 'Order') List<EsimGoOrderItemDto> get order {
  if (_order is EqualUnmodifiableListView) return _order;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_order);
}


/// Create a copy of EsimGoOrderRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimGoOrderRequestDtoCopyWith<_EsimGoOrderRequestDto> get copyWith => __$EsimGoOrderRequestDtoCopyWithImpl<_EsimGoOrderRequestDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimGoOrderRequestDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimGoOrderRequestDto&&(identical(other.type, type) || other.type == type)&&(identical(other.assign, assign) || other.assign == assign)&&const DeepCollectionEquality().equals(other._order, _order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,assign,const DeepCollectionEquality().hash(_order));

@override
String toString() {
  return 'EsimGoOrderRequestDto(type: $type, assign: $assign, order: $order)';
}


}

/// @nodoc
abstract mixin class _$EsimGoOrderRequestDtoCopyWith<$Res> implements $EsimGoOrderRequestDtoCopyWith<$Res> {
  factory _$EsimGoOrderRequestDtoCopyWith(_EsimGoOrderRequestDto value, $Res Function(_EsimGoOrderRequestDto) _then) = __$EsimGoOrderRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 String type, bool assign,@JsonKey(name: 'Order') List<EsimGoOrderItemDto> order
});




}
/// @nodoc
class __$EsimGoOrderRequestDtoCopyWithImpl<$Res>
    implements _$EsimGoOrderRequestDtoCopyWith<$Res> {
  __$EsimGoOrderRequestDtoCopyWithImpl(this._self, this._then);

  final _EsimGoOrderRequestDto _self;
  final $Res Function(_EsimGoOrderRequestDto) _then;

/// Create a copy of EsimGoOrderRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? assign = null,Object? order = null,}) {
  return _then(_EsimGoOrderRequestDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,assign: null == assign ? _self.assign : assign // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self._order : order // ignore: cast_nullable_to_non_nullable
as List<EsimGoOrderItemDto>,
  ));
}


}


/// @nodoc
mixin _$EsimGoOrderItemDto {

 String get type; String get item; int get quantity;
/// Create a copy of EsimGoOrderItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimGoOrderItemDtoCopyWith<EsimGoOrderItemDto> get copyWith => _$EsimGoOrderItemDtoCopyWithImpl<EsimGoOrderItemDto>(this as EsimGoOrderItemDto, _$identity);

  /// Serializes this EsimGoOrderItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimGoOrderItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.item, item) || other.item == item)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,item,quantity);

@override
String toString() {
  return 'EsimGoOrderItemDto(type: $type, item: $item, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class $EsimGoOrderItemDtoCopyWith<$Res>  {
  factory $EsimGoOrderItemDtoCopyWith(EsimGoOrderItemDto value, $Res Function(EsimGoOrderItemDto) _then) = _$EsimGoOrderItemDtoCopyWithImpl;
@useResult
$Res call({
 String type, String item, int quantity
});




}
/// @nodoc
class _$EsimGoOrderItemDtoCopyWithImpl<$Res>
    implements $EsimGoOrderItemDtoCopyWith<$Res> {
  _$EsimGoOrderItemDtoCopyWithImpl(this._self, this._then);

  final EsimGoOrderItemDto _self;
  final $Res Function(EsimGoOrderItemDto) _then;

/// Create a copy of EsimGoOrderItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? item = null,Object? quantity = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimGoOrderItemDto].
extension EsimGoOrderItemDtoPatterns on EsimGoOrderItemDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimGoOrderItemDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimGoOrderItemDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimGoOrderItemDto value)  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderItemDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimGoOrderItemDto value)?  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderItemDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String item,  int quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimGoOrderItemDto() when $default != null:
return $default(_that.type,_that.item,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String item,  int quantity)  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderItemDto():
return $default(_that.type,_that.item,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String item,  int quantity)?  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderItemDto() when $default != null:
return $default(_that.type,_that.item,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimGoOrderItemDto implements EsimGoOrderItemDto {
  const _EsimGoOrderItemDto({required this.type, required this.item, required this.quantity});
  factory _EsimGoOrderItemDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderItemDtoFromJson(json);

@override final  String type;
@override final  String item;
@override final  int quantity;

/// Create a copy of EsimGoOrderItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimGoOrderItemDtoCopyWith<_EsimGoOrderItemDto> get copyWith => __$EsimGoOrderItemDtoCopyWithImpl<_EsimGoOrderItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimGoOrderItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimGoOrderItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.item, item) || other.item == item)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,item,quantity);

@override
String toString() {
  return 'EsimGoOrderItemDto(type: $type, item: $item, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$EsimGoOrderItemDtoCopyWith<$Res> implements $EsimGoOrderItemDtoCopyWith<$Res> {
  factory _$EsimGoOrderItemDtoCopyWith(_EsimGoOrderItemDto value, $Res Function(_EsimGoOrderItemDto) _then) = __$EsimGoOrderItemDtoCopyWithImpl;
@override @useResult
$Res call({
 String type, String item, int quantity
});




}
/// @nodoc
class __$EsimGoOrderItemDtoCopyWithImpl<$Res>
    implements _$EsimGoOrderItemDtoCopyWith<$Res> {
  __$EsimGoOrderItemDtoCopyWithImpl(this._self, this._then);

  final _EsimGoOrderItemDto _self;
  final $Res Function(_EsimGoOrderItemDto) _then;

/// Create a copy of EsimGoOrderItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? item = null,Object? quantity = null,}) {
  return _then(_EsimGoOrderItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$EsimGoOrderResponseDto {

 String? get orderReference; double? get total; String? get currency;
/// Create a copy of EsimGoOrderResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimGoOrderResponseDtoCopyWith<EsimGoOrderResponseDto> get copyWith => _$EsimGoOrderResponseDtoCopyWithImpl<EsimGoOrderResponseDto>(this as EsimGoOrderResponseDto, _$identity);

  /// Serializes this EsimGoOrderResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimGoOrderResponseDto&&(identical(other.orderReference, orderReference) || other.orderReference == orderReference)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderReference,total,currency);

@override
String toString() {
  return 'EsimGoOrderResponseDto(orderReference: $orderReference, total: $total, currency: $currency)';
}


}

/// @nodoc
abstract mixin class $EsimGoOrderResponseDtoCopyWith<$Res>  {
  factory $EsimGoOrderResponseDtoCopyWith(EsimGoOrderResponseDto value, $Res Function(EsimGoOrderResponseDto) _then) = _$EsimGoOrderResponseDtoCopyWithImpl;
@useResult
$Res call({
 String? orderReference, double? total, String? currency
});




}
/// @nodoc
class _$EsimGoOrderResponseDtoCopyWithImpl<$Res>
    implements $EsimGoOrderResponseDtoCopyWith<$Res> {
  _$EsimGoOrderResponseDtoCopyWithImpl(this._self, this._then);

  final EsimGoOrderResponseDto _self;
  final $Res Function(EsimGoOrderResponseDto) _then;

/// Create a copy of EsimGoOrderResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderReference = freezed,Object? total = freezed,Object? currency = freezed,}) {
  return _then(_self.copyWith(
orderReference: freezed == orderReference ? _self.orderReference : orderReference // ignore: cast_nullable_to_non_nullable
as String?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double?,currency: freezed == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimGoOrderResponseDto].
extension EsimGoOrderResponseDtoPatterns on EsimGoOrderResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimGoOrderResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimGoOrderResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimGoOrderResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? orderReference,  double? total,  String? currency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto() when $default != null:
return $default(_that.orderReference,_that.total,_that.currency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? orderReference,  double? total,  String? currency)  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto():
return $default(_that.orderReference,_that.total,_that.currency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? orderReference,  double? total,  String? currency)?  $default,) {final _that = this;
switch (_that) {
case _EsimGoOrderResponseDto() when $default != null:
return $default(_that.orderReference,_that.total,_that.currency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimGoOrderResponseDto implements EsimGoOrderResponseDto {
  const _EsimGoOrderResponseDto({this.orderReference, this.total, this.currency});
  factory _EsimGoOrderResponseDto.fromJson(Map<String, dynamic> json) => _$EsimGoOrderResponseDtoFromJson(json);

@override final  String? orderReference;
@override final  double? total;
@override final  String? currency;

/// Create a copy of EsimGoOrderResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimGoOrderResponseDtoCopyWith<_EsimGoOrderResponseDto> get copyWith => __$EsimGoOrderResponseDtoCopyWithImpl<_EsimGoOrderResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimGoOrderResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimGoOrderResponseDto&&(identical(other.orderReference, orderReference) || other.orderReference == orderReference)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderReference,total,currency);

@override
String toString() {
  return 'EsimGoOrderResponseDto(orderReference: $orderReference, total: $total, currency: $currency)';
}


}

/// @nodoc
abstract mixin class _$EsimGoOrderResponseDtoCopyWith<$Res> implements $EsimGoOrderResponseDtoCopyWith<$Res> {
  factory _$EsimGoOrderResponseDtoCopyWith(_EsimGoOrderResponseDto value, $Res Function(_EsimGoOrderResponseDto) _then) = __$EsimGoOrderResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 String? orderReference, double? total, String? currency
});




}
/// @nodoc
class __$EsimGoOrderResponseDtoCopyWithImpl<$Res>
    implements _$EsimGoOrderResponseDtoCopyWith<$Res> {
  __$EsimGoOrderResponseDtoCopyWithImpl(this._self, this._then);

  final _EsimGoOrderResponseDto _self;
  final $Res Function(_EsimGoOrderResponseDto) _then;

/// Create a copy of EsimGoOrderResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderReference = freezed,Object? total = freezed,Object? currency = freezed,}) {
  return _then(_EsimGoOrderResponseDto(
orderReference: freezed == orderReference ? _self.orderReference : orderReference // ignore: cast_nullable_to_non_nullable
as String?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double?,currency: freezed == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
