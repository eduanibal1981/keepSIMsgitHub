/// SIM Shield — Price Watch Model (G2)
///
/// Maps to `offer_price_watches`. The client owns exactly two columns —
/// [isActive] and [thresholdPercent]. Everything else is written by the nightly
/// `refresh_offer_price_watch()` job and is revoked at the column level, so a
/// write to any of it comes back 42501 rather than silently doing nothing.
///
/// [origin] is what the UI keys its affordances on:
///   * `auto` — derived from a SIM line the user holds. Offer a switch, not a
///     delete: the job recreates any auto row whose line still exists, so a
///     delete button there would appear to do nothing.
///   * `user` — created from this app. Deletable.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'offer_price_watch_model.freezed.dart';
part 'offer_price_watch_model.g.dart';

@freezed
abstract class OfferPriceWatch with _$OfferPriceWatch {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory OfferPriceWatch({
    required String id,
    required String userId,

    /// `topup` (a country + carrier) or `esim` (a country).
    required String source,
    required String countryCode,
    String? carrierCode,
    @Default('user') String origin,
    @Default(true) bool isActive,

    /// null means "use the server default", currently 10%.
    double? thresholdPercent,

    /// The best price we can currently see. For `esim` this is RETAIL $/GB —
    /// wholesale never leaves the database. For `topup` it is the USD price of
    /// the offer that moved most.
    double? lastBestUsd,
    double? lastBaselineUsd,
    double? lastAlertedBestUsd,
    DateTime? lastAlertAt,
    DateTime? lastCheckedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _OfferPriceWatch;

  const OfferPriceWatch._();

  factory OfferPriceWatch.fromJson(Map<String, dynamic> json) =>
      _$OfferPriceWatchFromJson(json);

  bool get isAuto => origin == 'auto';
  bool get isEsim => source == 'esim';

  /// True once the nightly job has actually priced this subject. A watch on a
  /// country/carrier the catalog does not cover yet stays unpriced forever, and
  /// the UI has to say so rather than render an empty price.
  bool get hasPrice => lastBestUsd != null && lastBestUsd! > 0;

  /// How far the current best sits below the baseline, as a percentage.
  /// Negative when the price has gone *up*, which is worth showing too.
  double? get changePercent {
    final double? now = lastBestUsd;
    final double? was = lastBaselineUsd;
    if (now == null || was == null || was <= 0) return null;
    return (was - now) / was * 100.0;
  }

  /// The threshold this watch is actually judged against.
  double effectiveThreshold(double serverDefault) =>
      thresholdPercent ?? serverDefault;

  /// `SA / Zain` or just `DE`.
  String get subjectLabel =>
      carrierCode == null ? countryCode : '$countryCode · $carrierCode';

  /// eSIM prices are per gigabyte; top-up prices are per offer.
  String get unitSuffix => isEsim ? '/GB' : '';
}
