// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountDeletionRecord)
final accountDeletionRecordProvider = AccountDeletionRecordProvider._();

final class AccountDeletionRecordProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>?>,
          Map<String, dynamic>?,
          FutureOr<Map<String, dynamic>?>
        >
    with
        $FutureModifier<Map<String, dynamic>?>,
        $FutureProvider<Map<String, dynamic>?> {
  AccountDeletionRecordProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionRecordProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionRecordHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>?> create(Ref ref) {
    return accountDeletionRecord(ref);
  }
}

String _$accountDeletionRecordHash() =>
    r'77b874620403e91f41781ab2738dc9e660987f28';

@ProviderFor(PrivacyController)
final privacyControllerProvider = PrivacyControllerProvider._();

final class PrivacyControllerProvider
    extends $AsyncNotifierProvider<PrivacyController, bool> {
  PrivacyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privacyControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privacyControllerHash();

  @$internal
  @override
  PrivacyController create() => PrivacyController();
}

String _$privacyControllerHash() => r'848ec0c96bf3b2cb82f73dca62e8c43881085417';

abstract class _$PrivacyController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
