// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sim_lines_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(simLinesRepository)
final simLinesRepositoryProvider = SimLinesRepositoryProvider._();

final class SimLinesRepositoryProvider
    extends
        $FunctionalProvider<
          SimLinesRepository,
          SimLinesRepository,
          SimLinesRepository
        >
    with $Provider<SimLinesRepository> {
  SimLinesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'simLinesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$simLinesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SimLinesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SimLinesRepository create(Ref ref) {
    return simLinesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SimLinesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SimLinesRepository>(value),
    );
  }
}

String _$simLinesRepositoryHash() =>
    r'0966df307d7c347ae5df7b37f69a825091baccdd';
