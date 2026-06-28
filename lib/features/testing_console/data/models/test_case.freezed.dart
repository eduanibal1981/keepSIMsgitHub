// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'test_case.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TestCase {

 String get id;@JsonKey(name: 'feature_group') String get featureGroup;@JsonKey(name: 'test_name') String get testName; String get status;@JsonKey(name: 'ai_task_request') String? get aiTaskRequest;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of TestCase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TestCaseCopyWith<TestCase> get copyWith => _$TestCaseCopyWithImpl<TestCase>(this as TestCase, _$identity);

  /// Serializes this TestCase to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TestCase&&(identical(other.id, id) || other.id == id)&&(identical(other.featureGroup, featureGroup) || other.featureGroup == featureGroup)&&(identical(other.testName, testName) || other.testName == testName)&&(identical(other.status, status) || other.status == status)&&(identical(other.aiTaskRequest, aiTaskRequest) || other.aiTaskRequest == aiTaskRequest)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,featureGroup,testName,status,aiTaskRequest,createdAt,updatedAt);

@override
String toString() {
  return 'TestCase(id: $id, featureGroup: $featureGroup, testName: $testName, status: $status, aiTaskRequest: $aiTaskRequest, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $TestCaseCopyWith<$Res>  {
  factory $TestCaseCopyWith(TestCase value, $Res Function(TestCase) _then) = _$TestCaseCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'feature_group') String featureGroup,@JsonKey(name: 'test_name') String testName, String status,@JsonKey(name: 'ai_task_request') String? aiTaskRequest,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$TestCaseCopyWithImpl<$Res>
    implements $TestCaseCopyWith<$Res> {
  _$TestCaseCopyWithImpl(this._self, this._then);

  final TestCase _self;
  final $Res Function(TestCase) _then;

/// Create a copy of TestCase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? featureGroup = null,Object? testName = null,Object? status = null,Object? aiTaskRequest = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,featureGroup: null == featureGroup ? _self.featureGroup : featureGroup // ignore: cast_nullable_to_non_nullable
as String,testName: null == testName ? _self.testName : testName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,aiTaskRequest: freezed == aiTaskRequest ? _self.aiTaskRequest : aiTaskRequest // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TestCase].
extension TestCasePatterns on TestCase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TestCase value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TestCase() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TestCase value)  $default,){
final _that = this;
switch (_that) {
case _TestCase():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TestCase value)?  $default,){
final _that = this;
switch (_that) {
case _TestCase() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'feature_group')  String featureGroup, @JsonKey(name: 'test_name')  String testName,  String status, @JsonKey(name: 'ai_task_request')  String? aiTaskRequest, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TestCase() when $default != null:
return $default(_that.id,_that.featureGroup,_that.testName,_that.status,_that.aiTaskRequest,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'feature_group')  String featureGroup, @JsonKey(name: 'test_name')  String testName,  String status, @JsonKey(name: 'ai_task_request')  String? aiTaskRequest, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _TestCase():
return $default(_that.id,_that.featureGroup,_that.testName,_that.status,_that.aiTaskRequest,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'feature_group')  String featureGroup, @JsonKey(name: 'test_name')  String testName,  String status, @JsonKey(name: 'ai_task_request')  String? aiTaskRequest, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _TestCase() when $default != null:
return $default(_that.id,_that.featureGroup,_that.testName,_that.status,_that.aiTaskRequest,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TestCase implements TestCase {
  const _TestCase({required this.id, @JsonKey(name: 'feature_group') required this.featureGroup, @JsonKey(name: 'test_name') required this.testName, this.status = 'pending', @JsonKey(name: 'ai_task_request') this.aiTaskRequest, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _TestCase.fromJson(Map<String, dynamic> json) => _$TestCaseFromJson(json);

@override final  String id;
@override@JsonKey(name: 'feature_group') final  String featureGroup;
@override@JsonKey(name: 'test_name') final  String testName;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'ai_task_request') final  String? aiTaskRequest;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of TestCase
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TestCaseCopyWith<_TestCase> get copyWith => __$TestCaseCopyWithImpl<_TestCase>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TestCaseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TestCase&&(identical(other.id, id) || other.id == id)&&(identical(other.featureGroup, featureGroup) || other.featureGroup == featureGroup)&&(identical(other.testName, testName) || other.testName == testName)&&(identical(other.status, status) || other.status == status)&&(identical(other.aiTaskRequest, aiTaskRequest) || other.aiTaskRequest == aiTaskRequest)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,featureGroup,testName,status,aiTaskRequest,createdAt,updatedAt);

@override
String toString() {
  return 'TestCase(id: $id, featureGroup: $featureGroup, testName: $testName, status: $status, aiTaskRequest: $aiTaskRequest, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TestCaseCopyWith<$Res> implements $TestCaseCopyWith<$Res> {
  factory _$TestCaseCopyWith(_TestCase value, $Res Function(_TestCase) _then) = __$TestCaseCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'feature_group') String featureGroup,@JsonKey(name: 'test_name') String testName, String status,@JsonKey(name: 'ai_task_request') String? aiTaskRequest,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$TestCaseCopyWithImpl<$Res>
    implements _$TestCaseCopyWith<$Res> {
  __$TestCaseCopyWithImpl(this._self, this._then);

  final _TestCase _self;
  final $Res Function(_TestCase) _then;

/// Create a copy of TestCase
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? featureGroup = null,Object? testName = null,Object? status = null,Object? aiTaskRequest = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_TestCase(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,featureGroup: null == featureGroup ? _self.featureGroup : featureGroup // ignore: cast_nullable_to_non_nullable
as String,testName: null == testName ? _self.testName : testName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,aiTaskRequest: freezed == aiTaskRequest ? _self.aiTaskRequest : aiTaskRequest // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
