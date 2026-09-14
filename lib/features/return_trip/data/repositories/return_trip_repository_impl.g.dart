// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_trip_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(returnTripRepository)
final returnTripRepositoryProvider = ReturnTripRepositoryProvider._();

final class ReturnTripRepositoryProvider
    extends
        $FunctionalProvider<
          ReturnTripRepository,
          ReturnTripRepository,
          ReturnTripRepository
        >
    with $Provider<ReturnTripRepository> {
  ReturnTripRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'returnTripRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$returnTripRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReturnTripRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReturnTripRepository create(Ref ref) {
    return returnTripRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReturnTripRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReturnTripRepository>(value),
    );
  }
}

String _$returnTripRepositoryHash() =>
    r'983225120224524bcd0ab71384d64bd8460949bd';
