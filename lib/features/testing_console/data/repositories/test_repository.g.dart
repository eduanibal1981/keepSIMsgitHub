// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(testRepository)
final testRepositoryProvider = TestRepositoryProvider._();

final class TestRepositoryProvider
    extends $FunctionalProvider<TestRepository, TestRepository, TestRepository>
    with $Provider<TestRepository> {
  TestRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testRepositoryHash();

  @$internal
  @override
  $ProviderElement<TestRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TestRepository create(Ref ref) {
    return testRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TestRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TestRepository>(value),
    );
  }
}

String _$testRepositoryHash() => r'cd004572985c8d9c953c0cba12e14535a2e94d9b';
