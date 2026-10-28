// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_esim.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserEsim {

 String get id; String get userId; String get esimOrderId; String get iccid; String get lpaActivationCode; String get qrCodeUrl; String get bundleName; String get provider; String get status; int get dataRemainingMb; int get dataTotalMb; DateTime? get purchasedAt; DateTime? get firstActivatedAt; DateTime? get expiresAt; DateTime? get lastSyncedAt; DateTime? get createdAt; DateTime? get updatedAt; bool get issuanceVerified; String get profileState; String get installationState; String get bundleState; String get activationTrigger; int? get dataTotalBytes; int? get dataUsedBytes; int? get dataRemainingBytes; DateTime? get usageObservedAt; DateTime? get lastUsageAttemptAt; DateTime? get activationDeadlineAt; String? get usageErrorCode; Map<String, dynamic>? get catalogueDetails;
/// Create a copy of UserEsim
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserEsimCopyWith<UserEsim> get copyWith => _$UserEsimCopyWithImpl<UserEsim>(this as UserEsim, _$identity);

  /// Serializes this UserEsim to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserEsim&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.esimOrderId, esimOrderId) || other.esimOrderId == esimOrderId)&&(identical(other.iccid, iccid) || other.iccid == iccid)&&(identical(other.lpaActivationCode, lpaActivationCode) || other.lpaActivationCode == lpaActivationCode)&&(identical(other.qrCodeUrl, qrCodeUrl) || other.qrCodeUrl == qrCodeUrl)&&(identical(other.bundleName, bundleName) || other.bundleName == bundleName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.status, status) || other.status == status)&&(identical(other.dataRemainingMb, dataRemainingMb) || other.dataRemainingMb == dataRemainingMb)&&(identical(other.dataTotalMb, dataTotalMb) || other.dataTotalMb == dataTotalMb)&&(identical(other.purchasedAt, purchasedAt) || other.purchasedAt == purchasedAt)&&(identical(other.firstActivatedAt, firstActivatedAt) || other.firstActivatedAt == firstActivatedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.issuanceVerified, issuanceVerified) || other.issuanceVerified == issuanceVerified)&&(identical(other.profileState, profileState) || other.profileState == profileState)&&(identical(other.installationState, installationState) || other.installationState == installationState)&&(identical(other.bundleState, bundleState) || other.bundleState == bundleState)&&(identical(other.activationTrigger, activationTrigger) || other.activationTrigger == activationTrigger)&&(identical(other.dataTotalBytes, dataTotalBytes) || other.dataTotalBytes == dataTotalBytes)&&(identical(other.dataUsedBytes, dataUsedBytes) || other.dataUsedBytes == dataUsedBytes)&&(identical(other.dataRemainingBytes, dataRemainingBytes) || other.dataRemainingBytes == dataRemainingBytes)&&(identical(other.usageObservedAt, usageObservedAt) || other.usageObservedAt == usageObservedAt)&&(identical(other.lastUsageAttemptAt, lastUsageAttemptAt) || other.lastUsageAttemptAt == lastUsageAttemptAt)&&(identical(other.activationDeadlineAt, activationDeadlineAt) || other.activationDeadlineAt == activationDeadlineAt)&&(identical(other.usageErrorCode, usageErrorCode) || other.usageErrorCode == usageErrorCode)&&const DeepCollectionEquality().equals(other.catalogueDetails, catalogueDetails));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,esimOrderId,iccid,lpaActivationCode,qrCodeUrl,bundleName,provider,status,dataRemainingMb,dataTotalMb,purchasedAt,firstActivatedAt,expiresAt,lastSyncedAt,createdAt,updatedAt,issuanceVerified,profileState,installationState,bundleState,activationTrigger,dataTotalBytes,dataUsedBytes,dataRemainingBytes,usageObservedAt,lastUsageAttemptAt,activationDeadlineAt,usageErrorCode,const DeepCollectionEquality().hash(catalogueDetails)]);



}

