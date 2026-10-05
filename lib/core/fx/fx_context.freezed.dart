// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fx_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FxContext {

/// The global brake (`FX_DISPLAY_ENABLED`).
 bool get enabled;/// What to actually render in. Already collapsed to `USD` on any fallback.
 String get currency;/// What `profiles.preferred_currency` says.
 String get requestedCurrency;/// Units of [currency] per 1 USD. Exactly 1 when [currency] is `USD`.
 double get rate; String get symbol; int get decimalDigits;/// When the quote was taken. Null on any fallback.
 DateTime? get asOf;/// Age assessed by the server, rather than the device's wall clock.
 double? get ageHours; bool get stale;/// Server fallback reason, or client `refresh_required` when no safe
/// remaining lifetime can be established. Null when a real rate is in play.
 String? get fallbackReason; double get maxAgeHours;/// Everything the picker may offer, USD first.
 List<FxCurrencyOption> get available;
/// Create a copy of FxContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FxContextCopyWith<FxContext> get copyWith => _$FxContextCopyWithImpl<FxContext>(this as FxContext, _$identity);

  /// Serializes this FxContext to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FxContext&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.requestedCurrency, requestedCurrency) || other.requestedCurrency == requestedCurrency)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.decimalDigits, decimalDigits) || other.decimalDigits == decimalDigits)&&(identical(other.asOf, asOf) || other.asOf == asOf)&&(identical(other.ageHours, ageHours) || other.ageHours == ageHours)&&(identical(other.stale, stale) || other.stale == stale)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.maxAgeHours, maxAgeHours) || other.maxAgeHours == maxAgeHours)&&const DeepCollectionEquality().equals(other.available, available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,currency,requestedCurrency,rate,symbol,decimalDigits,asOf,ageHours,stale,fallbackReason,maxAgeHours,const DeepCollectionEquality().hash(available));

@override
String toString() {
  return 'FxContext(enabled: $enabled, currency: $currency, requestedCurrency: $requestedCurrency, rate: $rate, symbol: $symbol, decimalDigits: $decimalDigits, asOf: $asOf, ageHours: $ageHours, stale: $stale, fallbackReason: $fallbackReason, maxAgeHours: $maxAgeHours, available: $available)';
}


}

