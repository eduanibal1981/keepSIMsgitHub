// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_refill_quote_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a tier-aware quote for a specific SIM line and base cost.

@ProviderFor(lineRefillQuote)
final lineRefillQuoteProvider = LineRefillQuoteFamily._();

/// Provides a tier-aware quote for a specific SIM line and base cost.

final class LineRefillQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<LineRefillQuote>,
          LineRefillQuote,
          FutureOr<LineRefillQuote>
        >
    with $FutureModifier<LineRefillQuote>, $FutureProvider<LineRefillQuote> {
  /// Provides a tier-aware quote for a specific SIM line and base cost.
  LineRefillQuoteProvider._({
    required LineRefillQuoteFamily super.from,
    required ({
      SimLine line,
      double baseCostUsd,
      String? offerId,
      int? offerValue,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'lineRefillQuoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lineRefillQuoteHash();

  @override
  String toString() {
    return r'lineRefillQuoteProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<LineRefillQuote> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LineRefillQuote> create(Ref ref) {
    final argument =
        this.argument
            as ({
              SimLine line,
              double baseCostUsd,
              String? offerId,
              int? offerValue,
            });
    return lineRefillQuote(
      ref,
      line: argument.line,
      baseCostUsd: argument.baseCostUsd,
      offerId: argument.offerId,
      offerValue: argument.offerValue,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LineRefillQuoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lineRefillQuoteHash() => r'c658f29f33486cd91dc2c1502a3c54d5517c0a62';

/// Provides a tier-aware quote for a specific SIM line and base cost.

final class LineRefillQuoteFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<LineRefillQuote>,
          ({SimLine line, double baseCostUsd, String? offerId, int? offerValue})
        > {
  LineRefillQuoteFamily._()
    : super(
        retry: null,
        name: r'lineRefillQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides a tier-aware quote for a specific SIM line and base cost.

  LineRefillQuoteProvider call({
    required SimLine line,
    required double baseCostUsd,
    String? offerId,
    int? offerValue,
  }) => LineRefillQuoteProvider._(
    argument: (
      line: line,
      baseCostUsd: baseCostUsd,
      offerId: offerId,
      offerValue: offerValue,
    ),
    from: this,
  );

  @override
  String toString() => r'lineRefillQuoteProvider';
}

/// Provides a suggested tier-aware quote for the line's usage forecast.
///
/// Combines:
/// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
/// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
/// 3. The line's effective tier and published fee rules.

@ProviderFor(suggestedLineRefillQuote)
final suggestedLineRefillQuoteProvider = SuggestedLineRefillQuoteFamily._();

/// Provides a suggested tier-aware quote for the line's usage forecast.
///
/// Combines:
/// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
/// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
/// 3. The line's effective tier and published fee rules.

final class SuggestedLineRefillQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<LineRefillQuote?>,
          LineRefillQuote?,
          FutureOr<LineRefillQuote?>
        >
    with $FutureModifier<LineRefillQuote?>, $FutureProvider<LineRefillQuote?> {
  /// Provides a suggested tier-aware quote for the line's usage forecast.
  ///
  /// Combines:
  /// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
  /// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
  /// 3. The line's effective tier and published fee rules.
  SuggestedLineRefillQuoteProvider._({
    required SuggestedLineRefillQuoteFamily super.from,
    required SimLine super.argument,
  }) : super(
         retry: null,
         name: r'suggestedLineRefillQuoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$suggestedLineRefillQuoteHash();

  @override
  String toString() {
    return r'suggestedLineRefillQuoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LineRefillQuote?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LineRefillQuote?> create(Ref ref) {
    final argument = this.argument as SimLine;
    return suggestedLineRefillQuote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SuggestedLineRefillQuoteProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$suggestedLineRefillQuoteHash() =>
    r'57bd44508116508fba33978db3ede538b3123d71';

/// Provides a suggested tier-aware quote for the line's usage forecast.
///
/// Combines:
/// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
/// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
/// 3. The line's effective tier and published fee rules.

final class SuggestedLineRefillQuoteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LineRefillQuote?>, SimLine> {
  SuggestedLineRefillQuoteFamily._()
    : super(
        retry: null,
        name: r'suggestedLineRefillQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides a suggested tier-aware quote for the line's usage forecast.
  ///
  /// Combines:
  /// 1. The line's usage forecast (suggestedOfferId, suggestedAmountUsd, suggestedFrequencyDays).
  /// 2. The line's offer catalog to resolve the exact supplier base price of the suggested offer.
  /// 3. The line's effective tier and published fee rules.

  SuggestedLineRefillQuoteProvider call(SimLine line) =>
      SuggestedLineRefillQuoteProvider._(argument: line, from: this);

  @override
  String toString() => r'suggestedLineRefillQuoteProvider';
}