/// @nodoc
abstract mixin class $UserEsimCopyWith<$Res>  {
  factory $UserEsimCopyWith(UserEsim value, $Res Function(UserEsim) _then) = _$UserEsimCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String esimOrderId, String iccid, String lpaActivationCode, String qrCodeUrl, String bundleName, String provider, String status, int dataRemainingMb, int dataTotalMb, DateTime? purchasedAt, DateTime? firstActivatedAt, DateTime? expiresAt, DateTime? lastSyncedAt, DateTime? createdAt, DateTime? updatedAt, bool issuanceVerified, String profileState, String installationState, String bundleState, String activationTrigger, int? dataTotalBytes, int? dataUsedBytes, int? dataRemainingBytes, DateTime? usageObservedAt, DateTime? lastUsageAttemptAt, DateTime? activationDeadlineAt, String? usageErrorCode, Map<String, dynamic>? catalogueDetails
});




}
/// @nodoc
class _$UserEsimCopyWithImpl<$Res>
    implements $UserEsimCopyWith<$Res> {
  _$UserEsimCopyWithImpl(this._self, this._then);

  final UserEsim _self;
  final $Res Function(UserEsim) _then;

/// Create a copy of UserEsim
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? esimOrderId = null,Object? iccid = null,Object? lpaActivationCode = null,Object? qrCodeUrl = null,Object? bundleName = null,Object? provider = null,Object? status = null,Object? dataRemainingMb = null,Object? dataTotalMb = null,Object? purchasedAt = freezed,Object? firstActivatedAt = freezed,Object? expiresAt = freezed,Object? lastSyncedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? issuanceVerified = null,Object? profileState = null,Object? installationState = null,Object? bundleState = null,Object? activationTrigger = null,Object? dataTotalBytes = freezed,Object? dataUsedBytes = freezed,Object? dataRemainingBytes = freezed,Object? usageObservedAt = freezed,Object? lastUsageAttemptAt = freezed,Object? activationDeadlineAt = freezed,Object? usageErrorCode = freezed,Object? catalogueDetails = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,esimOrderId: null == esimOrderId ? _self.esimOrderId : esimOrderId // ignore: cast_nullable_to_non_nullable
as String,iccid: null == iccid ? _self.iccid : iccid // ignore: cast_nullable_to_non_nullable
as String,lpaActivationCode: null == lpaActivationCode ? _self.lpaActivationCode : lpaActivationCode // ignore: cast_nullable_to_non_nullable
as String,qrCodeUrl: null == qrCodeUrl ? _self.qrCodeUrl : qrCodeUrl // ignore: cast_nullable_to_non_nullable
as String,bundleName: null == bundleName ? _self.bundleName : bundleName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,dataRemainingMb: null == dataRemainingMb ? _self.dataRemainingMb : dataRemainingMb // ignore: cast_nullable_to_non_nullable
as int,dataTotalMb: null == dataTotalMb ? _self.dataTotalMb : dataTotalMb // ignore: cast_nullable_to_non_nullable
as int,purchasedAt: freezed == purchasedAt ? _self.purchasedAt : purchasedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,firstActivatedAt: freezed == firstActivatedAt ? _self.firstActivatedAt : firstActivatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,issuanceVerified: null == issuanceVerified ? _self.issuanceVerified : issuanceVerified // ignore: cast_nullable_to_non_nullable
as bool,profileState: null == profileState ? _self.profileState : profileState // ignore: cast_nullable_to_non_nullable
as String,installationState: null == installationState ? _self.installationState : installationState // ignore: cast_nullable_to_non_nullable
as String,bundleState: null == bundleState ? _self.bundleState : bundleState // ignore: cast_nullable_to_non_nullable
as String,activationTrigger: null == activationTrigger ? _self.activationTrigger : activationTrigger // ignore: cast_nullable_to_non_nullable
as String,dataTotalBytes: freezed == dataTotalBytes ? _self.dataTotalBytes : dataTotalBytes // ignore: cast_nullable_to_non_nullable
as int?,dataUsedBytes: freezed == dataUsedBytes ? _self.dataUsedBytes : dataUsedBytes // ignore: cast_nullable_to_non_nullable
as int?,dataRemainingBytes: freezed == dataRemainingBytes ? _self.dataRemainingBytes : dataRemainingBytes // ignore: cast_nullable_to_non_nullable
as int?,usageObservedAt: freezed == usageObservedAt ? _self.usageObservedAt : usageObservedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsageAttemptAt: freezed == lastUsageAttemptAt ? _self.lastUsageAttemptAt : lastUsageAttemptAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activationDeadlineAt: freezed == activationDeadlineAt ? _self.activationDeadlineAt : activationDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,usageErrorCode: freezed == usageErrorCode ? _self.usageErrorCode : usageErrorCode // ignore: cast_nullable_to_non_nullable
as String?,catalogueDetails: freezed == catalogueDetails ? _self.catalogueDetails : catalogueDetails // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserEsim].
extension UserEsimPatterns on UserEsim {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserEsim value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserEsim() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserEsim value)  $default,){
final _that = this;
switch (_that) {
case _UserEsim():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserEsim value)?  $default,){
final _that = this;
switch (_that) {
case _UserEsim() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String esimOrderId,  String iccid,  String lpaActivationCode,  String qrCodeUrl,  String bundleName,  String provider,  String status,  int dataRemainingMb,  int dataTotalMb,  DateTime? purchasedAt,  DateTime? firstActivatedAt,  DateTime? expiresAt,  DateTime? lastSyncedAt,  DateTime? createdAt,  DateTime? updatedAt,  bool issuanceVerified,  String profileState,  String installationState,  String bundleState,  String activationTrigger,  int? dataTotalBytes,  int? dataUsedBytes,  int? dataRemainingBytes,  DateTime? usageObservedAt,  DateTime? lastUsageAttemptAt,  DateTime? activationDeadlineAt,  String? usageErrorCode,  Map<String, dynamic>? catalogueDetails)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserEsim() when $default != null:
return $default(_that.id,_that.userId,_that.esimOrderId,_that.iccid,_that.lpaActivationCode,_that.qrCodeUrl,_that.bundleName,_that.provider,_that.status,_that.dataRemainingMb,_that.dataTotalMb,_that.purchasedAt,_that.firstActivatedAt,_that.expiresAt,_that.lastSyncedAt,_that.createdAt,_that.updatedAt,_that.issuanceVerified,_that.profileState,_that.installationState,_that.bundleState,_that.activationTrigger,_that.dataTotalBytes,_that.dataUsedBytes,_that.dataRemainingBytes,_that.usageObservedAt,_that.lastUsageAttemptAt,_that.activationDeadlineAt,_that.usageErrorCode,_that.catalogueDetails);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String esimOrderId,  String iccid,  String lpaActivationCode,  String qrCodeUrl,  String bundleName,  String provider,  String status,  int dataRemainingMb,  int dataTotalMb,  DateTime? purchasedAt,  DateTime? firstActivatedAt,  DateTime? expiresAt,  DateTime? lastSyncedAt,  DateTime? createdAt,  DateTime? updatedAt,  bool issuanceVerified,  String profileState,  String installationState,  String bundleState,  String activationTrigger,  int? dataTotalBytes,  int? dataUsedBytes,  int? dataRemainingBytes,  DateTime? usageObservedAt,  DateTime? lastUsageAttemptAt,  DateTime? activationDeadlineAt,  String? usageErrorCode,  Map<String, dynamic>? catalogueDetails)  $default,) {final _that = this;
switch (_that) {
case _UserEsim():
return $default(_that.id,_that.userId,_that.esimOrderId,_that.iccid,_that.lpaActivationCode,_that.qrCodeUrl,_that.bundleName,_that.provider,_that.status,_that.dataRemainingMb,_that.dataTotalMb,_that.purchasedAt,_that.firstActivatedAt,_that.expiresAt,_that.lastSyncedAt,_that.createdAt,_that.updatedAt,_that.issuanceVerified,_that.profileState,_that.installationState,_that.bundleState,_that.activationTrigger,_that.dataTotalBytes,_that.dataUsedBytes,_that.dataRemainingBytes,_that.usageObservedAt,_that.lastUsageAttemptAt,_that.activationDeadlineAt,_that.usageErrorCode,_that.catalogueDetails);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String esimOrderId,  String iccid,  String lpaActivationCode,  String qrCodeUrl,  String bundleName,  String provider,  String status,  int dataRemainingMb,  int dataTotalMb,  DateTime? purchasedAt,  DateTime? firstActivatedAt,  DateTime? expiresAt,  DateTime? lastSyncedAt,  DateTime? createdAt,  DateTime? updatedAt,  bool issuanceVerified,  String profileState,  String installationState,  String bundleState,  String activationTrigger,  int? dataTotalBytes,  int? dataUsedBytes,  int? dataRemainingBytes,  DateTime? usageObservedAt,  DateTime? lastUsageAttemptAt,  DateTime? activationDeadlineAt,  String? usageErrorCode,  Map<String, dynamic>? catalogueDetails)?  $default,) {final _that = this;
switch (_that) {
case _UserEsim() when $default != null:
return $default(_that.id,_that.userId,_that.esimOrderId,_that.iccid,_that.lpaActivationCode,_that.qrCodeUrl,_that.bundleName,_that.provider,_that.status,_that.dataRemainingMb,_that.dataTotalMb,_that.purchasedAt,_that.firstActivatedAt,_that.expiresAt,_that.lastSyncedAt,_that.createdAt,_that.updatedAt,_that.issuanceVerified,_that.profileState,_that.installationState,_that.bundleState,_that.activationTrigger,_that.dataTotalBytes,_that.dataUsedBytes,_that.dataRemainingBytes,_that.usageObservedAt,_that.lastUsageAttemptAt,_that.activationDeadlineAt,_that.usageErrorCode,_that.catalogueDetails);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserEsim extends UserEsim {
  const _UserEsim({required this.id, required this.userId, required this.esimOrderId, required this.iccid, required this.lpaActivationCode, required this.qrCodeUrl, required this.bundleName, required this.provider, required this.status, required this.dataRemainingMb, required this.dataTotalMb, this.purchasedAt, this.firstActivatedAt, this.expiresAt, this.lastSyncedAt, this.createdAt, this.updatedAt, this.issuanceVerified = false, this.profileState = 'unknown', this.installationState = 'unknown', this.bundleState = 'unknown', this.activationTrigger = 'unknown', this.dataTotalBytes, this.dataUsedBytes, this.dataRemainingBytes, this.usageObservedAt, this.lastUsageAttemptAt, this.activationDeadlineAt, this.usageErrorCode, final  Map<String, dynamic>? catalogueDetails}): _catalogueDetails = catalogueDetails,super._();
  factory _UserEsim.fromJson(Map<String, dynamic> json) => _$UserEsimFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String esimOrderId;
@override final  String iccid;
@override final  String lpaActivationCode;
@override final  String qrCodeUrl;
@override final  String bundleName;
@override final  String provider;
@override final  String status;
@override final  int dataRemainingMb;
@override final  int dataTotalMb;
@override final  DateTime? purchasedAt;
@override final  DateTime? firstActivatedAt;
@override final  DateTime? expiresAt;
@override final  DateTime? lastSyncedAt;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
@override@JsonKey() final  bool issuanceVerified;
@override@JsonKey() final  String profileState;
@override@JsonKey() final  String installationState;
@override@JsonKey() final  String bundleState;
@override@JsonKey() final  String activationTrigger;
@override final  int? dataTotalBytes;
@override final  int? dataUsedBytes;
@override final  int? dataRemainingBytes;
@override final  DateTime? usageObservedAt;
@override final  DateTime? lastUsageAttemptAt;
@override final  DateTime? activationDeadlineAt;
@override final  String? usageErrorCode;
 final  Map<String, dynamic>? _catalogueDetails;
@override Map<String, dynamic>? get catalogueDetails {
  final value = _catalogueDetails;
  if (value == null) return null;
  if (_catalogueDetails is EqualUnmodifiableMapView) return _catalogueDetails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of UserEsim
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserEsimCopyWith<_UserEsim> get copyWith => __$UserEsimCopyWithImpl<_UserEsim>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserEsimToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserEsim&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.esimOrderId, esimOrderId) || other.esimOrderId == esimOrderId)&&(identical(other.iccid, iccid) || other.iccid == iccid)&&(identical(other.lpaActivationCode, lpaActivationCode) || other.lpaActivationCode == lpaActivationCode)&&(identical(other.qrCodeUrl, qrCodeUrl) || other.qrCodeUrl == qrCodeUrl)&&(identical(other.bundleName, bundleName) || other.bundleName == bundleName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.status, status) || other.status == status)&&(identical(other.dataRemainingMb, dataRemainingMb) || other.dataRemainingMb == dataRemainingMb)&&(identical(other.dataTotalMb, dataTotalMb) || other.dataTotalMb == dataTotalMb)&&(identical(other.purchasedAt, purchasedAt) || other.purchasedAt == purchasedAt)&&(identical(other.firstActivatedAt, firstActivatedAt) || other.firstActivatedAt == firstActivatedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.issuanceVerified, issuanceVerified) || other.issuanceVerified == issuanceVerified)&&(identical(other.profileState, profileState) || other.profileState == profileState)&&(identical(other.installationState, installationState) || other.installationState == installationState)&&(identical(other.bundleState, bundleState) || other.bundleState == bundleState)&&(identical(other.activationTrigger, activationTrigger) || other.activationTrigger == activationTrigger)&&(identical(other.dataTotalBytes, dataTotalBytes) || other.dataTotalBytes == dataTotalBytes)&&(identical(other.dataUsedBytes, dataUsedBytes) || other.dataUsedBytes == dataUsedBytes)&&(identical(other.dataRemainingBytes, dataRemainingBytes) || other.dataRemainingBytes == dataRemainingBytes)&&(identical(other.usageObservedAt, usageObservedAt) || other.usageObservedAt == usageObservedAt)&&(identical(other.lastUsageAttemptAt, lastUsageAttemptAt) || other.lastUsageAttemptAt == lastUsageAttemptAt)&&(identical(other.activationDeadlineAt, activationDeadlineAt) || other.activationDeadlineAt == activationDeadlineAt)&&(identical(other.usageErrorCode, usageErrorCode) || other.usageErrorCode == usageErrorCode)&&const DeepCollectionEquality().equals(other._catalogueDetails, _catalogueDetails));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,esimOrderId,iccid,lpaActivationCode,qrCodeUrl,bundleName,provider,status,dataRemainingMb,dataTotalMb,purchasedAt,firstActivatedAt,expiresAt,lastSyncedAt,createdAt,updatedAt,issuanceVerified,profileState,installationState,bundleState,activationTrigger,dataTotalBytes,dataUsedBytes,dataRemainingBytes,usageObservedAt,lastUsageAttemptAt,activationDeadlineAt,usageErrorCode,const DeepCollectionEquality().hash(_catalogueDetails)]);



}

