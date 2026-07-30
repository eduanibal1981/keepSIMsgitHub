// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the payload most recently handed to the platform, or null when
/// nothing has been published (unsupported platform, or the plugin refused).
/// Exposed mainly so the state is inspectable in devtools; nothing reads it.

@ProviderFor(HomeWidgetSync)
final homeWidgetSyncProvider = HomeWidgetSyncProvider._();

/// Returns the payload most recently handed to the platform, or null when
/// nothing has been published (unsupported platform, or the plugin refused).
/// Exposed mainly so the state is inspectable in devtools; nothing reads it.
final class HomeWidgetSyncProvider
    extends $NotifierProvider<HomeWidgetSync, String?> {
  /// Returns the payload most recently handed to the platform, or null when
  /// nothing has been published (unsupported platform, or the plugin refused).
  /// Exposed mainly so the state is inspectable in devtools; nothing reads it.
  HomeWidgetSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeWidgetSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeWidgetSyncHash();

  @$internal
  @override
  HomeWidgetSync create() => HomeWidgetSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$homeWidgetSyncHash() => r'abc3ba2163cf848a9facf5cb5183b4a62fc5e156';

/// Returns the payload most recently handed to the platform, or null when
/// nothing has been published (unsupported platform, or the plugin refused).
/// Exposed mainly so the state is inspectable in devtools; nothing reads it.

abstract class _$HomeWidgetSync extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
