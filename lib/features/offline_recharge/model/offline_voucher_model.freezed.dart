// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offline_voucher_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StoredVoucher {

@JsonKey(name: 'grant_id') String get grantId;@JsonKey(name: 'sim_line_id') String get simLineId; String get pin; String? get serial;@JsonKey(name: 'face_value_usd') double get faceValueUsd;@JsonKey(name: 'amount_due_usd') double get amountDueUsd; String get instructions;/// USSD with a `{PIN}` placeholder, e.g. `*102*{PIN}#`. Null unless an
/// operator has confirmed the code works on this carrier — an unverified
/// string dialled by someone with no signal cannot be taken back.
@JsonKey(name: 'redeem_ussd_template') String? get redeemUssdTemplate;@JsonKey(name: 'expires_at') DateTime? get expiresAt;@JsonKey(name: 'revealed_at') DateTime? get revealedAt; bool get reported;@JsonKey(name: 'stored_at') DateTime? get storedAt;
/// Create a copy of StoredVoucher
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredVoucherCopyWith<StoredVoucher> get copyWith => _$StoredVoucherCopyWithImpl<StoredVoucher>(this as StoredVoucher, _$identity);

  /// Serializes this StoredVoucher to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredVoucher&&(identical(other.grantId, grantId) || other.grantId == grantId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.serial, serial) || other.serial == serial)&&(identical(other.faceValueUsd, faceValueUsd) || other.faceValueUsd == faceValueUsd)&&(identical(other.amountDueUsd, amountDueUsd) || other.amountDueUsd == amountDueUsd)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.redeemUssdTemplate, redeemUssdTemplate) || other.redeemUssdTemplate == redeemUssdTemplate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.revealedAt, revealedAt) || other.revealedAt == revealedAt)&&(identical(other.reported, reported) || other.reported == reported)&&(identical(other.storedAt, storedAt) || other.storedAt == storedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grantId,simLineId,pin,serial,faceValueUsd,amountDueUsd,instructions,redeemUssdTemplate,expiresAt,revealedAt,reported,storedAt);

@override
String toString() {
  return 'StoredVoucher(grantId: $grantId, simLineId: $simLineId, pin: $pin, serial: $serial, faceValueUsd: $faceValueUsd, amountDueUsd: $amountDueUsd, instructions: $instructions, redeemUssdTemplate: $redeemUssdTemplate, expiresAt: $expiresAt, revealedAt: $revealedAt, reported: $reported, storedAt: $storedAt)';
}


}

