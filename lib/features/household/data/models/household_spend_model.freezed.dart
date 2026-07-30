// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'household_spend_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HouseholdSpendRow {

 String get memberRowId; String? get memberId; String get memberEmail; String? get memberName; String get role; String get inviteStatus; double get monthlyCapUsd; double? get perTxnCapUsd;/// Already debited from the owner's wallet this month.
 double get committedUsd;/// Queued but not yet debited. Counts against the cap on purpose — see the
/// migration header; without it a member could stack refills past the cap.
 double get inFlightUsd; double get spentMtdUsd; double get remainingUsd; DateTime? get lastSpendAt;
/// Create a copy of HouseholdSpendRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HouseholdSpendRowCopyWith<HouseholdSpendRow> get copyWith => _$HouseholdSpendRowCopyWithImpl<HouseholdSpendRow>(this as HouseholdSpendRow, _$identity);

  /// Serializes this HouseholdSpendRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HouseholdSpendRow&&(identical(other.memberRowId, memberRowId) || other.memberRowId == memberRowId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.memberEmail, memberEmail) || other.memberEmail == memberEmail)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteStatus, inviteStatus) || other.inviteStatus == inviteStatus)&&(identical(other.monthlyCapUsd, monthlyCapUsd) || other.monthlyCapUsd == monthlyCapUsd)&&(identical(other.perTxnCapUsd, perTxnCapUsd) || other.perTxnCapUsd == perTxnCapUsd)&&(identical(other.committedUsd, committedUsd) || other.committedUsd == committedUsd)&&(identical(other.inFlightUsd, inFlightUsd) || other.inFlightUsd == inFlightUsd)&&(identical(other.spentMtdUsd, spentMtdUsd) || other.spentMtdUsd == spentMtdUsd)&&(identical(other.remainingUsd, remainingUsd) || other.remainingUsd == remainingUsd)&&(identical(other.lastSpendAt, lastSpendAt) || other.lastSpendAt == lastSpendAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,memberRowId,memberId,memberEmail,memberName,role,inviteStatus,monthlyCapUsd,perTxnCapUsd,committedUsd,inFlightUsd,spentMtdUsd,remainingUsd,lastSpendAt);

@override
String toString() {
  return 'HouseholdSpendRow(memberRowId: $memberRowId, memberId: $memberId, memberEmail: $memberEmail, memberName: $memberName, role: $role, inviteStatus: $inviteStatus, monthlyCapUsd: $monthlyCapUsd, perTxnCapUsd: $perTxnCapUsd, committedUsd: $committedUsd, inFlightUsd: $inFlightUsd, spentMtdUsd: $spentMtdUsd, remainingUsd: $remainingUsd, lastSpendAt: $lastSpendAt)';
}


}

