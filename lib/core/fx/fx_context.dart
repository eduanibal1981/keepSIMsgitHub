/// SIM Shield — display-currency context (G11)
///
/// One object out of `get_fx_display_context()`. Read [currency] to know what
/// to render in; it is **already** collapsed to `USD` by the server whenever
/// the feature is off, the rate is too old, or the profile names a currency we
/// do not carry. The client never decides staleness — a device with a skewed
/// clock would otherwise disagree with the server about what is true.
///
/// [requestedCurrency] is what the profile asked for, which differs from
/// [currency] exactly when a fallback happened; [fallbackReason] says which.
/// That pair is what lets the settings screen explain itself instead of
/// silently ignoring the user's choice.
///
/// ⚠️ [rate] is for the eye only. Every charge, cap, wallet balance and ledger
/// row in this product is USD, and there is deliberately no local→USD helper
/// anywhere: converting an *input* back into dollars puts rounding drift inside
/// the money path. Convert one way, at render time, and keep the dollar figure
/// visible wherever the user commits to a charge.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'fx_context.freezed.dart';
part 'fx_context.g.dart';

@freezed
abstract class FxContext with _$FxContext {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FxContext({
    /// The global brake (`FX_DISPLAY_ENABLED`).
    @Default(true) bool enabled,

    /// What to actually render in. Already collapsed to `USD` on any fallback.
    @Default('USD') String currency,

    /// What `profiles.preferred_currency` says.
    @Default('USD') String requestedCurrency,

    /// Units of [currency] per 1 USD. Exactly 1 when [currency] is `USD`.
    @Default(1.0) double rate,
    @Default(r'$') String symbol,
    @Default(2) int decimalDigits,

    /// When the quote was taken. Null on any fallback.
    DateTime? asOf,
    @Default(false) bool stale,

    /// `base` | `disabled` | `stale` | `unknown_currency`, or null when a real
    /// rate is in play.
    String? fallbackReason,
    @Default(72.0) double maxAgeHours,

    /// Everything the picker may offer, USD first.
    @Default(<FxCurrencyOption>[]) List<FxCurrencyOption> available,
  }) = _FxContext;

  const FxContext._();

  factory FxContext.fromJson(Map<String, dynamic> json) =>
      _$FxContextFromJson(json);

  /// True when there is a real conversion to show. Every widget that renders a
  /// secondary local figure gates on this and nothing else.
  bool get convertsMoney => currency != 'USD' && rate > 0;

  /// The user asked for a currency and did not get it — the settings screen
  /// owes them an explanation.
  bool get isFallingBack =>
      requestedCurrency != 'USD' && currency != requestedCurrency;
}

/// One row of the picker. Sourced from the same RPC as the rate, so the list
/// and the formatter can never disagree about which currencies are usable.
@freezed
abstract class FxCurrencyOption with _$FxCurrencyOption {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FxCurrencyOption({
    required String code,
    required String name,
    required String symbol,
    @Default(2) int decimalDigits,
  }) = _FxCurrencyOption;

  factory FxCurrencyOption.fromJson(Map<String, dynamic> json) =>
      _$FxCurrencyOptionFromJson(json);
}
