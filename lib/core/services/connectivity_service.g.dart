// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityServiceHash() =>
    r'761fb6617e328492c913a40bfb1e5b774b56a2d2';

/// See also [ConnectivityService].
@ProviderFor(ConnectivityService)
final connectivityServiceProvider =
    NotifierProvider<ConnectivityService, NetworkStatus>.internal(
      ConnectivityService.new,
      name: r'connectivityServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$connectivityServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ConnectivityService = Notifier<NetworkStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
