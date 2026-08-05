/// A single row of the eSIM comparison, from either rail.
///
/// Deliberately NOT a freezed entity: this maps one-for-one onto the
/// `compare_esim_offers()` result set and is never persisted, never patched and
/// never diffed. A generated union/copyWith would be machinery with no caller.
///
/// The two rails it carries are genuinely different products:
///   * [OfferAction.buyInApp]    — our own resale bundle. Wallet debit, we owe
///                                 the eSIM, QR arrives in-app.
///   * [OfferAction.openPartner] — an affiliate deal. We take no money and owe
///                                 no fulfilment; the user finishes on the
///                                 partner's own site and we may earn a
///                                 commission. This MUST be disclosed.
library;

enum OfferAction { buyInApp, openPartner }

enum OfferSpeedTier { fixed, lite, essential, plus, longDuration }

class CompareOffer {
  const CompareOffer({
    required this.offerKind,
    required this.offerId,
    required this.sourceCode,
    required this.sourceName,
    required this.title,
    required this.countries,
    required this.countryCount,
    required this.dataAmountMb,
    required this.isUnlimited,
    required this.durationDays,
    required this.priceUsd,
    required this.action,
    required this.priceIsStale,
    required this.disclosureRequired,
    this.logoUrl,
    this.description,
    this.speedTier,
    this.listPriceUsd,
    this.pricePerGbUsd,
    this.couponCode,
    this.couponDescription,
    this.imageUrl,
  });

  final String offerKind; // 'resale' | 'affiliate'
  final String offerId;
  final String sourceCode;
  final String sourceName;
  final String? logoUrl;
  final String title;
  final String? description;
  final List<String> countries;
  final int countryCount;
  final int dataAmountMb;
  final bool isUnlimited;
  final int durationDays;
  final OfferSpeedTier? speedTier;
  final double priceUsd;

  /// The partner's pre-discount price, for strikethrough. Null when there is
  /// no discount — nothing is struck through rather than inventing a "was".
  final double? listPriceUsd;

  /// NULL for unlimited plans, and that nullability is the point. The server
  /// returns NULL rather than 0.0 so an unlimited bundle can never sort as
  /// "cheapest per GB"; anything reading this must preserve the distinction.
  final double? pricePerGbUsd;

  final String? couponCode;
  final String? couponDescription;
  final String? imageUrl;
  final OfferAction action;

  /// True when a hand-entered partner price is older than the configured
  /// window. The card must then show the offer WITHOUT a number — a
  /// confidently wrong price about someone else's shop is worse than none.
  final bool priceIsStale;

  final bool disclosureRequired;

  bool get isAffiliate => action == OfferAction.openPartner;

  /// Whether a price may be printed as fact. Kept as one named getter so every
  /// surface asks the same question instead of each re-deriving the rule.
  bool get canQuotePrice => !priceIsStale;

  static OfferSpeedTier? _tier(String? raw) {
    switch (raw) {
      case 'fixed':
        return OfferSpeedTier.fixed;
      case 'lite':
        return OfferSpeedTier.lite;
      case 'essential':
        return OfferSpeedTier.essential;
      case 'plus':
        return OfferSpeedTier.plus;
      case 'long_duration':
        return OfferSpeedTier.longDuration;
      default:
        return null;
    }
  }