/// @nodoc
abstract mixin class $HouseholdSpendRowCopyWith<$Res>  {
  factory $HouseholdSpendRowCopyWith(HouseholdSpendRow value, $Res Function(HouseholdSpendRow) _then) = _$HouseholdSpendRowCopyWithImpl;
@useResult
$Res call({
 String memberRowId, String? memberId, String memberEmail, String? memberName, String role, String inviteStatus, double monthlyCapUsd, double? perTxnCapUsd, double committedUsd, double inFlightUsd, double spentMtdUsd, double remainingUsd, DateTime? lastSpendAt
});




}
/// @nodoc
class _$HouseholdSpendRowCopyWithImpl<$Res>
    implements $HouseholdSpendRowCopyWith<$Res> {
  _$HouseholdSpendRowCopyWithImpl(this._self, this._then);

  final HouseholdSpendRow _self;
  final $Res Function(HouseholdSpendRow) _then;

/// Create a copy of HouseholdSpendRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? memberRowId = null,Object? memberId = freezed,Object? memberEmail = null,Object? memberName = freezed,Object? role = null,Object? inviteStatus = null,Object? monthlyCapUsd = null,Object? perTxnCapUsd = freezed,Object? committedUsd = null,Object? inFlightUsd = null,Object? spentMtdUsd = null,Object? remainingUsd = null,Object? lastSpendAt = freezed,}) {
  return _then(_self.copyWith(
memberRowId: null == memberRowId ? _self.memberRowId : memberRowId // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,memberEmail: null == memberEmail ? _self.memberEmail : memberEmail // ignore: cast_nullable_to_non_nullable
as String,memberName: freezed == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,inviteStatus: null == inviteStatus ? _self.inviteStatus : inviteStatus // ignore: cast_nullable_to_non_nullable
as String,monthlyCapUsd: null == monthlyCapUsd ? _self.monthlyCapUsd : monthlyCapUsd // ignore: cast_nullable_to_non_nullable
as double,perTxnCapUsd: freezed == perTxnCapUsd ? _self.perTxnCapUsd : perTxnCapUsd // ignore: cast_nullable_to_non_nullable
as double?,committedUsd: null == committedUsd ? _self.committedUsd : committedUsd // ignore: cast_nullable_to_non_nullable
as double,inFlightUsd: null == inFlightUsd ? _self.inFlightUsd : inFlightUsd // ignore: cast_nullable_to_non_nullable
as double,spentMtdUsd: null == spentMtdUsd ? _self.spentMtdUsd : spentMtdUsd // ignore: cast_nullable_to_non_nullable
as double,remainingUsd: null == remainingUsd ? _self.remainingUsd : remainingUsd // ignore: cast_nullable_to_non_nullable
as double,lastSpendAt: freezed == lastSpendAt ? _self.lastSpendAt : lastSpendAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HouseholdSpendRow].
extension HouseholdSpendRowPatterns on HouseholdSpendRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HouseholdSpendRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HouseholdSpendRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HouseholdSpendRow value)  $default,){
final _that = this;
switch (_that) {
case _HouseholdSpendRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HouseholdSpendRow value)?  $default,){
final _that = this;
switch (_that) {
case _HouseholdSpendRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String memberRowId,  String? memberId,  String memberEmail,  String? memberName,  String role,  String inviteStatus,  double monthlyCapUsd,  double? perTxnCapUsd,  double committedUsd,  double inFlightUsd,  double spentMtdUsd,  double remainingUsd,  DateTime? lastSpendAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HouseholdSpendRow() when $default != null:
return $default(_that.memberRowId,_that.memberId,_that.memberEmail,_that.memberName,_that.role,_that.inviteStatus,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.committedUsd,_that.inFlightUsd,_that.spentMtdUsd,_that.remainingUsd,_that.lastSpendAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String memberRowId,  String? memberId,  String memberEmail,  String? memberName,  String role,  String inviteStatus,  double monthlyCapUsd,  double? perTxnCapUsd,  double committedUsd,  double inFlightUsd,  double spentMtdUsd,  double remainingUsd,  DateTime? lastSpendAt)  $default,) {final _that = this;
switch (_that) {
case _HouseholdSpendRow():
return $default(_that.memberRowId,_that.memberId,_that.memberEmail,_that.memberName,_that.role,_that.inviteStatus,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.committedUsd,_that.inFlightUsd,_that.spentMtdUsd,_that.remainingUsd,_that.lastSpendAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String memberRowId,  String? memberId,  String memberEmail,  String? memberName,  String role,  String inviteStatus,  double monthlyCapUsd,  double? perTxnCapUsd,  double committedUsd,  double inFlightUsd,  double spentMtdUsd,  double remainingUsd,  DateTime? lastSpendAt)?  $default,) {final _that = this;
switch (_that) {
case _HouseholdSpendRow() when $default != null:
return $default(_that.memberRowId,_that.memberId,_that.memberEmail,_that.memberName,_that.role,_that.inviteStatus,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.committedUsd,_that.inFlightUsd,_that.spentMtdUsd,_that.remainingUsd,_that.lastSpendAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _HouseholdSpendRow extends HouseholdSpendRow {
  const _HouseholdSpendRow({required this.memberRowId, this.memberId, required this.memberEmail, this.memberName, required this.role, required this.inviteStatus, this.monthlyCapUsd = 0.0, this.perTxnCapUsd, this.committedUsd = 0.0, this.inFlightUsd = 0.0, this.spentMtdUsd = 0.0, this.remainingUsd = 0.0, this.lastSpendAt}): super._();
  factory _HouseholdSpendRow.fromJson(Map<String, dynamic> json) => _$HouseholdSpendRowFromJson(json);

@override final  String memberRowId;
@override final  String? memberId;
@override final  String memberEmail;
@override final  String? memberName;
@override final  String role;
@override final  String inviteStatus;
@override@JsonKey() final  double monthlyCapUsd;
@override final  double? perTxnCapUsd;
/// Already debited from the owner's wallet this month.
@override@JsonKey() final  double committedUsd;
/// Queued but not yet debited. Counts against the cap on purpose — see the
/// migration header; without it a member could stack refills past the cap.
@override@JsonKey() final  double inFlightUsd;
@override@JsonKey() final  double spentMtdUsd;
@override@JsonKey() final  double remainingUsd;
@override final  DateTime? lastSpendAt;

/// Create a copy of HouseholdSpendRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HouseholdSpendRowCopyWith<_HouseholdSpendRow> get copyWith => __$HouseholdSpendRowCopyWithImpl<_HouseholdSpendRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HouseholdSpendRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HouseholdSpendRow&&(identical(other.memberRowId, memberRowId) || other.memberRowId == memberRowId)&&(identical(other.memberId, memberId) || other.memberId == memberId)&&(identical(other.memberEmail, memberEmail) || other.memberEmail == memberEmail)&&(identical(other.memberName, memberName) || other.memberName == memberName)&&(identical(other.role, role) || other.role == role)&&(identical(other.inviteStatus, inviteStatus) || other.inviteStatus == inviteStatus)&&(identical(other.monthlyCapUsd, monthlyCapUsd) || other.monthlyCapUsd == monthlyCapUsd)&&(identical(other.perTxnCapUsd, perTxnCapUsd) || other.perTxnCapUsd == perTxnCapUsd)&&(identical(other.committedUsd, committedUsd) || other.committedUsd == committedUsd)&&(identical(other.inFlightUsd, inFlightUsd) || other.inFlightUsd == inFlightUsd)&&(identical(other.spentMtdUsd, spentMtdUsd) || other.spentMtdUsd == spentMtdUsd)&&(identical(other.remainingUsd, remainingUsd) || other.remainingUsd == remainingUsd)&&(identical(other.lastSpendAt, lastSpendAt) || other.lastSpendAt == lastSpendAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,memberRowId,memberId,memberEmail,memberName,role,inviteStatus,monthlyCapUsd,perTxnCapUsd,committedUsd,inFlightUsd,spentMtdUsd,remainingUsd,lastSpendAt);

@override
String toString() {
  return 'HouseholdSpendRow(memberRowId: $memberRowId, memberId: $memberId, memberEmail: $memberEmail, memberName: $memberName, role: $role, inviteStatus: $inviteStatus, monthlyCapUsd: $monthlyCapUsd, perTxnCapUsd: $perTxnCapUsd, committedUsd: $committedUsd, inFlightUsd: $inFlightUsd, spentMtdUsd: $spentMtdUsd, remainingUsd: $remainingUsd, lastSpendAt: $lastSpendAt)';
}


}

/// @nodoc
abstract mixin class _$HouseholdSpendRowCopyWith<$Res> implements $HouseholdSpendRowCopyWith<$Res> {
  factory _$HouseholdSpendRowCopyWith(_HouseholdSpendRow value, $Res Function(_HouseholdSpendRow) _then) = __$HouseholdSpendRowCopyWithImpl;
@override @useResult
$Res call({
 String memberRowId, String? memberId, String memberEmail, String? memberName, String role, String inviteStatus, double monthlyCapUsd, double? perTxnCapUsd, double committedUsd, double inFlightUsd, double spentMtdUsd, double remainingUsd, DateTime? lastSpendAt
});




}
/// @nodoc
class __$HouseholdSpendRowCopyWithImpl<$Res>
    implements _$HouseholdSpendRowCopyWith<$Res> {
  __$HouseholdSpendRowCopyWithImpl(this._self, this._then);

  final _HouseholdSpendRow _self;
  final $Res Function(_HouseholdSpendRow) _then;

/// Create a copy of HouseholdSpendRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? memberRowId = null,Object? memberId = freezed,Object? memberEmail = null,Object? memberName = freezed,Object? role = null,Object? inviteStatus = null,Object? monthlyCapUsd = null,Object? perTxnCapUsd = freezed,Object? committedUsd = null,Object? inFlightUsd = null,Object? spentMtdUsd = null,Object? remainingUsd = null,Object? lastSpendAt = freezed,}) {
  return _then(_HouseholdSpendRow(
memberRowId: null == memberRowId ? _self.memberRowId : memberRowId // ignore: cast_nullable_to_non_nullable
as String,memberId: freezed == memberId ? _self.memberId : memberId // ignore: cast_nullable_to_non_nullable
as String?,memberEmail: null == memberEmail ? _self.memberEmail : memberEmail // ignore: cast_nullable_to_non_nullable
as String,memberName: freezed == memberName ? _self.memberName : memberName // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,inviteStatus: null == inviteStatus ? _self.inviteStatus : inviteStatus // ignore: cast_nullable_to_non_nullable
as String,monthlyCapUsd: null == monthlyCapUsd ? _self.monthlyCapUsd : monthlyCapUsd // ignore: cast_nullable_to_non_nullable
as double,perTxnCapUsd: freezed == perTxnCapUsd ? _self.perTxnCapUsd : perTxnCapUsd // ignore: cast_nullable_to_non_nullable
as double?,committedUsd: null == committedUsd ? _self.committedUsd : committedUsd // ignore: cast_nullable_to_non_nullable
as double,inFlightUsd: null == inFlightUsd ? _self.inFlightUsd : inFlightUsd // ignore: cast_nullable_to_non_nullable
as double,spentMtdUsd: null == spentMtdUsd ? _self.spentMtdUsd : spentMtdUsd // ignore: cast_nullable_to_non_nullable
as double,remainingUsd: null == remainingUsd ? _self.remainingUsd : remainingUsd // ignore: cast_nullable_to_non_nullable
as double,lastSpendAt: freezed == lastSpendAt ? _self.lastSpendAt : lastSpendAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$HouseholdAllowance {

 String get ownerId; String? get ownerName; String? get ownerEmail; String get role; double get monthlyCapUsd; double? get perTxnCapUsd; double get spentMtdUsd; double get remainingUsd;
/// Create a copy of HouseholdAllowance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HouseholdAllowanceCopyWith<HouseholdAllowance> get copyWith => _$HouseholdAllowanceCopyWithImpl<HouseholdAllowance>(this as HouseholdAllowance, _$identity);

  /// Serializes this HouseholdAllowance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HouseholdAllowance&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.ownerEmail, ownerEmail) || other.ownerEmail == ownerEmail)&&(identical(other.role, role) || other.role == role)&&(identical(other.monthlyCapUsd, monthlyCapUsd) || other.monthlyCapUsd == monthlyCapUsd)&&(identical(other.perTxnCapUsd, perTxnCapUsd) || other.perTxnCapUsd == perTxnCapUsd)&&(identical(other.spentMtdUsd, spentMtdUsd) || other.spentMtdUsd == spentMtdUsd)&&(identical(other.remainingUsd, remainingUsd) || other.remainingUsd == remainingUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerId,ownerName,ownerEmail,role,monthlyCapUsd,perTxnCapUsd,spentMtdUsd,remainingUsd);

@override
String toString() {
  return 'HouseholdAllowance(ownerId: $ownerId, ownerName: $ownerName, ownerEmail: $ownerEmail, role: $role, monthlyCapUsd: $monthlyCapUsd, perTxnCapUsd: $perTxnCapUsd, spentMtdUsd: $spentMtdUsd, remainingUsd: $remainingUsd)';
}


}

/// @nodoc
abstract mixin class $HouseholdAllowanceCopyWith<$Res>  {
  factory $HouseholdAllowanceCopyWith(HouseholdAllowance value, $Res Function(HouseholdAllowance) _then) = _$HouseholdAllowanceCopyWithImpl;
@useResult
$Res call({
 String ownerId, String? ownerName, String? ownerEmail, String role, double monthlyCapUsd, double? perTxnCapUsd, double spentMtdUsd, double remainingUsd
});




}
/// @nodoc
class _$HouseholdAllowanceCopyWithImpl<$Res>
    implements $HouseholdAllowanceCopyWith<$Res> {
  _$HouseholdAllowanceCopyWithImpl(this._self, this._then);

  final HouseholdAllowance _self;
  final $Res Function(HouseholdAllowance) _then;

/// Create a copy of HouseholdAllowance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerId = null,Object? ownerName = freezed,Object? ownerEmail = freezed,Object? role = null,Object? monthlyCapUsd = null,Object? perTxnCapUsd = freezed,Object? spentMtdUsd = null,Object? remainingUsd = null,}) {
  return _then(_self.copyWith(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,ownerEmail: freezed == ownerEmail ? _self.ownerEmail : ownerEmail // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,monthlyCapUsd: null == monthlyCapUsd ? _self.monthlyCapUsd : monthlyCapUsd // ignore: cast_nullable_to_non_nullable
as double,perTxnCapUsd: freezed == perTxnCapUsd ? _self.perTxnCapUsd : perTxnCapUsd // ignore: cast_nullable_to_non_nullable
as double?,spentMtdUsd: null == spentMtdUsd ? _self.spentMtdUsd : spentMtdUsd // ignore: cast_nullable_to_non_nullable
as double,remainingUsd: null == remainingUsd ? _self.remainingUsd : remainingUsd // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [HouseholdAllowance].
extension HouseholdAllowancePatterns on HouseholdAllowance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HouseholdAllowance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HouseholdAllowance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HouseholdAllowance value)  $default,){
final _that = this;
switch (_that) {
case _HouseholdAllowance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HouseholdAllowance value)?  $default,){
final _that = this;
switch (_that) {
case _HouseholdAllowance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerId,  String? ownerName,  String? ownerEmail,  String role,  double monthlyCapUsd,  double? perTxnCapUsd,  double spentMtdUsd,  double remainingUsd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HouseholdAllowance() when $default != null:
return $default(_that.ownerId,_that.ownerName,_that.ownerEmail,_that.role,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.spentMtdUsd,_that.remainingUsd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerId,  String? ownerName,  String? ownerEmail,  String role,  double monthlyCapUsd,  double? perTxnCapUsd,  double spentMtdUsd,  double remainingUsd)  $default,) {final _that = this;
switch (_that) {
case _HouseholdAllowance():
return $default(_that.ownerId,_that.ownerName,_that.ownerEmail,_that.role,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.spentMtdUsd,_that.remainingUsd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerId,  String? ownerName,  String? ownerEmail,  String role,  double monthlyCapUsd,  double? perTxnCapUsd,  double spentMtdUsd,  double remainingUsd)?  $default,) {final _that = this;
switch (_that) {
case _HouseholdAllowance() when $default != null:
return $default(_that.ownerId,_that.ownerName,_that.ownerEmail,_that.role,_that.monthlyCapUsd,_that.perTxnCapUsd,_that.spentMtdUsd,_that.remainingUsd);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _HouseholdAllowance extends HouseholdAllowance {
  const _HouseholdAllowance({required this.ownerId, this.ownerName, this.ownerEmail, required this.role, this.monthlyCapUsd = 0.0, this.perTxnCapUsd, this.spentMtdUsd = 0.0, this.remainingUsd = 0.0}): super._();
  factory _HouseholdAllowance.fromJson(Map<String, dynamic> json) => _$HouseholdAllowanceFromJson(json);

@override final  String ownerId;
@override final  String? ownerName;
@override final  String? ownerEmail;
@override final  String role;
@override@JsonKey() final  double monthlyCapUsd;
@override final  double? perTxnCapUsd;
@override@JsonKey() final  double spentMtdUsd;
@override@JsonKey() final  double remainingUsd;

/// Create a copy of HouseholdAllowance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HouseholdAllowanceCopyWith<_HouseholdAllowance> get copyWith => __$HouseholdAllowanceCopyWithImpl<_HouseholdAllowance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HouseholdAllowanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HouseholdAllowance&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.ownerEmail, ownerEmail) || other.ownerEmail == ownerEmail)&&(identical(other.role, role) || other.role == role)&&(identical(other.monthlyCapUsd, monthlyCapUsd) || other.monthlyCapUsd == monthlyCapUsd)&&(identical(other.perTxnCapUsd, perTxnCapUsd) || other.perTxnCapUsd == perTxnCapUsd)&&(identical(other.spentMtdUsd, spentMtdUsd) || other.spentMtdUsd == spentMtdUsd)&&(identical(other.remainingUsd, remainingUsd) || other.remainingUsd == remainingUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerId,ownerName,ownerEmail,role,monthlyCapUsd,perTxnCapUsd,spentMtdUsd,remainingUsd);

@override
String toString() {
  return 'HouseholdAllowance(ownerId: $ownerId, ownerName: $ownerName, ownerEmail: $ownerEmail, role: $role, monthlyCapUsd: $monthlyCapUsd, perTxnCapUsd: $perTxnCapUsd, spentMtdUsd: $spentMtdUsd, remainingUsd: $remainingUsd)';
}


}

/// @nodoc
abstract mixin class _$HouseholdAllowanceCopyWith<$Res> implements $HouseholdAllowanceCopyWith<$Res> {
  factory _$HouseholdAllowanceCopyWith(_HouseholdAllowance value, $Res Function(_HouseholdAllowance) _then) = __$HouseholdAllowanceCopyWithImpl;
@override @useResult
$Res call({
 String ownerId, String? ownerName, String? ownerEmail, String role, double monthlyCapUsd, double? perTxnCapUsd, double spentMtdUsd, double remainingUsd
});




}
/// @nodoc
class __$HouseholdAllowanceCopyWithImpl<$Res>
    implements _$HouseholdAllowanceCopyWith<$Res> {
  __$HouseholdAllowanceCopyWithImpl(this._self, this._then);

  final _HouseholdAllowance _self;
  final $Res Function(_HouseholdAllowance) _then;

/// Create a copy of HouseholdAllowance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerId = null,Object? ownerName = freezed,Object? ownerEmail = freezed,Object? role = null,Object? monthlyCapUsd = null,Object? perTxnCapUsd = freezed,Object? spentMtdUsd = null,Object? remainingUsd = null,}) {
  return _then(_HouseholdAllowance(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,ownerEmail: freezed == ownerEmail ? _self.ownerEmail : ownerEmail // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,monthlyCapUsd: null == monthlyCapUsd ? _self.monthlyCapUsd : monthlyCapUsd // ignore: cast_nullable_to_non_nullable
as double,perTxnCapUsd: freezed == perTxnCapUsd ? _self.perTxnCapUsd : perTxnCapUsd // ignore: cast_nullable_to_non_nullable
as double?,spentMtdUsd: null == spentMtdUsd ? _self.spentMtdUsd : spentMtdUsd // ignore: cast_nullable_to_non_nullable
as double,remainingUsd: null == remainingUsd ? _self.remainingUsd : remainingUsd // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
