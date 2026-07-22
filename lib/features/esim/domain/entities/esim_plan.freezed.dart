// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'esim_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EsimPlan {

 String get id; String get name; int get dataAmountMB; int get durationDays; double get priceUsd; String get providerName; List<String> get supportedCountries; List<String> get roamingEnabled; String? get description; String? get imageUrl;
/// Create a copy of EsimPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EsimPlanCopyWith<EsimPlan> get copyWith => _$EsimPlanCopyWithImpl<EsimPlan>(this as EsimPlan, _$identity);

  /// Serializes this EsimPlan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EsimPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dataAmountMB, dataAmountMB) || other.dataAmountMB == dataAmountMB)&&(identical(other.durationDays, durationDays) || other.durationDays == durationDays)&&(identical(other.priceUsd, priceUsd) || other.priceUsd == priceUsd)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other.supportedCountries, supportedCountries)&&const DeepCollectionEquality().equals(other.roamingEnabled, roamingEnabled)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dataAmountMB,durationDays,priceUsd,providerName,const DeepCollectionEquality().hash(supportedCountries),const DeepCollectionEquality().hash(roamingEnabled),description,imageUrl);

@override
String toString() {
  return 'EsimPlan(id: $id, name: $name, dataAmountMB: $dataAmountMB, durationDays: $durationDays, priceUsd: $priceUsd, providerName: $providerName, supportedCountries: $supportedCountries, roamingEnabled: $roamingEnabled, description: $description, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $EsimPlanCopyWith<$Res>  {
  factory $EsimPlanCopyWith(EsimPlan value, $Res Function(EsimPlan) _then) = _$EsimPlanCopyWithImpl;
@useResult
$Res call({
 String id, String name, int dataAmountMB, int durationDays, double priceUsd, String providerName, List<String> supportedCountries, List<String> roamingEnabled, String? description, String? imageUrl
});




}
/// @nodoc
class _$EsimPlanCopyWithImpl<$Res>
    implements $EsimPlanCopyWith<$Res> {
  _$EsimPlanCopyWithImpl(this._self, this._then);

  final EsimPlan _self;
  final $Res Function(EsimPlan) _then;

/// Create a copy of EsimPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? dataAmountMB = null,Object? durationDays = null,Object? priceUsd = null,Object? providerName = null,Object? supportedCountries = null,Object? roamingEnabled = null,Object? description = freezed,Object? imageUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dataAmountMB: null == dataAmountMB ? _self.dataAmountMB : dataAmountMB // ignore: cast_nullable_to_non_nullable
as int,durationDays: null == durationDays ? _self.durationDays : durationDays // ignore: cast_nullable_to_non_nullable
as int,priceUsd: null == priceUsd ? _self.priceUsd : priceUsd // ignore: cast_nullable_to_non_nullable
as double,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,supportedCountries: null == supportedCountries ? _self.supportedCountries : supportedCountries // ignore: cast_nullable_to_non_nullable
as List<String>,roamingEnabled: null == roamingEnabled ? _self.roamingEnabled : roamingEnabled // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EsimPlan].
extension EsimPlanPatterns on EsimPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EsimPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EsimPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EsimPlan value)  $default,){
final _that = this;
switch (_that) {
case _EsimPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EsimPlan value)?  $default,){
final _that = this;
switch (_that) {
case _EsimPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int dataAmountMB,  int durationDays,  double priceUsd,  String providerName,  List<String> supportedCountries,  List<String> roamingEnabled,  String? description,  String? imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EsimPlan() when $default != null:
return $default(_that.id,_that.name,_that.dataAmountMB,_that.durationDays,_that.priceUsd,_that.providerName,_that.supportedCountries,_that.roamingEnabled,_that.description,_that.imageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int dataAmountMB,  int durationDays,  double priceUsd,  String providerName,  List<String> supportedCountries,  List<String> roamingEnabled,  String? description,  String? imageUrl)  $default,) {final _that = this;
switch (_that) {
case _EsimPlan():
return $default(_that.id,_that.name,_that.dataAmountMB,_that.durationDays,_that.priceUsd,_that.providerName,_that.supportedCountries,_that.roamingEnabled,_that.description,_that.imageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int dataAmountMB,  int durationDays,  double priceUsd,  String providerName,  List<String> supportedCountries,  List<String> roamingEnabled,  String? description,  String? imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _EsimPlan() when $default != null:
return $default(_that.id,_that.name,_that.dataAmountMB,_that.durationDays,_that.priceUsd,_that.providerName,_that.supportedCountries,_that.roamingEnabled,_that.description,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EsimPlan extends EsimPlan {
  const _EsimPlan({required this.id, required this.name, required this.dataAmountMB, required this.durationDays, required this.priceUsd, required this.providerName, final  List<String> supportedCountries = const [], final  List<String> roamingEnabled = const [], this.description, this.imageUrl}): _supportedCountries = supportedCountries,_roamingEnabled = roamingEnabled,super._();
  factory _EsimPlan.fromJson(Map<String, dynamic> json) => _$EsimPlanFromJson(json);

@override final  String id;
@override final  String name;
@override final  int dataAmountMB;
@override final  int durationDays;
@override final  double priceUsd;
@override final  String providerName;
 final  List<String> _supportedCountries;
@override@JsonKey() List<String> get supportedCountries {
  if (_supportedCountries is EqualUnmodifiableListView) return _supportedCountries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedCountries);
}

 final  List<String> _roamingEnabled;
@override@JsonKey() List<String> get roamingEnabled {
  if (_roamingEnabled is EqualUnmodifiableListView) return _roamingEnabled;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_roamingEnabled);
}

@override final  String? description;
@override final  String? imageUrl;

/// Create a copy of EsimPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EsimPlanCopyWith<_EsimPlan> get copyWith => __$EsimPlanCopyWithImpl<_EsimPlan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EsimPlanToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EsimPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dataAmountMB, dataAmountMB) || other.dataAmountMB == dataAmountMB)&&(identical(other.durationDays, durationDays) || other.durationDays == durationDays)&&(identical(other.priceUsd, priceUsd) || other.priceUsd == priceUsd)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other._supportedCountries, _supportedCountries)&&const DeepCollectionEquality().equals(other._roamingEnabled, _roamingEnabled)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,dataAmountMB,durationDays,priceUsd,providerName,const DeepCollectionEquality().hash(_supportedCountries),const DeepCollectionEquality().hash(_roamingEnabled),description,imageUrl);

@override
String toString() {
  return 'EsimPlan(id: $id, name: $name, dataAmountMB: $dataAmountMB, durationDays: $durationDays, priceUsd: $priceUsd, providerName: $providerName, supportedCountries: $supportedCountries, roamingEnabled: $roamingEnabled, description: $description, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$EsimPlanCopyWith<$Res> implements $EsimPlanCopyWith<$Res> {
  factory _$EsimPlanCopyWith(_EsimPlan value, $Res Function(_EsimPlan) _then) = __$EsimPlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int dataAmountMB, int durationDays, double priceUsd, String providerName, List<String> supportedCountries, List<String> roamingEnabled, String? description, String? imageUrl
});




}
/// @nodoc
class __$EsimPlanCopyWithImpl<$Res>
    implements _$EsimPlanCopyWith<$Res> {
  __$EsimPlanCopyWithImpl(this._self, this._then);

  final _EsimPlan _self;
  final $Res Function(_EsimPlan) _then;

/// Create a copy of EsimPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? dataAmountMB = null,Object? durationDays = null,Object? priceUsd = null,Object? providerName = null,Object? supportedCountries = null,Object? roamingEnabled = null,Object? description = freezed,Object? imageUrl = freezed,}) {
  return _then(_EsimPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dataAmountMB: null == dataAmountMB ? _self.dataAmountMB : dataAmountMB // ignore: cast_nullable_to_non_nullable
as int,durationDays: null == durationDays ? _self.durationDays : durationDays // ignore: cast_nullable_to_non_nullable
as int,priceUsd: null == priceUsd ? _self.priceUsd : priceUsd // ignore: cast_nullable_to_non_nullable
as double,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,supportedCountries: null == supportedCountries ? _self._supportedCountries : supportedCountries // ignore: cast_nullable_to_non_nullable
as List<String>,roamingEnabled: null == roamingEnabled ? _self._roamingEnabled : roamingEnabled // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