/// @nodoc
abstract mixin class _$UserEsimCopyWith<$Res> implements $UserEsimCopyWith<$Res> {
  factory _$UserEsimCopyWith(_UserEsim value, $Res Function(_UserEsim) _then) = __$UserEsimCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String esimOrderId, String iccid, String lpaActivationCode, String qrCodeUrl, String bundleName, String provider, String status, int dataRemainingMb, int dataTotalMb, DateTime? purchasedAt, DateTime? firstActivatedAt, DateTime? expiresAt, DateTime? lastSyncedAt, DateTime? createdAt, DateTime? updatedAt, bool issuanceVerified, String profileState, String installationState, String bundleState, String activationTrigger, int? dataTotalBytes, int? dataUsedBytes, int? dataRemainingBytes, DateTime? usageObservedAt, DateTime? lastUsageAttemptAt, DateTime? activationDeadlineAt, String? usageErrorCode, Map<String, dynamic>? catalogueDetails
});




}
/// @nodoc
class __$UserEsimCopyWithImpl<$Res>
    implements _$UserEsimCopyWith<$Res> {
  __$UserEsimCopyWithImpl(this._self, this._then);

  final _UserEsim _self;
  final $Res Function(_UserEsim) _then;

/// Create a copy of UserEsim
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? esimOrderId = null,Object? iccid = null,Object? lpaActivationCode = null,Object? qrCodeUrl = null,Object? bundleName = null,Object? provider = null,Object? status = null,Object? dataRemainingMb = null,Object? dataTotalMb = null,Object? purchasedAt = freezed,Object? firstActivatedAt = freezed,Object? expiresAt = freezed,Object? lastSyncedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? issuanceVerified = null,Object? profileState = null,Object? installationState = null,Object? bundleState = null,Object? activationTrigger = null,Object? dataTotalBytes = freezed,Object? dataUsedBytes = freezed,Object? dataRemainingBytes = freezed,Object? usageObservedAt = freezed,Object? lastUsageAttemptAt = freezed,Object? activationDeadlineAt = freezed,Object? usageErrorCode = freezed,Object? catalogueDetails = freezed,}) {
  return _then(_UserEsim(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,esimOrderId: null == esimOrderId ? _self.esimOrderId : esimOrderId // ignore: cast_nullable_to_non_nullable
as String,iccid: null == iccid ? _self.iccid : iccid // ignore: cast_nullable_to_non_nullable
as String,lpaActivationCode: null == lpaActivationCode ? _self.lpaActivationCode : lpaActivationCode // ignore: cast_nullable_to_non_nullable
as String,qrCodeUrl: null == qrCodeUrl ? _self.qrCodeUrl : qrCodeUrl // ignore: cast_nullable_to_non_nullable
as String,bundleName: null == bundleName ? _self.bundleName : bundleName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,dataRemainingMb: null == dataRemainingMb ? _self.dataRemainingMb : dataRemainingMb // ignore: cast_nullable_to_non_nullable
as int,dataTotalMb: null == dataTotalMb ? _self.dataTotalMb : dataTotalMb // ignore: cast_nullable_to_non_nullable
as int,purchasedAt: freezed == purchasedAt ? _self.purchasedAt : purchasedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,firstActivatedAt: freezed == firstActivatedAt ? _self.firstActivatedAt : firstActivatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,issuanceVerified: null == issuanceVerified ? _self.issuanceVerified : issuanceVerified // ignore: cast_nullable_to_non_nullable
as bool,profileState: null == profileState ? _self.profileState : profileState // ignore: cast_nullable_to_non_nullable
as String,installationState: null == installationState ? _self.installationState : installationState // ignore: cast_nullable_to_non_nullable
as String,bundleState: null == bundleState ? _self.bundleState : bundleState // ignore: cast_nullable_to_non_nullable
as String,activationTrigger: null == activationTrigger ? _self.activationTrigger : activationTrigger // ignore: cast_nullable_to_non_nullable
as String,dataTotalBytes: freezed == dataTotalBytes ? _self.dataTotalBytes : dataTotalBytes // ignore: cast_nullable_to_non_nullable
as int?,dataUsedBytes: freezed == dataUsedBytes ? _self.dataUsedBytes : dataUsedBytes // ignore: cast_nullable_to_non_nullable
as int?,dataRemainingBytes: freezed == dataRemainingBytes ? _self.dataRemainingBytes : dataRemainingBytes // ignore: cast_nullable_to_non_nullable
as int?,usageObservedAt: freezed == usageObservedAt ? _self.usageObservedAt : usageObservedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastUsageAttemptAt: freezed == lastUsageAttemptAt ? _self.lastUsageAttemptAt : lastUsageAttemptAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activationDeadlineAt: freezed == activationDeadlineAt ? _self.activationDeadlineAt : activationDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,usageErrorCode: freezed == usageErrorCode ? _self.usageErrorCode : usageErrorCode // ignore: cast_nullable_to_non_nullable
as String?,catalogueDetails: freezed == catalogueDetails ? _self._catalogueDetails : catalogueDetails // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
