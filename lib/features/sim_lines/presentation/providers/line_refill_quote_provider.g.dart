// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_refill_quote_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(lineRefillQuote)
final lineRefillQuoteProvider = LineRefillQuoteFamily._();

final class LineRefillQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<LineRefillQuote>,
          LineRefillQuote,
          FutureOr<LineRefillQuote>
        >
    with $FutureModifier<LineRefillQuote>, $FutureProvider<LineRefillQuote> {
  LineRefillQuoteProvider._({
    required LineRefillQuoteFamily super.from,
    required ({SimLine line, String offerId, int? offerValue}) super.argument,
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
        this.argument as ({SimLine line, String offerId, int? offerValue});
    return lineRefillQuote(
      ref,
      line: argument.line,
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

String _$lineRefillQuoteHash() => r'9972f6872f5af3aaa0133d6c11eea83917a2ce93';

final class LineRefillQuoteFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<LineRefillQuote>,
          ({SimLine line, String offerId, int? offerValue})
        > {
  LineRefillQuoteFamily._()
    : super(
        retry: null,
        name: r'lineRefillQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LineRefillQuoteProvider call({
    required SimLine line,
    required String offerId,
    int? offerValue,
  }) => LineRefillQuoteProvider._(
    argument: (line: line, offerId: offerId, offerValue: offerValue),
    from: this,
  );

  @override
  String toString() => r'lineRefillQuoteProvider';
}

@ProviderFor(suggestedLineRefillQuote)
final suggestedLineRefillQuoteProvider = SuggestedLineRefillQuoteFamily._();

final class SuggestedLineRefillQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<LineRefillQuote?>,
          LineRefillQuote?,
          FutureOr<LineRefillQuote?>
        >
    with $FutureModifier<LineRefillQuote?>, $FutureProvider<LineRefillQuote?> {
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
    r'f5a44a1dfe1985cb4ce0957eda75cc56876ecb2a';

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

  SuggestedLineRefillQuoteProvider call(SimLine line) =>
      SuggestedLineRefillQuoteProvider._(argument: line, from: this);

  @override
  String toString() => r'suggestedLineRefillQuoteProvider';
}