/// @nodoc
abstract mixin class $FxContextCopyWith<$Res>  {
  factory $FxContextCopyWith(FxContext value, $Res Function(FxContext) _then) = _$FxContextCopyWithImpl;
@useResult
$Res call({
 bool enabled, String currency, String requestedCurrency, double rate, String symbol, int decimalDigits, DateTime? asOf, double? ageHours, bool stale, String? fallbackReason, double maxAgeHours, List<FxCurrencyOption> available
});




}
/// @nodoc
class _$FxContextCopyWithImpl<$Res>
    implements $FxContextCopyWith<$Res> {
  _$FxContextCopyWithImpl(this._self, this._then);

  final FxContext _self;
  final $Res Function(FxContext) _then;

/// Create a copy of FxContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? currency = null,Object? requestedCurrency = null,Object? rate = null,Object? symbol = null,Object? decimalDigits = null,Object? asOf = freezed,Object? ageHours = freezed,Object? stale = null,Object? fallbackReason = freezed,Object? maxAgeHours = null,Object? available = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,requestedCurrency: null == requestedCurrency ? _self.requestedCurrency : requestedCurrency // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,decimalDigits: null == decimalDigits ? _self.decimalDigits : decimalDigits // ignore: cast_nullable_to_non_nullable
as int,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime?,ageHours: freezed == ageHours ? _self.ageHours : ageHours // ignore: cast_nullable_to_non_nullable
as double?,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,maxAgeHours: null == maxAgeHours ? _self.maxAgeHours : maxAgeHours // ignore: cast_nullable_to_non_nullable
as double,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as List<FxCurrencyOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [FxContext].
extension FxContextPatterns on FxContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FxContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FxContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FxContext value)  $default,){
final _that = this;
switch (_that) {
case _FxContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FxContext value)?  $default,){
final _that = this;
switch (_that) {
case _FxContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String currency,  String requestedCurrency,  double rate,  String symbol,  int decimalDigits,  DateTime? asOf,  double? ageHours,  bool stale,  String? fallbackReason,  double maxAgeHours,  List<FxCurrencyOption> available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FxContext() when $default != null:
return $default(_that.enabled,_that.currency,_that.requestedCurrency,_that.rate,_that.symbol,_that.decimalDigits,_that.asOf,_that.ageHours,_that.stale,_that.fallbackReason,_that.maxAgeHours,_that.available);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String currency,  String requestedCurrency,  double rate,  String symbol,  int decimalDigits,  DateTime? asOf,  double? ageHours,  bool stale,  String? fallbackReason,  double maxAgeHours,  List<FxCurrencyOption> available)  $default,) {final _that = this;
switch (_that) {
case _FxContext():
return $default(_that.enabled,_that.currency,_that.requestedCurrency,_that.rate,_that.symbol,_that.decimalDigits,_that.asOf,_that.ageHours,_that.stale,_that.fallbackReason,_that.maxAgeHours,_that.available);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String currency,  String requestedCurrency,  double rate,  String symbol,  int decimalDigits,  DateTime? asOf,  double? ageHours,  bool stale,  String? fallbackReason,  double maxAgeHours,  List<FxCurrencyOption> available)?  $default,) {final _that = this;
switch (_that) {
case _FxContext() when $default != null:
return $default(_that.enabled,_that.currency,_that.requestedCurrency,_that.rate,_that.symbol,_that.decimalDigits,_that.asOf,_that.ageHours,_that.stale,_that.fallbackReason,_that.maxAgeHours,_that.available);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _FxContext extends FxContext {
  const _FxContext({this.enabled = true, this.currency = 'USD', this.requestedCurrency = 'USD', this.rate = 1.0, this.symbol = r'$', this.decimalDigits = 2, this.asOf, this.ageHours, this.stale = false, this.fallbackReason, this.maxAgeHours = 72.0, final  List<FxCurrencyOption> available = const <FxCurrencyOption>[]}): _available = available,super._();
  factory _FxContext.fromJson(Map<String, dynamic> json) => _$FxContextFromJson(json);

/// The global brake (`FX_DISPLAY_ENABLED`).
@override@JsonKey() final  bool enabled;
/// What to actually render in. Already collapsed to `USD` on any fallback.
@override@JsonKey() final  String currency;
/// What `profiles.preferred_currency` says.
@override@JsonKey() final  String requestedCurrency;
/// Units of [currency] per 1 USD. Exactly 1 when [currency] is `USD`.
@override@JsonKey() final  double rate;
@override@JsonKey() final  String symbol;
@override@JsonKey() final  int decimalDigits;
/// When the quote was taken. Null on any fallback.
@override final  DateTime? asOf;
/// Age assessed by the server, rather than the device's wall clock.
@override final  double? ageHours;
@override@JsonKey() final  bool stale;
/// Server fallback reason, or client `refresh_required` when no safe
/// remaining lifetime can be established. Null when a real rate is in play.
@override final  String? fallbackReason;
@override@JsonKey() final  double maxAgeHours;
/// Everything the picker may offer, USD first.
 final  List<FxCurrencyOption> _available;
/// Everything the picker may offer, USD first.
@override@JsonKey() List<FxCurrencyOption> get available {
  if (_available is EqualUnmodifiableListView) return _available;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_available);
}


/// Create a copy of FxContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FxContextCopyWith<_FxContext> get copyWith => __$FxContextCopyWithImpl<_FxContext>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FxContextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FxContext&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.requestedCurrency, requestedCurrency) || other.requestedCurrency == requestedCurrency)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.decimalDigits, decimalDigits) || other.decimalDigits == decimalDigits)&&(identical(other.asOf, asOf) || other.asOf == asOf)&&(identical(other.ageHours, ageHours) || other.ageHours == ageHours)&&(identical(other.stale, stale) || other.stale == stale)&&(identical(other.fallbackReason, fallbackReason) || other.fallbackReason == fallbackReason)&&(identical(other.maxAgeHours, maxAgeHours) || other.maxAgeHours == maxAgeHours)&&const DeepCollectionEquality().equals(other._available, _available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,currency,requestedCurrency,rate,symbol,decimalDigits,asOf,ageHours,stale,fallbackReason,maxAgeHours,const DeepCollectionEquality().hash(_available));

@override
String toString() {
  return 'FxContext(enabled: $enabled, currency: $currency, requestedCurrency: $requestedCurrency, rate: $rate, symbol: $symbol, decimalDigits: $decimalDigits, asOf: $asOf, ageHours: $ageHours, stale: $stale, fallbackReason: $fallbackReason, maxAgeHours: $maxAgeHours, available: $available)';
}


}

/// @nodoc
abstract mixin class _$FxContextCopyWith<$Res> implements $FxContextCopyWith<$Res> {
  factory _$FxContextCopyWith(_FxContext value, $Res Function(_FxContext) _then) = __$FxContextCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String currency, String requestedCurrency, double rate, String symbol, int decimalDigits, DateTime? asOf, double? ageHours, bool stale, String? fallbackReason, double maxAgeHours, List<FxCurrencyOption> available
});




}
/// @nodoc
class __$FxContextCopyWithImpl<$Res>
    implements _$FxContextCopyWith<$Res> {
  __$FxContextCopyWithImpl(this._self, this._then);

  final _FxContext _self;
  final $Res Function(_FxContext) _then;

/// Create a copy of FxContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? currency = null,Object? requestedCurrency = null,Object? rate = null,Object? symbol = null,Object? decimalDigits = null,Object? asOf = freezed,Object? ageHours = freezed,Object? stale = null,Object? fallbackReason = freezed,Object? maxAgeHours = null,Object? available = null,}) {
  return _then(_FxContext(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,requestedCurrency: null == requestedCurrency ? _self.requestedCurrency : requestedCurrency // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,decimalDigits: null == decimalDigits ? _self.decimalDigits : decimalDigits // ignore: cast_nullable_to_non_nullable
as int,asOf: freezed == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime?,ageHours: freezed == ageHours ? _self.ageHours : ageHours // ignore: cast_nullable_to_non_nullable
as double?,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,fallbackReason: freezed == fallbackReason ? _self.fallbackReason : fallbackReason // ignore: cast_nullable_to_non_nullable
as String?,maxAgeHours: null == maxAgeHours ? _self.maxAgeHours : maxAgeHours // ignore: cast_nullable_to_non_nullable
as double,available: null == available ? _self._available : available // ignore: cast_nullable_to_non_nullable
as List<FxCurrencyOption>,
  ));
}


}


