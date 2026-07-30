/// SIM Shield — "Roam or eSIM?" quote model (G5)
///
/// One row out of `roam_or_esim_quote(country, days, data_mb, carrier_id)`.
/// Two halves that are independently missing-able, so read [verdict] before
/// reading anything else:
///
///   * `esim_cheaper`    — both sides priced, the eSIM covers the trip, it wins.
///   * `roaming_cheaper` — both sides priced, the eSIM covers the trip, it loses.
///     This is a real outcome, not a bug: Jazz sells 1 GB in the UAE for $3.59.
///     Showing it is the reason a traveller can trust the screen at all.
///   * `esim_partial`    — the catalogue has nothing big enough. The best
///     available bundle is still shown, but no saving is claimed, because
///     comparing a 3 GB eSIM against 10 GB of roaming is not a comparison.
///   * `no_esim`         — no bundle covers this country (17 of the 21 supported
///     countries, on today's catalogue).
///   * `no_roaming_rate` — this user's carriers have no tariff on file.
///   * `no_data`         — neither side. Say so; render nothing else.
///
/// Every roaming figure is an estimate derived from the carrier's own published
/// price ([roamingSourceUrl], priced on [roamingPricedAsOf]) — never confirmed
/// with the carrier. [roamingIsEstimate] is true for every seeded row and the UI
/// must not drop that caveat: this screen's call to action is "buy our eSIM",
/// so an unqualified roaming price would be marketing, not information.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'roam_quote_model.freezed.dart';
part 'roam_quote_model.g.dart';

@freezed
abstract class RoamQuote with _$RoamQuote {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory RoamQuote({
    required String destinationCountryCode,
    required String destinationCountryName,
    required int tripDays,
    required int tripDataMb,

    // ── Roaming side ────────────────────────────────────────────────────────
    String? roamingCarrierId,
    String? roamingCarrierName,
    String? roamingHomeCountry,
    String? roamingProductName,

    /// `day_pass` | `bundle` | `payg`.
    String? roamingProductKind,

    /// `country` (a tariff for this destination) | `worldwide` (a zone pass).
    String? roamingScope,

    /// Packs needed, or days for a day pass, or megabytes for pay-as-you-go.
    int? roamingUnits,
    double? roamingTotalUsd,
    @Default(true) bool roamingIsEstimate,
    String? roamingSourceUrl,
    DateTime? roamingPricedAsOf,

    // ── eSIM side (retail; wholesale never leaves the database) ─────────────
    String? esimOfferId,
    String? esimBundleName,
    int? esimDataMb,
    int? esimDurationDays,
    int? esimQuantity,
    double? esimUnitPriceUsd,
    double? esimTotalUsd,
    @Default(false) bool esimCoversTrip,

    /// Positive when the eSIM is cheaper. Null unless both sides are priced
    /// *and* the eSIM actually covers the trip.
    double? savingsUsd,
    required String verdict,
  }) = _RoamQuote;

  const RoamQuote._();

  factory RoamQuote.fromJson(Map<String, dynamic> json) =>
      _$RoamQuoteFromJson(json);

  bool get hasRoaming => roamingTotalUsd != null;
  bool get hasEsim => esimTotalUsd != null;

  /// True only when a like-for-like comparison exists. `esim_partial` is
  /// deliberately excluded — see the class doc.
  bool get isComparable =>
      verdict == 'esim_cheaper' ||
      verdict == 'roaming_cheaper' ||
      verdict == 'tie';

  /// The saving as a share of the roaming price, for the headline chip.
  double? get savingsPercent {
    final double? saved = savingsUsd;
    final double? roam = roamingTotalUsd;
    if (saved == null || roam == null || roam <= 0 || saved <= 0) return null;
    return saved / roam * 100.0;
  }

  /// `1 GB`, `2.5 GB`, `500 MB`.
  static String formatMb(int? mb) {
    if (mb == null || mb <= 0) return '—';
    if (mb < 1000) return '$mb MB';
    final double gb = mb / 1000.0;
    return gb == gb.roundToDouble()
        ? '${gb.toStringAsFixed(0)} GB'
        : '${gb.toStringAsFixed(1)} GB';
  }

  /// `du · 3 × Roaming Data Daily Bundle (500 MB)`. The multiplier is the part
  /// people miss: one $9.53 day pass is not what a 3-day trip costs.
  String get roamingDetailLine {
    final String name = roamingProductName ?? '';
    final int units = roamingUnits ?? 1;
    if (roamingProductKind == 'payg') {
      return '$name · ${formatMb(tripDataMb)} at pay-as-you-go';
    }
    return units > 1 ? '$units × $name' : name;
  }

  /// `3 × 1 GB / 7 days`.
  String get esimDetailLine {
    final int qty = esimQuantity ?? 1;
    final String size =
        '${formatMb(esimDataMb)} / $esimDurationDays ${esimDurationDays == 1 ? 'day' : 'days'}';
    return qty > 1 ? '$qty × $size' : size;
  }
}

/// One of the caller's own carriers, with whether it can be quoted for a
/// destination. Mirrors `my_roaming_carriers(country)`.
@freezed
abstract class RoamCarrierOption with _$RoamCarrierOption {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory RoamCarrierOption({
    required String carrierId,
    required String carrierName,
    required String homeIso,
    required String homeCountry,
    @Default(false) bool isHome,
    @Default(false) bool hasRate,
    @Default(0) int productCount,
  }) = _RoamCarrierOption;

  const RoamCarrierOption._();

  factory RoamCarrierOption.fromJson(Map<String, dynamic> json) =>
      _$RoamCarrierOptionFromJson(json);
}