/// @nodoc
abstract mixin class $StoredVoucherCopyWith<$Res>  {
  factory $StoredVoucherCopyWith(StoredVoucher value, $Res Function(StoredVoucher) _then) = _$StoredVoucherCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'grant_id') String grantId,@JsonKey(name: 'sim_line_id') String simLineId, String pin, String? serial,@JsonKey(name: 'face_value_usd') double faceValueUsd,@JsonKey(name: 'amount_due_usd') double amountDueUsd, String instructions,@JsonKey(name: 'redeem_ussd_template') String? redeemUssdTemplate,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'revealed_at') DateTime? revealedAt, bool reported,@JsonKey(name: 'stored_at') DateTime? storedAt
});




}
/// @nodoc
class _$StoredVoucherCopyWithImpl<$Res>
    implements $StoredVoucherCopyWith<$Res> {
  _$StoredVoucherCopyWithImpl(this._self, this._then);

  final StoredVoucher _self;
  final $Res Function(StoredVoucher) _then;

/// Create a copy of StoredVoucher
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? grantId = null,Object? simLineId = null,Object? pin = null,Object? serial = freezed,Object? faceValueUsd = null,Object? amountDueUsd = null,Object? instructions = null,Object? redeemUssdTemplate = freezed,Object? expiresAt = freezed,Object? revealedAt = freezed,Object? reported = null,Object? storedAt = freezed,}) {
  return _then(_self.copyWith(
grantId: null == grantId ? _self.grantId : grantId // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String,serial: freezed == serial ? _self.serial : serial // ignore: cast_nullable_to_non_nullable
as String?,faceValueUsd: null == faceValueUsd ? _self.faceValueUsd : faceValueUsd // ignore: cast_nullable_to_non_nullable
as double,amountDueUsd: null == amountDueUsd ? _self.amountDueUsd : amountDueUsd // ignore: cast_nullable_to_non_nullable
as double,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,redeemUssdTemplate: freezed == redeemUssdTemplate ? _self.redeemUssdTemplate : redeemUssdTemplate // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revealedAt: freezed == revealedAt ? _self.revealedAt : revealedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reported: null == reported ? _self.reported : reported // ignore: cast_nullable_to_non_nullable
as bool,storedAt: freezed == storedAt ? _self.storedAt : storedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StoredVoucher].
extension StoredVoucherPatterns on StoredVoucher {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoredVoucher value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoredVoucher() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoredVoucher value)  $default,){
final _that = this;
switch (_that) {
case _StoredVoucher():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoredVoucher value)?  $default,){
final _that = this;
switch (_that) {
case _StoredVoucher() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'grant_id')  String grantId, @JsonKey(name: 'sim_line_id')  String simLineId,  String pin,  String? serial, @JsonKey(name: 'face_value_usd')  double faceValueUsd, @JsonKey(name: 'amount_due_usd')  double amountDueUsd,  String instructions, @JsonKey(name: 'redeem_ussd_template')  String? redeemUssdTemplate, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'revealed_at')  DateTime? revealedAt,  bool reported, @JsonKey(name: 'stored_at')  DateTime? storedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoredVoucher() when $default != null:
return $default(_that.grantId,_that.simLineId,_that.pin,_that.serial,_that.faceValueUsd,_that.amountDueUsd,_that.instructions,_that.redeemUssdTemplate,_that.expiresAt,_that.revealedAt,_that.reported,_that.storedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'grant_id')  String grantId, @JsonKey(name: 'sim_line_id')  String simLineId,  String pin,  String? serial, @JsonKey(name: 'face_value_usd')  double faceValueUsd, @JsonKey(name: 'amount_due_usd')  double amountDueUsd,  String instructions, @JsonKey(name: 'redeem_ussd_template')  String? redeemUssdTemplate, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'revealed_at')  DateTime? revealedAt,  bool reported, @JsonKey(name: 'stored_at')  DateTime? storedAt)  $default,) {final _that = this;
switch (_that) {
case _StoredVoucher():
return $default(_that.grantId,_that.simLineId,_that.pin,_that.serial,_that.faceValueUsd,_that.amountDueUsd,_that.instructions,_that.redeemUssdTemplate,_that.expiresAt,_that.revealedAt,_that.reported,_that.storedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'grant_id')  String grantId, @JsonKey(name: 'sim_line_id')  String simLineId,  String pin,  String? serial, @JsonKey(name: 'face_value_usd')  double faceValueUsd, @JsonKey(name: 'amount_due_usd')  double amountDueUsd,  String instructions, @JsonKey(name: 'redeem_ussd_template')  String? redeemUssdTemplate, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'revealed_at')  DateTime? revealedAt,  bool reported, @JsonKey(name: 'stored_at')  DateTime? storedAt)?  $default,) {final _that = this;
switch (_that) {
case _StoredVoucher() when $default != null:
return $default(_that.grantId,_that.simLineId,_that.pin,_that.serial,_that.faceValueUsd,_that.amountDueUsd,_that.instructions,_that.redeemUssdTemplate,_that.expiresAt,_that.revealedAt,_that.reported,_that.storedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _StoredVoucher extends StoredVoucher {
  const _StoredVoucher({@JsonKey(name: 'grant_id') required this.grantId, @JsonKey(name: 'sim_line_id') required this.simLineId, required this.pin, this.serial, @JsonKey(name: 'face_value_usd') required this.faceValueUsd, @JsonKey(name: 'amount_due_usd') required this.amountDueUsd, required this.instructions, @JsonKey(name: 'redeem_ussd_template') this.redeemUssdTemplate, @JsonKey(name: 'expires_at') this.expiresAt, @JsonKey(name: 'revealed_at') this.revealedAt, this.reported = false, @JsonKey(name: 'stored_at') this.storedAt}): super._();
  factory _StoredVoucher.fromJson(Map<String, dynamic> json) => _$StoredVoucherFromJson(json);

@override@JsonKey(name: 'grant_id') final  String grantId;
@override@JsonKey(name: 'sim_line_id') final  String simLineId;
@override final  String pin;
@override final  String? serial;
@override@JsonKey(name: 'face_value_usd') final  double faceValueUsd;
@override@JsonKey(name: 'amount_due_usd') final  double amountDueUsd;
@override final  String instructions;
/// USSD with a `{PIN}` placeholder, e.g. `*102*{PIN}#`. Null unless an
/// operator has confirmed the code works on this carrier — an unverified
/// string dialled by someone with no signal cannot be taken back.
@override@JsonKey(name: 'redeem_ussd_template') final  String? redeemUssdTemplate;
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;
@override@JsonKey(name: 'revealed_at') final  DateTime? revealedAt;
@override@JsonKey() final  bool reported;
@override@JsonKey(name: 'stored_at') final  DateTime? storedAt;

/// Create a copy of StoredVoucher
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoredVoucherCopyWith<_StoredVoucher> get copyWith => __$StoredVoucherCopyWithImpl<_StoredVoucher>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredVoucherToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoredVoucher&&(identical(other.grantId, grantId) || other.grantId == grantId)&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.serial, serial) || other.serial == serial)&&(identical(other.faceValueUsd, faceValueUsd) || other.faceValueUsd == faceValueUsd)&&(identical(other.amountDueUsd, amountDueUsd) || other.amountDueUsd == amountDueUsd)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.redeemUssdTemplate, redeemUssdTemplate) || other.redeemUssdTemplate == redeemUssdTemplate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.revealedAt, revealedAt) || other.revealedAt == revealedAt)&&(identical(other.reported, reported) || other.reported == reported)&&(identical(other.storedAt, storedAt) || other.storedAt == storedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,grantId,simLineId,pin,serial,faceValueUsd,amountDueUsd,instructions,redeemUssdTemplate,expiresAt,revealedAt,reported,storedAt);