  factory CompareOffer.fromRpc(Map<String, dynamic> map) {
    return CompareOffer(
      offerKind: map['offer_kind'] as String? ?? 'resale',
      offerId: map['offer_id'] as String? ?? '',
      sourceCode: map['source_code'] as String? ?? '',
      sourceName: map['source_name'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      countries: (map['countries'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          const [],
      countryCount: (map['country_count'] as num?)?.toInt() ?? 0,
      dataAmountMb: (map['data_amount_mb'] as num?)?.toInt() ?? 0,
      isUnlimited: map['is_unlimited'] as bool? ?? false,
      durationDays: (map['duration_days'] as num?)?.toInt() ?? 0,
      speedTier: _tier(map['speed_tier'] as String?),
      priceUsd: (map['price_usd'] as num?)?.toDouble() ?? 0.0,
      listPriceUsd: (map['list_price_usd'] as num?)?.toDouble(),
      pricePerGbUsd: (map['price_per_gb_usd'] as num?)?.toDouble(),
      couponCode: map['coupon_code'] as String?,
      couponDescription: map['coupon_description'] as String?,
      imageUrl: map['image_url'] as String?,
      action: (map['action'] as String?) == 'open_partner'
          ? OfferAction.openPartner
          : OfferAction.buyInApp,
      priceIsStale: map['price_is_stale'] as bool? ?? false,
      disclosureRequired: map['disclosure_required'] as bool? ?? false,
    );
  }

  String get formattedData {
    if (isUnlimited || dataAmountMb <= 0) return 'Unlimited';
    if (dataAmountMb >= 1024) {
      final gb = dataAmountMb / 1024.0;
      return '${gb == gb.roundToDouble() ? gb.toInt() : gb.toStringAsFixed(1)} GB';
    }
    return '$dataAmountMb MB';
  }
}

/// The filter state the compare screen sends to `compare_esim_offers()`.
///
/// Every field maps to a server parameter. Filtering happens in SQL, not in
/// Dart: the catalogue is 5,412 bundles and pulling it down to filter on the
/// device was only ever viable while it was truncated to 50.
class CompareFilters {
  const CompareFilters({
    this.coverage,
    this.minDataMb,
    this.minDays,
    this.maxPriceUsd,
    this.unlimitedOnly = false,
    this.speedTiers,
    this.sort = CompareSort.price,
  });

  final String? coverage; // 'local' | 'regional' | 'global'
  final int? minDataMb;
  final int? minDays;
  final double? maxPriceUsd;
  final bool unlimitedOnly;
  final List<String>? speedTiers;
  final CompareSort sort;

  CompareFilters copyWith({
    Object? coverage = _sentinel,
    Object? minDataMb = _sentinel,
    Object? minDays = _sentinel,
    Object? maxPriceUsd = _sentinel,
    bool? unlimitedOnly,
    Object? speedTiers = _sentinel,
    CompareSort? sort,
  }) {
    return CompareFilters(
      coverage: coverage == _sentinel ? this.coverage : coverage as String?,
      minDataMb: minDataMb == _sentinel ? this.minDataMb : minDataMb as int?,
      minDays: minDays == _sentinel ? this.minDays : minDays as int?,
      maxPriceUsd:
          maxPriceUsd == _sentinel ? this.maxPriceUsd : maxPriceUsd as double?,
      unlimitedOnly: unlimitedOnly ?? this.unlimitedOnly,
      speedTiers:
          speedTiers == _sentinel ? this.speedTiers : speedTiers as List<String>?,
      sort: sort ?? this.sort,
    );
  }

  // A plain `null` default cannot distinguish "leave alone" from "clear it",
  // and every filter here is legitimately clearable.
  static const Object _sentinel = Object();

  int get activeCount => [
        coverage != null,
        minDataMb != null,
        minDays != null,
        maxPriceUsd != null,
        unlimitedOnly,
        speedTiers != null && speedTiers!.isNotEmpty,
      ].where((e) => e).length;

  @override
  bool operator ==(Object other) =>
      other is CompareFilters &&
      other.coverage == coverage &&
      other.minDataMb == minDataMb &&
      other.minDays == minDays &&
      other.maxPriceUsd == maxPriceUsd &&
      other.unlimitedOnly == unlimitedOnly &&
      other.sort == sort &&
      _listEq(other.speedTiers, speedTiers);

  @override
  int get hashCode => Object.hash(coverage, minDataMb, minDays, maxPriceUsd,
      unlimitedOnly, sort, speedTiers?.join(','));

  static bool _listEq(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum CompareSort {
  price('price'),
  pricePerGb('price_per_gb'),
  data('data'),
  duration('duration');

  const CompareSort(this.wire);
  final String wire;
}
