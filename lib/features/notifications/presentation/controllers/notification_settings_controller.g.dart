// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlertSettingsController)
final alertSettingsControllerProvider = AlertSettingsControllerProvider._();

final class AlertSettingsControllerProvider
    extends
        $AsyncNotifierProvider<AlertSettingsController, List<AlertSetting>> {
  AlertSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'alertSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$alertSettingsControllerHash();

  @$internal
  @override
  AlertSettingsController create() => AlertSettingsController();
}

String _$alertSettingsControllerHash() =>
    r'ecd1f6119b1c085c560f4942e6349213805d1a54';

abstract class _$AlertSettingsController
    extends $AsyncNotifier<List<AlertSetting>> {
  FutureOr<List<AlertSetting>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<AlertSetting>>, List<AlertSetting>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<AlertSetting>>, List<AlertSetting>>,
              AsyncValue<List<AlertSetting>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UserPreferencesController)
final userPreferencesControllerProvider = UserPreferencesControllerProvider._();

final class UserPreferencesControllerProvider
    extends $AsyncNotifierProvider<UserPreferencesController, UserPreferences> {
  UserPreferencesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userPreferencesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userPreferencesControllerHash();

  @$internal
  @override
  UserPreferencesController create() => UserPreferencesController();
}

String _$userPreferencesControllerHash() =>
    r'8eaba320447cdd743c706ecaf5c7ceea14b8f742';

abstract class _$UserPreferencesController
    extends $AsyncNotifier<UserPreferences> {
  FutureOr<UserPreferences> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserPreferences>, UserPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserPreferences>, UserPreferences>,
              AsyncValue<UserPreferences>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(NotificationChannelsController)
final notificationChannelsControllerProvider =
    NotificationChannelsControllerProvider._();

final class NotificationChannelsControllerProvider
    extends
        $AsyncNotifierProvider<
          NotificationChannelsController,
          List<Map<String, dynamic>>
        > {
  NotificationChannelsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationChannelsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationChannelsControllerHash();

  @$internal
  @override
  NotificationChannelsController create() => NotificationChannelsController();
}

String _$notificationChannelsControllerHash() =>
    r'a0fbe75b594f6c1194455432a8402446da401cf4';

abstract class _$NotificationChannelsController
    extends $AsyncNotifier<List<Map<String, dynamic>>> {
  FutureOr<List<Map<String, dynamic>>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<Map<String, dynamic>>>,
              List<Map<String, dynamic>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<Map<String, dynamic>>>,
                List<Map<String, dynamic>>
              >,
              AsyncValue<List<Map<String, dynamic>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(notificationChannelCatalog)
final notificationChannelCatalogProvider =
    NotificationChannelCatalogProvider._();

final class NotificationChannelCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Map<String, dynamic>>>,
          Map<String, Map<String, dynamic>>,
          FutureOr<Map<String, Map<String, dynamic>>>
        >
    with
        $FutureModifier<Map<String, Map<String, dynamic>>>,
        $FutureProvider<Map<String, Map<String, dynamic>>> {
  NotificationChannelCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationChannelCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationChannelCatalogHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Map<String, dynamic>>> create(Ref ref) {
    return notificationChannelCatalog(ref);
  }
}

String _$notificationChannelCatalogHash() =>
    r'cf769958e20401d536b36e85057c53e608d9bf84';