@override
String toString() {
  return 'StoredVoucher(grantId: $grantId, simLineId: $simLineId, pin: $pin, serial: $serial, faceValueUsd: $faceValueUsd, amountDueUsd: $amountDueUsd, instructions: $instructions, redeemUssdTemplate: $redeemUssdTemplate, expiresAt: $expiresAt, revealedAt: $revealedAt, reported: $reported, storedAt: $storedAt)';
}


}

/// @nodoc
abstract mixin class _$StoredVoucherCopyWith<$Res> implements $StoredVoucherCopyWith<$Res> {
  factory _$StoredVoucherCopyWith(_StoredVoucher value, $Res Function(_StoredVoucher) _then) = __$StoredVoucherCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'grant_id') String grantId,@JsonKey(name: 'sim_line_id') String simLineId, String pin, String? serial,@JsonKey(name: 'face_value_usd') double faceValueUsd,@JsonKey(name: 'amount_due_usd') double amountDueUsd, String instructions,@JsonKey(name: 'redeem_ussd_template') String? redeemUssdTemplate,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'revealed_at') DateTime? revealedAt, bool reported,@JsonKey(name: 'stored_at') DateTime? storedAt
});




}
/// @nodoc
class __$StoredVoucherCopyWithImpl<$Res>
    implements _$StoredVoucherCopyWith<$Res> {
  __$StoredVoucherCopyWithImpl(this._self, this._then);

  final _StoredVoucher _self;
  final $Res Function(_StoredVoucher) _then;

/// Create a copy of StoredVoucher
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? grantId = null,Object? simLineId = null,Object? pin = null,Object? serial = freezed,Object? faceValueUsd = null,Object? amountDueUsd = null,Object? instructions = null,Object? redeemUssdTemplate = freezed,Object? expiresAt = freezed,Object? revealedAt = freezed,Object? reported = null,Object? storedAt = freezed,}) {
  return _then(_StoredVoucher(
grantId: null == grantId ? _self.grantId : grantId // ignore: cast_nullable_to_non_nullable
as String,simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String,serial: freezed == serial ? _self.serial : serial // ignore: cast_nullable_to_non_nullable
as String?,faceValueUsd: null == faceValueUsd ? _self.faceValueUsd : faceValueUsd // ignore: cast_nullable_to_non_nullable
as double,amountDueUsd: null == amountDueUsd ? _self.amountDueUsd : amountDueUsd // ignore: cast_nullable_to_non_nullable
as double,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,redeemUssdTemplate: freezed == redeemUssdTemplate ? _self.redeemUssdTemplate : redeemUssdTemplate // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revealedAt: freezed == revealedAt ? _self.revealedAt : revealedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reported: null == reported ? _self.reported : reported // ignore: cast_nullable_to_non_nullable
as bool,storedAt: freezed == storedAt ? _self.storedAt : storedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$VoucherGrant {

 String get id; String get status;@JsonKey(name: 'amount_due_usd') double? get amountDueUsd;@JsonKey(name: 'face_value_usd') double? get faceValueUsd;@JsonKey(name: 'revealed_at') DateTime? get revealedAt;@JsonKey(name: 'provisioned_at') DateTime? get provisionedAt;@JsonKey(name: 'expires_at') DateTime? get expiresAt;
/// Create a copy of VoucherGrant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoucherGrantCopyWith<VoucherGrant> get copyWith => _$VoucherGrantCopyWithImpl<VoucherGrant>(this as VoucherGrant, _$identity);

  /// Serializes this VoucherGrant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoucherGrant&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.amountDueUsd, amountDueUsd) || other.amountDueUsd == amountDueUsd)&&(identical(other.faceValueUsd, faceValueUsd) || other.faceValueUsd == faceValueUsd)&&(identical(other.revealedAt, revealedAt) || other.revealedAt == revealedAt)&&(identical(other.provisionedAt, provisionedAt) || other.provisionedAt == provisionedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,amountDueUsd,faceValueUsd,revealedAt,provisionedAt,expiresAt);

@override
String toString() {
  return 'VoucherGrant(id: $id, status: $status, amountDueUsd: $amountDueUsd, faceValueUsd: $faceValueUsd, revealedAt: $revealedAt, provisionedAt: $provisionedAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $VoucherGrantCopyWith<$Res>  {
  factory $VoucherGrantCopyWith(VoucherGrant value, $Res Function(VoucherGrant) _then) = _$VoucherGrantCopyWithImpl;
@useResult
$Res call({
 String id, String status,@JsonKey(name: 'amount_due_usd') double? amountDueUsd,@JsonKey(name: 'face_value_usd') double? faceValueUsd,@JsonKey(name: 'revealed_at') DateTime? revealedAt,@JsonKey(name: 'provisioned_at') DateTime? provisionedAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class _$VoucherGrantCopyWithImpl<$Res>
    implements $VoucherGrantCopyWith<$Res> {
  _$VoucherGrantCopyWithImpl(this._self, this._then);

  final VoucherGrant _self;
  final $Res Function(VoucherGrant) _then;

/// Create a copy of VoucherGrant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? amountDueUsd = freezed,Object? faceValueUsd = freezed,Object? revealedAt = freezed,Object? provisionedAt = freezed,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,amountDueUsd: freezed == amountDueUsd ? _self.amountDueUsd : amountDueUsd // ignore: cast_nullable_to_non_nullable
as double?,faceValueUsd: freezed == faceValueUsd ? _self.faceValueUsd : faceValueUsd // ignore: cast_nullable_to_non_nullable
as double?,revealedAt: freezed == revealedAt ? _self.revealedAt : revealedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,provisionedAt: freezed == provisionedAt ? _self.provisionedAt : provisionedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VoucherGrant].
extension VoucherGrantPatterns on VoucherGrant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoucherGrant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoucherGrant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoucherGrant value)  $default,){
final _that = this;
switch (_that) {
case _VoucherGrant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoucherGrant value)?  $default,){
final _that = this;
switch (_that) {
case _VoucherGrant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'amount_due_usd')  double? amountDueUsd, @JsonKey(name: 'face_value_usd')  double? faceValueUsd, @JsonKey(name: 'revealed_at')  DateTime? revealedAt, @JsonKey(name: 'provisioned_at')  DateTime? provisionedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoucherGrant() when $default != null:
return $default(_that.id,_that.status,_that.amountDueUsd,_that.faceValueUsd,_that.revealedAt,_that.provisionedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'amount_due_usd')  double? amountDueUsd, @JsonKey(name: 'face_value_usd')  double? faceValueUsd, @JsonKey(name: 'revealed_at')  DateTime? revealedAt, @JsonKey(name: 'provisioned_at')  DateTime? provisionedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _VoucherGrant():
return $default(_that.id,_that.status,_that.amountDueUsd,_that.faceValueUsd,_that.revealedAt,_that.provisionedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status, @JsonKey(name: 'amount_due_usd')  double? amountDueUsd, @JsonKey(name: 'face_value_usd')  double? faceValueUsd, @JsonKey(name: 'revealed_at')  DateTime? revealedAt, @JsonKey(name: 'provisioned_at')  DateTime? provisionedAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _VoucherGrant() when $default != null:
return $default(_that.id,_that.status,_that.amountDueUsd,_that.faceValueUsd,_that.revealedAt,_that.provisionedAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VoucherGrant extends VoucherGrant {
  const _VoucherGrant({required this.id, required this.status, @JsonKey(name: 'amount_due_usd') this.amountDueUsd, @JsonKey(name: 'face_value_usd') this.faceValueUsd, @JsonKey(name: 'revealed_at') this.revealedAt, @JsonKey(name: 'provisioned_at') this.provisionedAt, @JsonKey(name: 'expires_at') this.expiresAt}): super._();
  factory _VoucherGrant.fromJson(Map<String, dynamic> json) => _$VoucherGrantFromJson(json);

@override final  String id;
@override final  String status;
@override@JsonKey(name: 'amount_due_usd') final  double? amountDueUsd;
@override@JsonKey(name: 'face_value_usd') final  double? faceValueUsd;
@override@JsonKey(name: 'revealed_at') final  DateTime? revealedAt;
@override@JsonKey(name: 'provisioned_at') final  DateTime? provisionedAt;
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;

/// Create a copy of VoucherGrant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoucherGrantCopyWith<_VoucherGrant> get copyWith => __$VoucherGrantCopyWithImpl<_VoucherGrant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoucherGrantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoucherGrant&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.amountDueUsd, amountDueUsd) || other.amountDueUsd == amountDueUsd)&&(identical(other.faceValueUsd, faceValueUsd) || other.faceValueUsd == faceValueUsd)&&(identical(other.revealedAt, revealedAt) || other.revealedAt == revealedAt)&&(identical(other.provisionedAt, provisionedAt) || other.provisionedAt == provisionedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,amountDueUsd,faceValueUsd,revealedAt,provisionedAt,expiresAt);

@override
String toString() {
  return 'VoucherGrant(id: $id, status: $status, amountDueUsd: $amountDueUsd, faceValueUsd: $faceValueUsd, revealedAt: $revealedAt, provisionedAt: $provisionedAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$VoucherGrantCopyWith<$Res> implements $VoucherGrantCopyWith<$Res> {
  factory _$VoucherGrantCopyWith(_VoucherGrant value, $Res Function(_VoucherGrant) _then) = __$VoucherGrantCopyWithImpl;
@override @useResult
$Res call({
 String id, String status,@JsonKey(name: 'amount_due_usd') double? amountDueUsd,@JsonKey(name: 'face_value_usd') double? faceValueUsd,@JsonKey(name: 'revealed_at') DateTime? revealedAt,@JsonKey(name: 'provisioned_at') DateTime? provisionedAt,@JsonKey(name: 'expires_at') DateTime? expiresAt
});




}
/// @nodoc
class __$VoucherGrantCopyWithImpl<$Res>
    implements _$VoucherGrantCopyWith<$Res> {
  __$VoucherGrantCopyWithImpl(this._self, this._then);

  final _VoucherGrant _self;
  final $Res Function(_VoucherGrant) _then;

/// Create a copy of VoucherGrant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? amountDueUsd = freezed,Object? faceValueUsd = freezed,Object? revealedAt = freezed,Object? provisionedAt = freezed,Object? expiresAt = freezed,}) {
  return _then(_VoucherGrant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,amountDueUsd: freezed == amountDueUsd ? _self.amountDueUsd : amountDueUsd // ignore: cast_nullable_to_non_nullable
as double?,faceValueUsd: freezed == faceValueUsd ? _self.faceValueUsd : faceValueUsd // ignore: cast_nullable_to_non_nullable
as double?,revealedAt: freezed == revealedAt ? _self.revealedAt : revealedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,provisionedAt: freezed == provisionedAt ? _self.provisionedAt : provisionedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$VoucherRequest {

@JsonKey(name: 'due_at') DateTime? get dueAt; String? get reason;
/// Create a copy of VoucherRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoucherRequestCopyWith<VoucherRequest> get copyWith => _$VoucherRequestCopyWithImpl<VoucherRequest>(this as VoucherRequest, _$identity);

  /// Serializes this VoucherRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoucherRequest&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dueAt,reason);

@override
String toString() {
  return 'VoucherRequest(dueAt: $dueAt, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $VoucherRequestCopyWith<$Res>  {
  factory $VoucherRequestCopyWith(VoucherRequest value, $Res Function(VoucherRequest) _then) = _$VoucherRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'due_at') DateTime? dueAt, String? reason
});




}
/// @nodoc
class _$VoucherRequestCopyWithImpl<$Res>
    implements $VoucherRequestCopyWith<$Res> {
  _$VoucherRequestCopyWithImpl(this._self, this._then);

  final VoucherRequest _self;
  final $Res Function(VoucherRequest) _then;

/// Create a copy of VoucherRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dueAt = freezed,Object? reason = freezed,}) {
  return _then(_self.copyWith(
dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VoucherRequest].
extension VoucherRequestPatterns on VoucherRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoucherRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoucherRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoucherRequest value)  $default,){
final _that = this;
switch (_that) {
case _VoucherRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoucherRequest value)?  $default,){
final _that = this;
switch (_that) {
case _VoucherRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'due_at')  DateTime? dueAt,  String? reason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoucherRequest() when $default != null:
return $default(_that.dueAt,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'due_at')  DateTime? dueAt,  String? reason)  $default,) {final _that = this;
switch (_that) {
case _VoucherRequest():
return $default(_that.dueAt,_that.reason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'due_at')  DateTime? dueAt,  String? reason)?  $default,) {final _that = this;
switch (_that) {
case _VoucherRequest() when $default != null:
return $default(_that.dueAt,_that.reason);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VoucherRequest implements VoucherRequest {
  const _VoucherRequest({@JsonKey(name: 'due_at') this.dueAt, this.reason});
  factory _VoucherRequest.fromJson(Map<String, dynamic> json) => _$VoucherRequestFromJson(json);

@override@JsonKey(name: 'due_at') final  DateTime? dueAt;
@override final  String? reason;

/// Create a copy of VoucherRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoucherRequestCopyWith<_VoucherRequest> get copyWith => __$VoucherRequestCopyWithImpl<_VoucherRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoucherRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoucherRequest&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dueAt,reason);

@override
String toString() {
  return 'VoucherRequest(dueAt: $dueAt, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$VoucherRequestCopyWith<$Res> implements $VoucherRequestCopyWith<$Res> {
  factory _$VoucherRequestCopyWith(_VoucherRequest value, $Res Function(_VoucherRequest) _then) = __$VoucherRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'due_at') DateTime? dueAt, String? reason
});




}
/// @nodoc
class __$VoucherRequestCopyWithImpl<$Res>
    implements _$VoucherRequestCopyWith<$Res> {
  __$VoucherRequestCopyWithImpl(this._self, this._then);

  final _VoucherRequest _self;
  final $Res Function(_VoucherRequest) _then;

/// Create a copy of VoucherRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dueAt = freezed,Object? reason = freezed,}) {
  return _then(_VoucherRequest(
dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VoucherLineState {

@JsonKey(name: 'sim_line_id') String get simLineId;@JsonKey(name: 'phone_number') String get phoneNumber; String? get nickname;@JsonKey(name: 'carrier_id') String? get carrierId;@JsonKey(name: 'carrier_name') String? get carrierName; bool get entitled; VoucherGrant? get grant; VoucherRequest? get request;@JsonKey(name: 'stock_available') bool get stockAvailable;
/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoucherLineStateCopyWith<VoucherLineState> get copyWith => _$VoucherLineStateCopyWithImpl<VoucherLineState>(this as VoucherLineState, _$identity);

  /// Serializes this VoucherLineState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoucherLineState&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierName, carrierName) || other.carrierName == carrierName)&&(identical(other.entitled, entitled) || other.entitled == entitled)&&(identical(other.grant, grant) || other.grant == grant)&&(identical(other.request, request) || other.request == request)&&(identical(other.stockAvailable, stockAvailable) || other.stockAvailable == stockAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,phoneNumber,nickname,carrierId,carrierName,entitled,grant,request,stockAvailable);

@override
String toString() {
  return 'VoucherLineState(simLineId: $simLineId, phoneNumber: $phoneNumber, nickname: $nickname, carrierId: $carrierId, carrierName: $carrierName, entitled: $entitled, grant: $grant, request: $request, stockAvailable: $stockAvailable)';
}


}

/// @nodoc
abstract mixin class $VoucherLineStateCopyWith<$Res>  {
  factory $VoucherLineStateCopyWith(VoucherLineState value, $Res Function(VoucherLineState) _then) = _$VoucherLineStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber, String? nickname,@JsonKey(name: 'carrier_id') String? carrierId,@JsonKey(name: 'carrier_name') String? carrierName, bool entitled, VoucherGrant? grant, VoucherRequest? request,@JsonKey(name: 'stock_available') bool stockAvailable
});


$VoucherGrantCopyWith<$Res>? get grant;$VoucherRequestCopyWith<$Res>? get request;

}
/// @nodoc
class _$VoucherLineStateCopyWithImpl<$Res>
    implements $VoucherLineStateCopyWith<$Res> {
  _$VoucherLineStateCopyWithImpl(this._self, this._then);

  final VoucherLineState _self;
  final $Res Function(VoucherLineState) _then;

/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? simLineId = null,Object? phoneNumber = null,Object? nickname = freezed,Object? carrierId = freezed,Object? carrierName = freezed,Object? entitled = null,Object? grant = freezed,Object? request = freezed,Object? stockAvailable = null,}) {
  return _then(_self.copyWith(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,carrierId: freezed == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String?,carrierName: freezed == carrierName ? _self.carrierName : carrierName // ignore: cast_nullable_to_non_nullable
as String?,entitled: null == entitled ? _self.entitled : entitled // ignore: cast_nullable_to_non_nullable
as bool,grant: freezed == grant ? _self.grant : grant // ignore: cast_nullable_to_non_nullable
as VoucherGrant?,request: freezed == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as VoucherRequest?,stockAvailable: null == stockAvailable ? _self.stockAvailable : stockAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoucherGrantCopyWith<$Res>? get grant {
    if (_self.grant == null) {
    return null;
  }

  return $VoucherGrantCopyWith<$Res>(_self.grant!, (value) {
    return _then(_self.copyWith(grant: value));
  });
}/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoucherRequestCopyWith<$Res>? get request {
    if (_self.request == null) {
    return null;
  }

  return $VoucherRequestCopyWith<$Res>(_self.request!, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}


/// Adds pattern-matching-related methods to [VoucherLineState].
extension VoucherLineStatePatterns on VoucherLineState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoucherLineState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoucherLineState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoucherLineState value)  $default,){
final _that = this;
switch (_that) {
case _VoucherLineState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoucherLineState value)?  $default,){
final _that = this;
switch (_that) {
case _VoucherLineState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_name')  String? carrierName,  bool entitled,  VoucherGrant? grant,  VoucherRequest? request, @JsonKey(name: 'stock_available')  bool stockAvailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoucherLineState() when $default != null:
return $default(_that.simLineId,_that.phoneNumber,_that.nickname,_that.carrierId,_that.carrierName,_that.entitled,_that.grant,_that.request,_that.stockAvailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_name')  String? carrierName,  bool entitled,  VoucherGrant? grant,  VoucherRequest? request, @JsonKey(name: 'stock_available')  bool stockAvailable)  $default,) {final _that = this;
switch (_that) {
case _VoucherLineState():
return $default(_that.simLineId,_that.phoneNumber,_that.nickname,_that.carrierId,_that.carrierName,_that.entitled,_that.grant,_that.request,_that.stockAvailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'sim_line_id')  String simLineId, @JsonKey(name: 'phone_number')  String phoneNumber,  String? nickname, @JsonKey(name: 'carrier_id')  String? carrierId, @JsonKey(name: 'carrier_name')  String? carrierName,  bool entitled,  VoucherGrant? grant,  VoucherRequest? request, @JsonKey(name: 'stock_available')  bool stockAvailable)?  $default,) {final _that = this;
switch (_that) {
case _VoucherLineState() when $default != null:
return $default(_that.simLineId,_that.phoneNumber,_that.nickname,_that.carrierId,_that.carrierName,_that.entitled,_that.grant,_that.request,_that.stockAvailable);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _VoucherLineState extends VoucherLineState {
  const _VoucherLineState({@JsonKey(name: 'sim_line_id') required this.simLineId, @JsonKey(name: 'phone_number') required this.phoneNumber, this.nickname, @JsonKey(name: 'carrier_id') this.carrierId, @JsonKey(name: 'carrier_name') this.carrierName, this.entitled = false, this.grant, this.request, @JsonKey(name: 'stock_available') this.stockAvailable = false}): super._();
  factory _VoucherLineState.fromJson(Map<String, dynamic> json) => _$VoucherLineStateFromJson(json);

@override@JsonKey(name: 'sim_line_id') final  String simLineId;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override final  String? nickname;
@override@JsonKey(name: 'carrier_id') final  String? carrierId;
@override@JsonKey(name: 'carrier_name') final  String? carrierName;
@override@JsonKey() final  bool entitled;
@override final  VoucherGrant? grant;
@override final  VoucherRequest? request;
@override@JsonKey(name: 'stock_available') final  bool stockAvailable;

/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoucherLineStateCopyWith<_VoucherLineState> get copyWith => __$VoucherLineStateCopyWithImpl<_VoucherLineState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoucherLineStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoucherLineState&&(identical(other.simLineId, simLineId) || other.simLineId == simLineId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.carrierId, carrierId) || other.carrierId == carrierId)&&(identical(other.carrierName, carrierName) || other.carrierName == carrierName)&&(identical(other.entitled, entitled) || other.entitled == entitled)&&(identical(other.grant, grant) || other.grant == grant)&&(identical(other.request, request) || other.request == request)&&(identical(other.stockAvailable, stockAvailable) || other.stockAvailable == stockAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,simLineId,phoneNumber,nickname,carrierId,carrierName,entitled,grant,request,stockAvailable);

@override
String toString() {
  return 'VoucherLineState(simLineId: $simLineId, phoneNumber: $phoneNumber, nickname: $nickname, carrierId: $carrierId, carrierName: $carrierName, entitled: $entitled, grant: $grant, request: $request, stockAvailable: $stockAvailable)';
}


}

/// @nodoc
abstract mixin class _$VoucherLineStateCopyWith<$Res> implements $VoucherLineStateCopyWith<$Res> {
  factory _$VoucherLineStateCopyWith(_VoucherLineState value, $Res Function(_VoucherLineState) _then) = __$VoucherLineStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'sim_line_id') String simLineId,@JsonKey(name: 'phone_number') String phoneNumber, String? nickname,@JsonKey(name: 'carrier_id') String? carrierId,@JsonKey(name: 'carrier_name') String? carrierName, bool entitled, VoucherGrant? grant, VoucherRequest? request,@JsonKey(name: 'stock_available') bool stockAvailable
});


@override $VoucherGrantCopyWith<$Res>? get grant;@override $VoucherRequestCopyWith<$Res>? get request;

}
/// @nodoc
class __$VoucherLineStateCopyWithImpl<$Res>
    implements _$VoucherLineStateCopyWith<$Res> {
  __$VoucherLineStateCopyWithImpl(this._self, this._then);

  final _VoucherLineState _self;
  final $Res Function(_VoucherLineState) _then;

/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? simLineId = null,Object? phoneNumber = null,Object? nickname = freezed,Object? carrierId = freezed,Object? carrierName = freezed,Object? entitled = null,Object? grant = freezed,Object? request = freezed,Object? stockAvailable = null,}) {
  return _then(_VoucherLineState(
simLineId: null == simLineId ? _self.simLineId : simLineId // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,carrierId: freezed == carrierId ? _self.carrierId : carrierId // ignore: cast_nullable_to_non_nullable
as String?,carrierName: freezed == carrierName ? _self.carrierName : carrierName // ignore: cast_nullable_to_non_nullable
as String?,entitled: null == entitled ? _self.entitled : entitled // ignore: cast_nullable_to_non_nullable
as bool,grant: freezed == grant ? _self.grant : grant // ignore: cast_nullable_to_non_nullable
as VoucherGrant?,request: freezed == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as VoucherRequest?,stockAvailable: null == stockAvailable ? _self.stockAvailable : stockAvailable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoucherGrantCopyWith<$Res>? get grant {
    if (_self.grant == null) {
    return null;
  }

  return $VoucherGrantCopyWith<$Res>(_self.grant!, (value) {
    return _then(_self.copyWith(grant: value));
  });
}/// Create a copy of VoucherLineState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoucherRequestCopyWith<$Res>? get request {
    if (_self.request == null) {
    return null;
  }

  return $VoucherRequestCopyWith<$Res>(_self.request!, (value) {
    return _then(_self.copyWith(request: value));
  });
}
}


/// @nodoc
mixin _$OfflineVoucherState {

 bool get enabled; List<VoucherLineState> get lines;@JsonKey(name: 'outstanding_total_usd') double get outstandingTotalUsd;
/// Create a copy of OfflineVoucherState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfflineVoucherStateCopyWith<OfflineVoucherState> get copyWith => _$OfflineVoucherStateCopyWithImpl<OfflineVoucherState>(this as OfflineVoucherState, _$identity);

  /// Serializes this OfflineVoucherState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OfflineVoucherState&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.outstandingTotalUsd, outstandingTotalUsd) || other.outstandingTotalUsd == outstandingTotalUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,const DeepCollectionEquality().hash(lines),outstandingTotalUsd);

@override
String toString() {
  return 'OfflineVoucherState(enabled: $enabled, lines: $lines, outstandingTotalUsd: $outstandingTotalUsd)';
}


}

/// @nodoc
abstract mixin class $OfflineVoucherStateCopyWith<$Res>  {
  factory $OfflineVoucherStateCopyWith(OfflineVoucherState value, $Res Function(OfflineVoucherState) _then) = _$OfflineVoucherStateCopyWithImpl;
@useResult
$Res call({
 bool enabled, List<VoucherLineState> lines,@JsonKey(name: 'outstanding_total_usd') double outstandingTotalUsd
});




}
/// @nodoc
class _$OfflineVoucherStateCopyWithImpl<$Res>
    implements $OfflineVoucherStateCopyWith<$Res> {
  _$OfflineVoucherStateCopyWithImpl(this._self, this._then);

  final OfflineVoucherState _self;
  final $Res Function(OfflineVoucherState) _then;

/// Create a copy of OfflineVoucherState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? lines = null,Object? outstandingTotalUsd = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<VoucherLineState>,outstandingTotalUsd: null == outstandingTotalUsd ? _self.outstandingTotalUsd : outstandingTotalUsd // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OfflineVoucherState].
extension OfflineVoucherStatePatterns on OfflineVoucherState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OfflineVoucherState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OfflineVoucherState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OfflineVoucherState value)  $default,){
final _that = this;
switch (_that) {
case _OfflineVoucherState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OfflineVoucherState value)?  $default,){
final _that = this;
switch (_that) {
case _OfflineVoucherState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  List<VoucherLineState> lines, @JsonKey(name: 'outstanding_total_usd')  double outstandingTotalUsd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OfflineVoucherState() when $default != null:
return $default(_that.enabled,_that.lines,_that.outstandingTotalUsd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  List<VoucherLineState> lines, @JsonKey(name: 'outstanding_total_usd')  double outstandingTotalUsd)  $default,) {final _that = this;
switch (_that) {
case _OfflineVoucherState():
return $default(_that.enabled,_that.lines,_that.outstandingTotalUsd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  List<VoucherLineState> lines, @JsonKey(name: 'outstanding_total_usd')  double outstandingTotalUsd)?  $default,) {final _that = this;
switch (_that) {
case _OfflineVoucherState() when $default != null:
return $default(_that.enabled,_that.lines,_that.outstandingTotalUsd);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _OfflineVoucherState extends OfflineVoucherState {
  const _OfflineVoucherState({this.enabled = false, final  List<VoucherLineState> lines = const <VoucherLineState>[], @JsonKey(name: 'outstanding_total_usd') this.outstandingTotalUsd = 0.0}): _lines = lines,super._();
  factory _OfflineVoucherState.fromJson(Map<String, dynamic> json) => _$OfflineVoucherStateFromJson(json);

@override@JsonKey() final  bool enabled;
 final  List<VoucherLineState> _lines;
@override@JsonKey() List<VoucherLineState> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override@JsonKey(name: 'outstanding_total_usd') final  double outstandingTotalUsd;

/// Create a copy of OfflineVoucherState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfflineVoucherStateCopyWith<_OfflineVoucherState> get copyWith => __$OfflineVoucherStateCopyWithImpl<_OfflineVoucherState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OfflineVoucherStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OfflineVoucherState&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.outstandingTotalUsd, outstandingTotalUsd) || other.outstandingTotalUsd == outstandingTotalUsd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,const DeepCollectionEquality().hash(_lines),outstandingTotalUsd);

@override
String toString() {
  return 'OfflineVoucherState(enabled: $enabled, lines: $lines, outstandingTotalUsd: $outstandingTotalUsd)';
}


}

/// @nodoc
abstract mixin class _$OfflineVoucherStateCopyWith<$Res> implements $OfflineVoucherStateCopyWith<$Res> {
  factory _$OfflineVoucherStateCopyWith(_OfflineVoucherState value, $Res Function(_OfflineVoucherState) _then) = __$OfflineVoucherStateCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, List<VoucherLineState> lines,@JsonKey(name: 'outstanding_total_usd') double outstandingTotalUsd
});




}
/// @nodoc
class __$OfflineVoucherStateCopyWithImpl<$Res>
    implements _$OfflineVoucherStateCopyWith<$Res> {
  __$OfflineVoucherStateCopyWithImpl(this._self, this._then);

  final _OfflineVoucherState _self;
  final $Res Function(_OfflineVoucherState) _then;

/// Create a copy of OfflineVoucherState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? lines = null,Object? outstandingTotalUsd = null,}) {
  return _then(_OfflineVoucherState(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<VoucherLineState>,outstandingTotalUsd: null == outstandingTotalUsd ? _self.outstandingTotalUsd : outstandingTotalUsd // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
