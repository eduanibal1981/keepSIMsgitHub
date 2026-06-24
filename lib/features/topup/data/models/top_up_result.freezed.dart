// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'top_up_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TopUpResult {

 bool get success; String get transactionId; String? get errorMessage; double? get amountToppedUp; String? get localBenefit;
/// Create a copy of TopUpResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopUpResultCopyWith<TopUpResult> get copyWith => _$TopUpResultCopyWithImpl<TopUpResult>(this as TopUpResult, _$identity);

  /// Serializes this TopUpResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopUpResult&&(identical(other.success, success) || other.success == success)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.amountToppedUp, amountToppedUp) || other.amountToppedUp == amountToppedUp)&&(identical(other.localBenefit, localBenefit) || other.localBenefit == localBenefit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,transactionId,errorMessage,amountToppedUp,localBenefit);

@override
String toString() {
  return 'TopUpResult(success: $success, transactionId: $transactionId, errorMessage: $errorMessage, amountToppedUp: $amountToppedUp, localBenefit: $localBenefit)';
}


}

/// @nodoc
abstract mixin class $TopUpResultCopyWith<$Res>  {
  factory $TopUpResultCopyWith(TopUpResult value, $Res Function(TopUpResult) _then) = _$TopUpResultCopyWithImpl;
@useResult
$Res call({
 bool success, String transactionId, String? errorMessage, double? amountToppedUp, String? localBenefit
});




}
/// @nodoc
class _$TopUpResultCopyWithImpl<$Res>
    implements $TopUpResultCopyWith<$Res> {
  _$TopUpResultCopyWithImpl(this._self, this._then);

  final TopUpResult _self;
  final $Res Function(TopUpResult) _then;

/// Create a copy of TopUpResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? transactionId = null,Object? errorMessage = freezed,Object? amountToppedUp = freezed,Object? localBenefit = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,amountToppedUp: freezed == amountToppedUp ? _self.amountToppedUp : amountToppedUp // ignore: cast_nullable_to_non_nullable
as double?,localBenefit: freezed == localBenefit ? _self.localBenefit : localBenefit // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TopUpResult].
extension TopUpResultPatterns on TopUpResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopUpResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopUpResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopUpResult value)  $default,){
final _that = this;
switch (_that) {
case _TopUpResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopUpResult value)?  $default,){
final _that = this;
switch (_that) {
case _TopUpResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  String transactionId,  String? errorMessage,  double? amountToppedUp,  String? localBenefit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopUpResult() when $default != null:
return $default(_that.success,_that.transactionId,_that.errorMessage,_that.amountToppedUp,_that.localBenefit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  String transactionId,  String? errorMessage,  double? amountToppedUp,  String? localBenefit)  $default,) {final _that = this;
switch (_that) {
case _TopUpResult():
return $default(_that.success,_that.transactionId,_that.errorMessage,_that.amountToppedUp,_that.localBenefit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  String transactionId,  String? errorMessage,  double? amountToppedUp,  String? localBenefit)?  $default,) {final _that = this;
switch (_that) {
case _TopUpResult() when $default != null:
return $default(_that.success,_that.transactionId,_that.errorMessage,_that.amountToppedUp,_that.localBenefit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopUpResult implements TopUpResult {
  const _TopUpResult({required this.success, required this.transactionId, this.errorMessage, this.amountToppedUp, this.localBenefit});
  factory _TopUpResult.fromJson(Map<String, dynamic> json) => _$TopUpResultFromJson(json);

@override final  bool success;
@override final  String transactionId;
@override final  String? errorMessage;
@override final  double? amountToppedUp;
@override final  String? localBenefit;

/// Create a copy of TopUpResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopUpResultCopyWith<_TopUpResult> get copyWith => __$TopUpResultCopyWithImpl<_TopUpResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopUpResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopUpResult&&(identical(other.success, success) || other.success == success)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.amountToppedUp, amountToppedUp) || other.amountToppedUp == amountToppedUp)&&(identical(other.localBenefit, localBenefit) || other.localBenefit == localBenefit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,transactionId,errorMessage,amountToppedUp,localBenefit);

@override
String toString() {
  return 'TopUpResult(success: $success, transactionId: $transactionId, errorMessage: $errorMessage, amountToppedUp: $amountToppedUp, localBenefit: $localBenefit)';
}


}

/// @nodoc
abstract mixin class _$TopUpResultCopyWith<$Res> implements $TopUpResultCopyWith<$Res> {
  factory _$TopUpResultCopyWith(_TopUpResult value, $Res Function(_TopUpResult) _then) = __$TopUpResultCopyWithImpl;
@override @useResult
$Res call({
 bool success, String transactionId, String? errorMessage, double? amountToppedUp, String? localBenefit
});




}
/// @nodoc
class __$TopUpResultCopyWithImpl<$Res>
    implements _$TopUpResultCopyWith<$Res> {
  __$TopUpResultCopyWithImpl(this._self, this._then);

  final _TopUpResult _self;
  final $Res Function(_TopUpResult) _then;

/// Create a copy of TopUpResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? transactionId = null,Object? errorMessage = freezed,Object? amountToppedUp = freezed,Object? localBenefit = freezed,}) {
  return _then(_TopUpResult(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,amountToppedUp: freezed == amountToppedUp ? _self.amountToppedUp : amountToppedUp // ignore: cast_nullable_to_non_nullable
as double?,localBenefit: freezed == localBenefit ? _self.localBenefit : localBenefit // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
