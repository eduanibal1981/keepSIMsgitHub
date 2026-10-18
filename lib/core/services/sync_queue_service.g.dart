// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_queue_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SyncQueue)
final syncQueueProvider = SyncQueueProvider._();

final class SyncQueueProvider
    extends $NotifierProvider<SyncQueue, List<SyncOperation>> {
  SyncQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncQueueHash();

  @$internal
  @override
  SyncQueue create() => SyncQueue();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SyncOperation> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SyncOperation>>(value),
    );
  }
}

String _$syncQueueHash() => r'080b39f1d6a9d381317ed691d3621dd29eea6a9b';

abstract class _$SyncQueue extends $Notifier<List<SyncOperation>> {
  List<SyncOperation> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<SyncOperation>, List<SyncOperation>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<SyncOperation>, List<SyncOperation>>,
              List<SyncOperation>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