/// @nodoc
mixin _$FxCurrencyOption {

 String get code; String get name; String get symbol; int get decimalDigits;
/// Create a copy of FxCurrencyOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FxCurrencyOptionCopyWith<FxCurrencyOption> get copyWith => _$FxCurrencyOptionCopyWithImpl<FxCurrencyOption>(this as FxCurrencyOption, _$identity);

  /// Serializes this FxCurrencyOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FxCurrencyOption&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.decimalDigits, decimalDigits) || other.decimalDigits == decimalDigits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,symbol,decimalDigits);

@override
String toString() {
  return 'FxCurrencyOption(code: $code, name: $name, symbol: $symbol, decimalDigits: $decimalDigits)';
}


}

/// @nodoc
abstract mixin class $FxCurrencyOptionCopyWith<$Res>  {
  factory $FxCurrencyOptionCopyWith(FxCurrencyOption value, $Res Function(FxCurrencyOption) _then) = _$FxCurrencyOptionCopyWithImpl;
@useResult
$Res call({
 String code, String name, String symbol, int decimalDigits
});




}
/// @nodoc
class _$FxCurrencyOptionCopyWithImpl<$Res>
    implements $FxCurrencyOptionCopyWith<$Res> {
  _$FxCurrencyOptionCopyWithImpl(this._self, this._then);

  final FxCurrencyOption _self;
  final $Res Function(FxCurrencyOption) _then;

/// Create a copy of FxCurrencyOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? symbol = null,Object? decimalDigits = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,decimalDigits: null == decimalDigits ? _self.decimalDigits : decimalDigits // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FxCurrencyOption].
extension FxCurrencyOptionPatterns on FxCurrencyOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FxCurrencyOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FxCurrencyOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FxCurrencyOption value)  $default,){
final _that = this;
switch (_that) {
case _FxCurrencyOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FxCurrencyOption value)?  $default,){
final _that = this;
switch (_that) {
case _FxCurrencyOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  String symbol,  int decimalDigits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FxCurrencyOption() when $default != null:
return $default(_that.code,_that.name,_that.symbol,_that.decimalDigits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  String symbol,  int decimalDigits)  $default,) {final _that = this;
switch (_that) {
case _FxCurrencyOption():
return $default(_that.code,_that.name,_that.symbol,_that.decimalDigits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  String symbol,  int decimalDigits)?  $default,) {final _that = this;
switch (_that) {
case _FxCurrencyOption() when $default != null:
return $default(_that.code,_that.name,_that.symbol,_that.decimalDigits);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _FxCurrencyOption implements FxCurrencyOption {
  const _FxCurrencyOption({required this.code, required this.name, required this.symbol, this.decimalDigits = 2});
  factory _FxCurrencyOption.fromJson(Map<String, dynamic> json) => _$FxCurrencyOptionFromJson(json);

@override final  String code;
@override final  String name;
@override final  String symbol;
@override@JsonKey() final  int decimalDigits;

/// Create a copy of FxCurrencyOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FxCurrencyOptionCopyWith<_FxCurrencyOption> get copyWith => __$FxCurrencyOptionCopyWithImpl<_FxCurrencyOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FxCurrencyOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FxCurrencyOption&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.symbol, symbol) || other.symbol == symbol)&&(identical(other.decimalDigits, decimalDigits) || other.decimalDigits == decimalDigits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,name,symbol,decimalDigits);

@override
String toString() {
  return 'FxCurrencyOption(code: $code, name: $name, symbol: $symbol, decimalDigits: $decimalDigits)';
}


}

/// @nodoc
abstract mixin class _$FxCurrencyOptionCopyWith<$Res> implements $FxCurrencyOptionCopyWith<$Res> {
  factory _$FxCurrencyOptionCopyWith(_FxCurrencyOption value, $Res Function(_FxCurrencyOption) _then) = __$FxCurrencyOptionCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, String symbol, int decimalDigits
});




}
/// @nodoc
class __$FxCurrencyOptionCopyWithImpl<$Res>
    implements _$FxCurrencyOptionCopyWith<$Res> {
  __$FxCurrencyOptionCopyWithImpl(this._self, this._then);

  final _FxCurrencyOption _self;
  final $Res Function(_FxCurrencyOption) _then;

/// Create a copy of FxCurrencyOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? symbol = null,Object? decimalDigits = null,}) {
  return _then(_FxCurrencyOption(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,symbol: null == symbol ? _self.symbol : symbol // ignore: cast_nullable_to_non_nullable
as String,decimalDigits: null == decimalDigits ? _self.decimalDigits : decimalDigits // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
