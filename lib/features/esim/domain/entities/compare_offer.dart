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
    this.bundleGroup,
    this.speedTier,
    this.speedTierRaw,
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
  final String? bundleGroup;
  final List<String> countries;
  final int countryCount;
  final int dataAmountMb;
  final bool isUnlimited;
  final int durationDays;
  final OfferSpeedTier? speedTier;
  final String? speedTierRaw;
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

  /// Returns the user-facing product type tag (e.g. 'Fixed Bundle' or 'DayPass').
  String? get typeTag {
    if (bundleGroup != null && (bundleGroup == 'DayPass' || bundleGroup == 'Fixed Bundle')) {
      return bundleGroup;
    }
    if (sourceCode == 'esimaccess') {
      final isDaily = RegExp(r'daily|/day|fup|daypass', caseSensitive: false)
          .hasMatch('$title ${description ?? ''}');
      return isDaily ? 'DayPass' : 'Fixed Bundle';
    }
    return null;
  }

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
      bundleGroup: map['bundle_group'] as String?,
      countries: (map['countries'] as List<dynamic>?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          const [],
      countryCount: (map['country_count'] as num?)?.toInt() ?? 0,
      dataAmountMb: (map['data_amount_mb'] as num?)?.toInt() ?? 0,
      isUnlimited: map['is_unlimited'] as bool? ?? false,
      durationDays: (map['duration_days'] as num?)?.toInt() ?? 0,
      speedTier: _tier(map['speed_tier'] as String?),
      speedTierRaw: map['speed_tier'] as String?,
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
    if (typeTag == 'DayPass') {
      if (dataAmountMb > 0) {
        return '${formatDataMb(dataAmountMb)}/day';
      }
      return 'Unlimited';
    }
    return isUnlimited || dataAmountMb <= 0 ? 'Unlimited' : formatDataMb(dataAmountMb);
  }

  /// Returns a direct, human-readable explanation of the plan's exact speed & throttle policy.
  String? get exactSpeedDetail {
    if (!isUnlimited && typeTag != 'DayPass') {
      return null;
    }

    // 1. Check description for explicit daily throttle policy (e.g. Zendit / DayPass notes)
    if (description != null && description!.isNotEmpty) {
      final desc = description!;
      if (desc.contains('unthrottled') && desc.contains('throttled')) {
        return desc;
      }
    }

    // 2. DayPass or high-* speed tier (e.g. "high-1 Mbps", "high-512 kbps", "high-384 kbps")
    if (speedTierRaw != null && speedTierRaw!.startsWith('high-')) {
      final rate = speedTierRaw!.substring(5).trim();
      if (dataAmountMb > 0) {
        return '${formatDataMb(dataAmountMb)}/day at Max speed then throttle to $rate';
      }
      return 'Max speed then throttle to $rate';
    }

    // 3. Known standard tiers (eSIM Go / Zendit)
    switch (speedTier) {
      case OfferSpeedTier.lite:
        return 'Lite – 1 GB at Max speed then throttle to 512 kb/s';
      case OfferSpeedTier.essential:
        return 'Essential – 2 GB at Max speed then throttle to 1 Mb/s';
      case OfferSpeedTier.plus:
        return 'Plus – 3 GB at Max speed then throttle to 1 Mb/s';
      default:
        final raw = (speedTierRaw ?? bundleGroup ?? '').toLowerCase();
        if (raw.contains('lite') ||
            (raw.contains('fast') &&
                !raw.contains('faster') &&
                !raw.contains('fastest'))) {
          return 'Lite – 1 GB at Max speed then throttle to 512 kb/s';
        } else if (raw.contains('essential') || raw.contains('faster')) {
          return 'Essential – 2 GB at Max speed then throttle to 1 Mb/s';
        } else if (raw.contains('plus') ||
            raw.contains('fastest') ||
            raw.contains('premium')) {
          return 'Plus – 3 GB at Max speed then throttle to 1 Mb/s';
        }
        if (typeTag == 'DayPass' && dataAmountMb > 0) {
          return '${formatDataMb(dataAmountMb)}/day at Max speed then throttle to 384 kb/s';
        }
        return 'Unlimited data with fair-use speed policy';
    }
  }

  /// Maps a raw MB figure (which could be decimal like 1000 or binary like 1024)
  /// into a single canonical MB representation.
  static int canonicalizeDataMb(int mb) {
    if (mb <= 0) return 0;
    if (mb < 1000) {
      if (mb >= 450 && mb <= 550) return 500;
      return mb;
    }
    if (mb % 1024 == 0) {
      return (mb ~/ 1024) * 1000;
    }
    if (mb % 1000 == 0) {
      return mb;
    }
    final gbBin = mb / 1024.0;
    if ((gbBin * 10).roundToDouble() == gbBin * 10) {
      return (gbBin * 1000).round();
    }
    final gbDec = mb / 1000.0;
    if ((gbDec * 10).roundToDouble() == gbDec * 10) {
      return (gbDec * 1000).round();
    }
    return mb;
  }

  /// Returns all real database variants (decimal and binary) for a canonical MB size
  /// so filtering by "1 GB" matches both 1000 MB (eSIM Go) and 1024 MB (Zendit / eSIMAccess).
  static List<int> dataMbVariants(int mb) {
    final c = canonicalizeDataMb(mb);
    if (c <= 0) return [mb];
    if (c < 1000) {
      if (c == 500) return const [500, 512];
      return [c];
    }
    final gb = c ~/ 1000;
    if (c % 1000 == 0) {
      final bin = gb * 1024;
      return [c, bin];
    }
    return [c];
  }

  /// Renders a size the way the supplier sells it.
  ///
  /// Unifies decimal (1000 MB) and binary (1024 MB) formats so both render as
  /// "1 GB" instead of "1.0 GB", and 2048 MB renders as "2 GB" instead of "2.0 GB".
  /// Sub-GB amounts format as MB (e.g. "100 MB", "500 MB").
  static String formatDataMb(int mb) {
    if (mb <= 0) return '0 MB';
    final canonical = canonicalizeDataMb(mb);
    if (canonical < 1000) {
      return '$canonical MB';
    }
    final gb = canonical / 1000.0;
    return '${gb == gb.roundToDouble() ? gb.toInt() : gb.toStringAsFixed(1)} GB';
  }

  /// Predefined map of ISO-3166 alpha-2 country codes to English names.
  static const Map<String, String> defaultCountryNames = {
    'FR': 'France', 'US': 'United States', 'GB': 'United Kingdom',
    'DE': 'Germany', 'ES': 'Spain', 'IT': 'Italy', 'PT': 'Portugal',
    'GR': 'Greece', 'NL': 'Netherlands', 'CH': 'Switzerland',
    'AT': 'Austria', 'BE': 'Belgium', 'IE': 'Ireland', 'PL': 'Poland',
    'AE': 'United Arab Emirates', 'SA': 'Saudi Arabia', 'QA': 'Qatar',
    'KW': 'Kuwait', 'BH': 'Bahrain', 'OM': 'Oman', 'JO': 'Jordan',
    'EG': 'Egypt', 'MA': 'Morocco', 'TR': 'Turkey', 'PS': 'Palestine',
    'IN': 'India', 'PK': 'Pakistan', 'BD': 'Bangladesh', 'LK': 'Sri Lanka',
    'NP': 'Nepal', 'PH': 'Philippines', 'ID': 'Indonesia', 'MY': 'Malaysia',
    'SG': 'Singapore', 'TH': 'Thailand', 'VN': 'Vietnam', 'JP': 'Japan',
    'KR': 'South Korea', 'CN': 'China', 'HK': 'Hong Kong',
    'AU': 'Australia', 'NZ': 'New Zealand', 'CA': 'Canada', 'MX': 'Mexico',
    'BR': 'Brazil', 'AR': 'Argentina', 'ZA': 'South Africa',
    'KE': 'Kenya', 'NG': 'Nigeria', 'RU': 'Russia',
  };

  /// Resolves an ISO country code to its friendly English country name.
  static String? countryNameForCode(String code) {
    final cleaned = code.trim().toUpperCase();
    return defaultCountryNames[cleaned];
  }
}

