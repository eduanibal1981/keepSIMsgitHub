// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileNotificationEmailStatus)
final profileNotificationEmailStatusProvider =
    ProfileNotificationEmailStatusProvider._();

final class ProfileNotificationEmailStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<NotificationEmailStatus>,
          NotificationEmailStatus,
          FutureOr<NotificationEmailStatus>
        >
    with
        $FutureModifier<NotificationEmailStatus>,
        $FutureProvider<NotificationEmailStatus> {
  ProfileNotificationEmailStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileNotificationEmailStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileNotificationEmailStatusHash();

  @$internal
  @override
  $FutureProviderElement<NotificationEmailStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NotificationEmailStatus> create(Ref ref) {
    return profileNotificationEmailStatus(ref);
  }
}

String _$profileNotificationEmailStatusHash() =>
    r'6200d6a662f0d01b4e8708576ef1271d98eeeaa5';

@ProviderFor(ProfileController)
final profileControllerProvider = ProfileControllerProvider._();

final class ProfileControllerProvider
    extends $AsyncNotifierProvider<ProfileController, void> {
  ProfileControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileControllerHash();

  @$internal
  @override
  ProfileController create() => ProfileController();
}

String _$profileControllerHash() => r'b05d1d55cc3fa9753af993024f24390e1aa6d550';

abstract class _$ProfileController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
