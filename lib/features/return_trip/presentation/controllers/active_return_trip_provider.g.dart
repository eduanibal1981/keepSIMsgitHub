// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_return_trip_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeReturnTripInfo)
final activeReturnTripInfoProvider = ActiveReturnTripInfoFamily._();

final class ActiveReturnTripInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<ActiveReturnTripInfo?>,
          ActiveReturnTripInfo?,
          FutureOr<ActiveReturnTripInfo?>
        >
    with
        $FutureModifier<ActiveReturnTripInfo?>,
        $FutureProvider<ActiveReturnTripInfo?> {
  ActiveReturnTripInfoProvider._({
    required ActiveReturnTripInfoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeReturnTripInfoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeReturnTripInfoHash();

  @override
  String toString() {
    return r'activeReturnTripInfoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ActiveReturnTripInfo?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ActiveReturnTripInfo?> create(Ref ref) {
    final argument = this.argument as String;
    return activeReturnTripInfo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveReturnTripInfoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeReturnTripInfoHash() =>
    r'6ade6c72485cd6952f78bcfcb0bab34927945473';

final class ActiveReturnTripInfoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ActiveReturnTripInfo?>, String> {
  ActiveReturnTripInfoFamily._()
    : super(
        retry: null,
        name: r'activeReturnTripInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ActiveReturnTripInfoProvider call(String simLineId) =>
      ActiveReturnTripInfoProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'activeReturnTripInfoProvider';
}

@ProviderFor(returnTripHistory)
final returnTripHistoryProvider = ReturnTripHistoryFamily._();

final class ReturnTripHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActiveReturnTripInfo>>,
          List<ActiveReturnTripInfo>,
          FutureOr<List<ActiveReturnTripInfo>>
        >
    with
        $FutureModifier<List<ActiveReturnTripInfo>>,
        $FutureProvider<List<ActiveReturnTripInfo>> {
  ReturnTripHistoryProvider._({
    required ReturnTripHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'returnTripHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$returnTripHistoryHash();

  @override
  String toString() {
    return r'returnTripHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ActiveReturnTripInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ActiveReturnTripInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return returnTripHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReturnTripHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$returnTripHistoryHash() => r'bcd2996d538a40a6adb8c746e72b2bec308541af';

final class ReturnTripHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ActiveReturnTripInfo>>,
          String
        > {
  ReturnTripHistoryFamily._()
    : super(
        retry: null,
        name: r'returnTripHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReturnTripHistoryProvider call(String simLineId) =>
      ReturnTripHistoryProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'returnTripHistoryProvider';
}
