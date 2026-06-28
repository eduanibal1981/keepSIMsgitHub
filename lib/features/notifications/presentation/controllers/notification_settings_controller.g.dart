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
    r'730729cc55ccb39e11b4361fd0990b17310dc31b';

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
    r'963230a94a077e2dc189abd4ffcb32d4d8f391a7';

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
    r'd3ec17b1bd996ac5919d7877064f37033e085c6d';

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
