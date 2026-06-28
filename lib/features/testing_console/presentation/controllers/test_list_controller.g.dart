// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TestListController)
final testListControllerProvider = TestListControllerProvider._();

final class TestListControllerProvider
    extends $AsyncNotifierProvider<TestListController, List<TestCase>> {
  TestListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testListControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testListControllerHash();

  @$internal
  @override
  TestListController create() => TestListController();
}

String _$testListControllerHash() =>
    r'445029942b36846552121d7b87af6de99568437d';

abstract class _$TestListController extends $AsyncNotifier<List<TestCase>> {
  FutureOr<List<TestCase>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<TestCase>>, List<TestCase>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TestCase>>, List<TestCase>>,
              AsyncValue<List<TestCase>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
