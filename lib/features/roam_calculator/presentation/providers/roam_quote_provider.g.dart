// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roam_quote_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The comparison itself. Returns null only when the country code is empty —
/// every other outcome is a `verdict` the UI is expected to render.

@ProviderFor(roamQuote)
final roamQuoteProvider = RoamQuoteFamily._();

/// The comparison itself. Returns null only when the country code is empty —
/// every other outcome is a `verdict` the UI is expected to render.

final class RoamQuoteProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoamQuote?>,
          RoamQuote?,
          FutureOr<RoamQuote?>
        >
    with $FutureModifier<RoamQuote?>, $FutureProvider<RoamQuote?> {
  /// The comparison itself. Returns null only when the country code is empty —
  /// every other outcome is a `verdict` the UI is expected to render.
  RoamQuoteProvider._({
    required RoamQuoteFamily super.from,
    required RoamQuoteInput super.argument,
  }) : super(
         retry: null,
         name: r'roamQuoteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roamQuoteHash();

  @override
  String toString() {
    return r'roamQuoteProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RoamQuote?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoamQuote?> create(Ref ref) {
    final argument = this.argument as RoamQuoteInput;
    return roamQuote(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoamQuoteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roamQuoteHash() => r'1d7dbb8538f589b8370533a8f09477ad408f7c4a';

/// The comparison itself. Returns null only when the country code is empty —
/// every other outcome is a `verdict` the UI is expected to render.

final class RoamQuoteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoamQuote?>, RoamQuoteInput> {
  RoamQuoteFamily._()
    : super(
        retry: null,
        name: r'roamQuoteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The comparison itself. Returns null only when the country code is empty —
  /// every other outcome is a `verdict` the UI is expected to render.

  RoamQuoteProvider call(RoamQuoteInput input) =>
      RoamQuoteProvider._(argument: input, from: this);

  @override
  String toString() => r'roamQuoteProvider';
}

/// The caller's own carriers, home carrier first, for the picker.

@ProviderFor(roamCarriers)
final roamCarriersProvider = RoamCarriersFamily._();

/// The caller's own carriers, home carrier first, for the picker.

final class RoamCarriersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoamCarrierOption>>,
          List<RoamCarrierOption>,
          FutureOr<List<RoamCarrierOption>>
        >
    with
        $FutureModifier<List<RoamCarrierOption>>,
        $FutureProvider<List<RoamCarrierOption>> {
  /// The caller's own carriers, home carrier first, for the picker.
  RoamCarriersProvider._({
    required RoamCarriersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'roamCarriersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roamCarriersHash();

  @override
  String toString() {
    return r'roamCarriersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RoamCarrierOption>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RoamCarrierOption>> create(Ref ref) {
    final argument = this.argument as String;
    return roamCarriers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoamCarriersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roamCarriersHash() => r'21f0cb6731aeb082a326e5a5a64612a5e9b875a6';

/// The caller's own carriers, home carrier first, for the picker.

final class RoamCarriersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RoamCarrierOption>>, String> {
  RoamCarriersFamily._()
    : super(
        retry: null,
        name: r'roamCarriersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The caller's own carriers, home carrier first, for the picker.

  RoamCarriersProvider call(String countryCode) =>
      RoamCarriersProvider._(argument: countryCode, from: this);

  @override
  String toString() => r'roamCarriersProvider';
}