/// The bounds one destination's catalogue actually offers, from
/// `compare_esim_filter_bounds()`.
///
/// The filter sheet used to hard-code its chip values with a comment warning
/// that "a 14 days chip would match nothing". The ladder is a property of the
/// catalogue, so it is read from the catalogue — and it differs by country:
/// France sells 12 metered sizes across 4 durations, and offering the global
/// ladder there invents choices that return nothing.
class CompareBounds {
  const CompareBounds({
    this.durations = const [],
    this.dataMb = const [],
    this.minPriceUsd,
    this.maxPriceUsd,
    this.hasUnlimited = false,
  });

  final List<int> durations;
  final List<int> dataMb;
  final double? minPriceUsd;
  final double? maxPriceUsd;
  final bool hasUnlimited;

  bool get isEmpty => durations.isEmpty && dataMb.isEmpty;

  /// Returns the catalogue's data sizes unified into canonical sizes without duplicates.
  /// E.g. [100, 500, 1000, 1024, 2000, 2048] -> [100, 500, 1000, 2000].
  List<int> get canonicalDataMb {
    final set = <int>{};
    for (final mb in dataMb) {
      if (mb > 0) {
        set.add(CompareOffer.canonicalizeDataMb(mb));
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  factory CompareBounds.fromRpc(dynamic raw) {
    if (raw is! Map) return const CompareBounds();
    final map = Map<String, dynamic>.from(raw);
    List<int> ints(String key) =>
        (map[key] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toInt())
            .toList();
    return CompareBounds(
      durations: ints('durations'),
      dataMb: ints('data_mb'),
      minPriceUsd: (map['min_price_usd'] as num?)?.toDouble(),
      maxPriceUsd: (map['max_price_usd'] as num?)?.toDouble(),
      hasUnlimited: map['has_unlimited'] as bool? ?? false,
    );
  }
}

/// How a numeric dimension is being asked about.
///
/// The three shapes are not interchangeable, which is why the mode is stored
/// rather than inferred from whichever field happens to be non-null: "any
/// length" (all), "between 1 and 7 days" (range) and "the 3-day or the 7-day
/// one" (exact) are three different questions, and a user who taps Range and
/// has not moved the slider yet still means Range.
enum RangeFilterMode { all, range, exact }

/// Data has a fourth answer that is not a quantity at all.
///
/// Unlimited used to be a switch sitting beside the size chips, which asked
/// "unlimited what?" — the catalogue also has speed tiers called Unlimited
/// Lite/Essential/Plus, so a bare "Unlimited" toggle next to a Speed section
/// was genuinely ambiguous. As a mode it reads as what it is: one of the
/// answers to "how much data", mutually exclusive with naming a size.
enum DataFilterMode { all, range, exact, unlimited }

/// The filter state the compare screen sends to `compare_esim_offers()`.
///
/// Filtering happens in SQL, not in Dart: the catalogue is 5,412 bundles and
/// pulling it down to filter on the device was only ever viable while it was
/// truncated to 50. The `wire*` getters are what actually goes over the wire —
/// they exist so the mode rules (an exact list only counts in exact mode, an
/// empty box is NULL and not 0) are decided in one place instead of being
/// re-derived by the repository, the sheet and the badge separately.
class CompareFilters {
  const CompareFilters({
    this.coverage,
    this.validityMode = RangeFilterMode.all,
    this.minDays,
    this.maxDays,
    this.daysExact = const [],
    this.dataMode = DataFilterMode.all,
    this.minDataMb,
    this.maxDataMb,
    this.dataExactMb = const [],
    this.priceRangeOn = false,
    this.minPriceUsd,
    this.maxPriceUsd,
    this.speedTiers,
    this.sort = CompareSort.price,
  });

  final String? coverage; // 'local' | 'regional' | 'global'

  final RangeFilterMode validityMode;
  final int? minDays;
  final int? maxDays;
  final List<int> daysExact;

  final DataFilterMode dataMode;
  final int? minDataMb;
  final int? maxDataMb;
  final List<int> dataExactMb;

  /// Price has no exact mode — nobody shops for a plan that costs precisely
  /// $12.40 — so the segmented control is just All / Range.
  final bool priceRangeOn;

  /// Both bounds are optional inside the range. An empty minimum means 0 and
  /// an empty maximum means the top of the catalogue; neither is sent as a
  /// number, because sending 0 for an empty maximum would mean the opposite of
  /// what the user left blank.
  final double? minPriceUsd;
  final double? maxPriceUsd;

  final List<String>? speedTiers;
  final CompareSort sort;

  // ── What the server is actually asked ────────────────────────────────────
  int? get wireMinDays =>
      validityMode == RangeFilterMode.range ? minDays : null;
  int? get wireMaxDays =>
      validityMode == RangeFilterMode.range ? maxDays : null;
  List<int>? get wireDaysExact =>
      validityMode == RangeFilterMode.exact && daysExact.isNotEmpty
          ? daysExact
          : null;

  int? get wireMinDataMb => dataMode == DataFilterMode.range ? minDataMb : null;
  int? get wireMaxDataMb => dataMode == DataFilterMode.range ? maxDataMb : null;
  List<int>? get wireDataExactMb {
    if (dataMode != DataFilterMode.exact || dataExactMb.isEmpty) {
      return null;
    }
    final set = <int>{};
    for (final mb in dataExactMb) {
      set.addAll(CompareOffer.dataMbVariants(mb));
    }
    final list = set.toList()..sort();
    return list.isEmpty ? null : list;
  }
  bool get wireUnlimitedOnly => dataMode == DataFilterMode.unlimited;
  List<String>? get wireSpeedTiers =>
      dataMode == DataFilterMode.unlimited ? speedTiers : null;

  double? get wireMinPriceUsd => priceRangeOn ? minPriceUsd : null;
  double? get wireMaxPriceUsd => priceRangeOn ? maxPriceUsd : null;

  // ── Which sections are narrowing the list ────────────────────────────────
  // A mode that is selected but not yet filled in narrows nothing, so it must
  // not inflate the badge on the Filters pill. "Range" with both ends blank is
  // "All" with extra steps.
  bool get validityIsActive => switch (validityMode) {
        RangeFilterMode.all => false,
        RangeFilterMode.range => minDays != null || maxDays != null,
        RangeFilterMode.exact => daysExact.isNotEmpty,
      };

  bool get dataIsActive => switch (dataMode) {
        DataFilterMode.all => false,
        DataFilterMode.unlimited => true,
        DataFilterMode.range => minDataMb != null || maxDataMb != null,
        DataFilterMode.exact => dataExactMb.isNotEmpty,
      };

  bool get priceIsActive =>
      priceRangeOn && (minPriceUsd != null || maxPriceUsd != null);

  bool get speedIsActive =>
      dataMode == DataFilterMode.unlimited &&
      speedTiers != null &&
      speedTiers!.isNotEmpty;

  int get activeCount => [
        coverage != null,
        validityIsActive,
        dataIsActive,
        priceIsActive,
        speedIsActive,
      ].where((e) => e).length;

  CompareFilters copyWith({
    Object? coverage = _sentinel,
    RangeFilterMode? validityMode,
    Object? minDays = _sentinel,
    Object? maxDays = _sentinel,
    List<int>? daysExact,
    DataFilterMode? dataMode,
    Object? minDataMb = _sentinel,
    Object? maxDataMb = _sentinel,
    List<int>? dataExactMb,
    bool? priceRangeOn,
    Object? minPriceUsd = _sentinel,
    Object? maxPriceUsd = _sentinel,
    Object? speedTiers = _sentinel,
    CompareSort? sort,
  }) {
    return CompareFilters(
      coverage: coverage == _sentinel ? this.coverage : coverage as String?,
      validityMode: validityMode ?? this.validityMode,
      minDays: minDays == _sentinel ? this.minDays : minDays as int?,
      maxDays: maxDays == _sentinel ? this.maxDays : maxDays as int?,
      daysExact: daysExact ?? this.daysExact,
      dataMode: dataMode ?? this.dataMode,
      minDataMb: minDataMb == _sentinel ? this.minDataMb : minDataMb as int?,
      maxDataMb: maxDataMb == _sentinel ? this.maxDataMb : maxDataMb as int?,
      dataExactMb: dataExactMb ?? this.dataExactMb,
      priceRangeOn: priceRangeOn ?? this.priceRangeOn,
      minPriceUsd:
          minPriceUsd == _sentinel ? this.minPriceUsd : minPriceUsd as double?,
      maxPriceUsd:
          maxPriceUsd == _sentinel ? this.maxPriceUsd : maxPriceUsd as double?,
      speedTiers:
          speedTiers == _sentinel ? this.speedTiers : speedTiers as List<String>?,
      sort: sort ?? this.sort,
    );
  }

  // A plain `null` default cannot distinguish "leave alone" from "clear it",
  // and every bound here is legitimately clearable.
  static const Object _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is CompareFilters &&
      other.coverage == coverage &&
      other.validityMode == validityMode &&
      other.minDays == minDays &&
      other.maxDays == maxDays &&
      other.dataMode == dataMode &&
      other.minDataMb == minDataMb &&
      other.maxDataMb == maxDataMb &&
      other.priceRangeOn == priceRangeOn &&
      other.minPriceUsd == minPriceUsd &&
      other.maxPriceUsd == maxPriceUsd &&
      other.sort == sort &&
      _listEq(other.daysExact, daysExact) &&
      _listEq(other.dataExactMb, dataExactMb) &&
      _listEq(other.speedTiers, speedTiers);

  @override
  int get hashCode => Object.hash(
        coverage,
        validityMode,
        minDays,
        maxDays,
        daysExact.join(','),
        dataMode,
        minDataMb,
        maxDataMb,
        dataExactMb.join(','),
        priceRangeOn,
        minPriceUsd,
        maxPriceUsd,
        sort,
        speedTiers?.join(','),
      );

  static bool _listEq(List<Object>? a, List<Object>? b) {
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
