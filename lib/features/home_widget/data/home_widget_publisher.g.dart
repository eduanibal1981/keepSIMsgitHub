// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_publisher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeWidgetPublisher)
final homeWidgetPublisherProvider = HomeWidgetPublisherProvider._();

final class HomeWidgetPublisherProvider
    extends
        $FunctionalProvider<
          HomeWidgetPublisher,
          HomeWidgetPublisher,
          HomeWidgetPublisher
        >
    with $Provider<HomeWidgetPublisher> {
  HomeWidgetPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeWidgetPublisherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeWidgetPublisherHash();

  @$internal
  @override
  $ProviderElement<HomeWidgetPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HomeWidgetPublisher create(Ref ref) {
    return homeWidgetPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeWidgetPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeWidgetPublisher>(value),
    );
  }
}

String _$homeWidgetPublisherHash() =>
    r'15306b09636b2dc9e362eee58c8effc5cab8c51c';
