import 'package:freezed_annotation/freezed_annotation.dart';

part 'offline_voucher_model.freezed.dart';
part 'offline_voucher_model.g.dart';

/// A recharge PIN held on this device, ready to be used with no connectivity.
///
/// This is the only object in the app that carries a bearer instrument, and it
/// lives in the platform keystore (Keychain / EncryptedSharedPreferences), NOT
/// in `LocalCacheService` like every other cached model here. SharedPreferences
/// is a plain XML file that any backup, any rooted device and any `adb backup`
/// reads — fine for a cached carrier list, not for something that can be spent.
///
/// [revealedAt] is written the moment the user taps through to see the PIN,
/// **before any network call**, because at that moment there is by definition no
/// network. [reported] flips only once the server has acknowledged the reveal;
/// until then the app keeps retrying, and the debt does not exist server-side.
@freezed
abstract class StoredVoucher with _$StoredVoucher {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory StoredVoucher({
    @JsonKey(name: 'grant_id') required String grantId,
    @JsonKey(name: 'sim_line_id') required String simLineId,
    required String pin,
    String? serial,
    @JsonKey(name: 'face_value_usd') required double faceValueUsd,
    @JsonKey(name: 'amount_due_usd') required double amountDueUsd,
    required String instructions,

    /// USSD with a `{PIN}` placeholder, e.g. `*102*{PIN}#`. Null unless an
    /// operator has confirmed the code works on this carrier — an unverified
    /// string dialled by someone with no signal cannot be taken back.
    @JsonKey(name: 'redeem_ussd_template') String? redeemUssdTemplate,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'revealed_at') DateTime? revealedAt,
    @Default(false) bool reported,
    @JsonKey(name: 'stored_at') DateTime? storedAt,
  }) = _StoredVoucher;

  const StoredVoucher._();

  factory StoredVoucher.fromJson(Map<String, dynamic> json) =>
      _$StoredVoucherFromJson(json);

  bool get isRevealed => revealedAt != null;

  /// True once the reveal has happened but the server has not been told. The
  /// app is carrying a debt it owes a report on.
  bool get needsReport => revealedAt != null && !reported;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// The dialable string, or null when there is no verified template.
  String? get redeemCode {
    final t = redeemUssdTemplate;
    if (t == null || t.isEmpty) return null;
    return t.replaceAll('{PIN}', pin.replaceAll(RegExp(r'[\s-]'), ''));
  }
}

/// The server's view of one voucher. Never carries the PIN — the handset
/// already has that, and putting a bearer instrument in a status poll would
/// spread it across every response cache the app has.
@freezed
abstract class VoucherGrant with _$VoucherGrant {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VoucherGrant({
    required String id,
    required String status,
    @JsonKey(name: 'amount_due_usd') double? amountDueUsd,
    @JsonKey(name: 'face_value_usd') double? faceValueUsd,
    @JsonKey(name: 'revealed_at') DateTime? revealedAt,
    @JsonKey(name: 'provisioned_at') DateTime? provisionedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _VoucherGrant;

  const VoucherGrant._();

  factory VoucherGrant.fromJson(Map<String, dynamic> json) =>
      _$VoucherGrantFromJson(json);

  bool get isOutstanding => status == 'revealed';
  bool get isSealed => status == 'provisioned';
}

/// An open promise to hand-load a PIN for this line, with its deadline.
/// The state RPC returns null for fulfilled/cancelled history or no request.
@freezed
abstract class VoucherRequest with _$VoucherRequest {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VoucherRequest({
    @JsonKey(name: 'due_at') DateTime? dueAt,
    String? reason,
  }) = _VoucherRequest;

  factory VoucherRequest.fromJson(Map<String, dynamic> json) =>
      _$VoucherRequestFromJson(json);
}

@freezed
abstract class VoucherLineState with _$VoucherLineState {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory VoucherLineState({
    @JsonKey(name: 'sim_line_id') required String simLineId,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    String? nickname,
    @JsonKey(name: 'carrier_id') String? carrierId,
    @JsonKey(name: 'carrier_name') String? carrierName,
    @Default(false) bool entitled,
    VoucherGrant? grant,
    VoucherRequest? request,
    @JsonKey(name: 'stock_available') @Default(false) bool stockAvailable,
  }) = _VoucherLineState;

  const VoucherLineState._();

  factory VoucherLineState.fromJson(Map<String, dynamic> json) =>
      _$VoucherLineStateFromJson(json);

  /// A new PIN can be collected: entitled, nothing outstanding, stock exists.
  bool get canProvision => entitled && grant == null && stockAvailable;

  /// Entitled and waiting on us, not on them.
  bool get awaitingStock => entitled && grant == null && !stockAvailable;
}

@freezed
abstract class OfflineVoucherState with _$OfflineVoucherState {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory OfflineVoucherState({
    @Default(false) bool enabled,
    @Default(<VoucherLineState>[]) List<VoucherLineState> lines,
    @JsonKey(name: 'outstanding_total_usd')
    @Default(0.0)
    double outstandingTotalUsd,
  }) = _OfflineVoucherState;

  const OfflineVoucherState._();

  factory OfflineVoucherState.fromJson(Map<String, dynamic> json) =>
      _$OfflineVoucherStateFromJson(json);

  VoucherLineState? forLine(String simLineId) {
    for (final l in lines) {
      if (l.simLineId == simLineId) return l;
    }
    return null;
  }
}

/// Why a provision attempt did not hand over a PIN.
///
/// These are the server's own `code` values. They are distinct states in the
/// UI, not one generic error: "you owe us for the last one" and "we have not
/// stocked your carrier yet" are opposite problems with opposite remedies, and
/// collapsing them into "could not get a PIN" is what makes a subscriber blame
/// the app for something they can fix in one tap.
abstract final class VoucherProvisionCode {
  static const ok = 'OK';
  static const featureOff = 'FEATURE_OFF';
  static const notPremium = 'NOT_PREMIUM';
  static const settlementDue = 'SETTLEMENT_DUE';
  static const noStock = 'NO_STOCK';
  static const noCarrier = 'NO_CARRIER';
  static const lineNotFound = 'LINE_NOT_FOUND';
  static const raceRetry = 'RACE_RETRY';
  static const unauthorized = 'UNAUTHORIZED';
  static const offline = 'OFFLINE';

  /// A transport or server error, as opposed to one of the server's own
  /// refusals above. Kept distinct so the UI never renders a Postgres message
  /// where a product explanation belongs.
  static const error = 'ERROR';
}

/// The outcome of asking for a PIN: either a stored voucher, or a reason.
class VoucherProvisionResult {
  const VoucherProvisionResult({
    required this.code,
    this.voucher,
    this.grantId,
    this.amountDueUsd,
    this.expectedBy,
    this.message,
  });

  final String code;
  final StoredVoucher? voucher;
  final String? grantId;
  final double? amountDueUsd;
  final DateTime? expectedBy;

  /// Diagnostic text for [VoucherProvisionCode.error] only. Never shown as-is.
  final String? message;

  bool get isOk => code == VoucherProvisionCode.ok && voucher != null;
}
