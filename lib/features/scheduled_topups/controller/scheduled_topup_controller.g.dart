// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_topup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ScheduledTopupController)
final scheduledTopupControllerProvider = ScheduledTopupControllerProvider._();

final class ScheduledTopupControllerProvider
    extends
        $AsyncNotifierProvider<ScheduledTopupController, List<ScheduledTopup>> {
  ScheduledTopupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledTopupControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledTopupControllerHash();

  @$internal
  @override
  ScheduledTopupController create() => ScheduledTopupController();
}

String _$scheduledTopupControllerHash() =>
    r'0d037559ce2accec25b4e9dfc1d56f715b5a244a';

abstract class _$ScheduledTopupController
    extends $AsyncNotifier<List<ScheduledTopup>> {
  FutureOr<List<ScheduledTopup>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ScheduledTopup>>, List<ScheduledTopup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ScheduledTopup>>,
                List<ScheduledTopup>
              >,
              AsyncValue<List<ScheduledTopup>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Helper provider to get schedule for a specific SIM line.

@ProviderFor(scheduledTopupForLine)
final scheduledTopupForLineProvider = ScheduledTopupForLineFamily._();

/// Helper provider to get schedule for a specific SIM line.

final class ScheduledTopupForLineProvider
    extends
        $FunctionalProvider<ScheduledTopup?, ScheduledTopup?, ScheduledTopup?>
    with $Provider<ScheduledTopup?> {
  /// Helper provider to get schedule for a specific SIM line.
  ScheduledTopupForLineProvider._({
    required ScheduledTopupForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'scheduledTopupForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduledTopupForLineHash();

  @override
  String toString() {
    return r'scheduledTopupForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ScheduledTopup?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduledTopup? create(Ref ref) {
    final argument = this.argument as String;
    return scheduledTopupForLine(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledTopup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledTopup?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledTopupForLineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledTopupForLineHash() =>
    r'f599c7a508a02a012903973e5b6cc2399a07ebb8';

/// Helper provider to get schedule for a specific SIM line.

final class ScheduledTopupForLineFamily extends $Family
    with $FunctionalFamilyOverride<ScheduledTopup?, String> {
  ScheduledTopupForLineFamily._()
    : super(
        retry: null,
        name: r'scheduledTopupForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper provider to get schedule for a specific SIM line.

  ScheduledTopupForLineProvider call(String simLineId) =>
      ScheduledTopupForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'scheduledTopupForLineProvider';
}

/// Helper provider to get Notify schedule for a specific SIM line.

@ProviderFor(scheduledNotifyForLine)
final scheduledNotifyForLineProvider = ScheduledNotifyForLineFamily._();

/// Helper provider to get Notify schedule for a specific SIM line.

final class ScheduledNotifyForLineProvider
    extends
        $FunctionalProvider<ScheduledTopup?, ScheduledTopup?, ScheduledTopup?>
    with $Provider<ScheduledTopup?> {
  /// Helper provider to get Notify schedule for a specific SIM line.
  ScheduledNotifyForLineProvider._({
    required ScheduledNotifyForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'scheduledNotifyForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduledNotifyForLineHash();

  @override
  String toString() {
    return r'scheduledNotifyForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ScheduledTopup?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduledTopup? create(Ref ref) {
    final argument = this.argument as String;
    return scheduledNotifyForLine(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledTopup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledTopup?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledNotifyForLineProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledNotifyForLineHash() =>
    r'c73bd577ef9d37cb4dc0cc6a987eae4347c6b342';

/// Helper provider to get Notify schedule for a specific SIM line.

final class ScheduledNotifyForLineFamily extends $Family
    with $FunctionalFamilyOverride<ScheduledTopup?, String> {
  ScheduledNotifyForLineFamily._()
    : super(
        retry: null,
        name: r'scheduledNotifyForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper provider to get Notify schedule for a specific SIM line.

  ScheduledNotifyForLineProvider call(String simLineId) =>
      ScheduledNotifyForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'scheduledNotifyForLineProvider';
}

/// Helper provider to get Custom Refill schedule for a specific SIM line.

@ProviderFor(scheduledCustomRefillForLine)
final scheduledCustomRefillForLineProvider =
    ScheduledCustomRefillForLineFamily._();

/// Helper provider to get Custom Refill schedule for a specific SIM line.

final class ScheduledCustomRefillForLineProvider
    extends
        $FunctionalProvider<ScheduledTopup?, ScheduledTopup?, ScheduledTopup?>
    with $Provider<ScheduledTopup?> {
  /// Helper provider to get Custom Refill schedule for a specific SIM line.
  ScheduledCustomRefillForLineProvider._({
    required ScheduledCustomRefillForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'scheduledCustomRefillForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduledCustomRefillForLineHash();

  @override
  String toString() {
    return r'scheduledCustomRefillForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ScheduledTopup?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduledTopup? create(Ref ref) {
    final argument = this.argument as String;
    return scheduledCustomRefillForLine(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledTopup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledTopup?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledCustomRefillForLineProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledCustomRefillForLineHash() =>
    r'1b8202c419edd03eaf95c4e39807dad546b92b62';

/// Helper provider to get Custom Refill schedule for a specific SIM line.

final class ScheduledCustomRefillForLineFamily extends $Family
    with $FunctionalFamilyOverride<ScheduledTopup?, String> {
  ScheduledCustomRefillForLineFamily._()
    : super(
        retry: null,
        name: r'scheduledCustomRefillForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper provider to get Custom Refill schedule for a specific SIM line.

  ScheduledCustomRefillForLineProvider call(String simLineId) =>
      ScheduledCustomRefillForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'scheduledCustomRefillForLineProvider';
}

/// Helper provider to get Mini Refill schedule for a specific SIM line.

@ProviderFor(scheduledMiniRefillForLine)
final scheduledMiniRefillForLineProvider = ScheduledMiniRefillForLineFamily._();

/// Helper provider to get Mini Refill schedule for a specific SIM line.

final class ScheduledMiniRefillForLineProvider
    extends
        $FunctionalProvider<ScheduledTopup?, ScheduledTopup?, ScheduledTopup?>
    with $Provider<ScheduledTopup?> {
  /// Helper provider to get Mini Refill schedule for a specific SIM line.
  ScheduledMiniRefillForLineProvider._({
    required ScheduledMiniRefillForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'scheduledMiniRefillForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scheduledMiniRefillForLineHash();

  @override
  String toString() {
    return r'scheduledMiniRefillForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ScheduledTopup?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduledTopup? create(Ref ref) {
    final argument = this.argument as String;
    return scheduledMiniRefillForLine(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledTopup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledTopup?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledMiniRefillForLineProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledMiniRefillForLineHash() =>
    r'561e99894ac2169d57b7c3c534ca65a389517aec';

/// Helper provider to get Mini Refill schedule for a specific SIM line.

final class ScheduledMiniRefillForLineFamily extends $Family
    with $FunctionalFamilyOverride<ScheduledTopup?, String> {
  ScheduledMiniRefillForLineFamily._()
    : super(
        retry: null,
        name: r'scheduledMiniRefillForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Helper provider to get Mini Refill schedule for a specific SIM line.

  ScheduledMiniRefillForLineProvider call(String simLineId) =>
      ScheduledMiniRefillForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'scheduledMiniRefillForLineProvider';
}

/// Family provider to watch execution history for a SIM Line.

@ProviderFor(topupExecutionsForLine)
final topupExecutionsForLineProvider = TopupExecutionsForLineFamily._();

/// Family provider to watch execution history for a SIM Line.

final class TopupExecutionsForLineProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TopupExecution>>,
          List<TopupExecution>,
          FutureOr<List<TopupExecution>>
        >
    with
        $FutureModifier<List<TopupExecution>>,
        $FutureProvider<List<TopupExecution>> {
  /// Family provider to watch execution history for a SIM Line.
  TopupExecutionsForLineProvider._({
    required TopupExecutionsForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'topupExecutionsForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$topupExecutionsForLineHash();

  @override
  String toString() {
    return r'topupExecutionsForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TopupExecution>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TopupExecution>> create(Ref ref) {
    final argument = this.argument as String;
    return topupExecutionsForLine(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TopupExecutionsForLineProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$topupExecutionsForLineHash() =>
    r'a3fc7ef02c79e6f526ca8449248422968ca5fa8a';

/// Family provider to watch execution history for a SIM Line.

final class TopupExecutionsForLineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TopupExecution>>, String> {
  TopupExecutionsForLineFamily._()
    : super(
        retry: null,
        name: r'topupExecutionsForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Family provider to watch execution history for a SIM Line.

  TopupExecutionsForLineProvider call(String simLineId) =>
      TopupExecutionsForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'topupExecutionsForLineProvider';
}

/// Live execution status for a SIM line (C3).
///
/// An instant refill is handed to worker_instant_refill, whose round trip has
/// no fixed duration — it debits the wallet, calls the provider, and may refund.
/// The UI used to guess with a 3-second timer, which refreshed the balance
/// either before the worker had finished or long after. Streaming the row means
/// the status and the wallet update exactly when the worker actually moves them.

@ProviderFor(topupExecutionsLive)
final topupExecutionsLiveProvider = TopupExecutionsLiveFamily._();

/// Live execution status for a SIM line (C3).
///
/// An instant refill is handed to worker_instant_refill, whose round trip has
/// no fixed duration — it debits the wallet, calls the provider, and may refund.
/// The UI used to guess with a 3-second timer, which refreshed the balance
/// either before the worker had finished or long after. Streaming the row means
/// the status and the wallet update exactly when the worker actually moves them.

final class TopupExecutionsLiveProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TopupExecution>>,
          List<TopupExecution>,
          Stream<List<TopupExecution>>
        >
    with
        $FutureModifier<List<TopupExecution>>,
        $StreamProvider<List<TopupExecution>> {
  /// Live execution status for a SIM line (C3).
  ///
  /// An instant refill is handed to worker_instant_refill, whose round trip has
  /// no fixed duration — it debits the wallet, calls the provider, and may refund.
  /// The UI used to guess with a 3-second timer, which refreshed the balance
  /// either before the worker had finished or long after. Streaming the row means
  /// the status and the wallet update exactly when the worker actually moves them.
  TopupExecutionsLiveProvider._({
    required TopupExecutionsLiveFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'topupExecutionsLiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$topupExecutionsLiveHash();

  @override
  String toString() {
    return r'topupExecutionsLiveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TopupExecution>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TopupExecution>> create(Ref ref) {
    final argument = this.argument as String;
    return topupExecutionsLive(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TopupExecutionsLiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$topupExecutionsLiveHash() =>
    r'a7202867d5fb4eacb916a2de8837e33112499d13';

/// Live execution status for a SIM line (C3).
///
/// An instant refill is handed to worker_instant_refill, whose round trip has
/// no fixed duration — it debits the wallet, calls the provider, and may refund.
/// The UI used to guess with a 3-second timer, which refreshed the balance
/// either before the worker had finished or long after. Streaming the row means
/// the status and the wallet update exactly when the worker actually moves them.

final class TopupExecutionsLiveFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TopupExecution>>, String> {
  TopupExecutionsLiveFamily._()
    : super(
        retry: null,
        name: r'topupExecutionsLiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Live execution status for a SIM line (C3).
  ///
  /// An instant refill is handed to worker_instant_refill, whose round trip has
  /// no fixed duration — it debits the wallet, calls the provider, and may refund.
  /// The UI used to guess with a 3-second timer, which refreshed the balance
  /// either before the worker had finished or long after. Streaming the row means
  /// the status and the wallet update exactly when the worker actually moves them.

  TopupExecutionsLiveProvider call(String simLineId) =>
      TopupExecutionsLiveProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'topupExecutionsLiveProvider';
}

/// Paginated execution history provider.

@ProviderFor(SimLineExecutionsHistory)
final simLineExecutionsHistoryProvider = SimLineExecutionsHistoryFamily._();

/// Paginated execution history provider.
final class SimLineExecutionsHistoryProvider
    extends
        $AsyncNotifierProvider<SimLineExecutionsHistory, List<TopupExecution>> {
  /// Paginated execution history provider.
  SimLineExecutionsHistoryProvider._({
    required SimLineExecutionsHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'simLineExecutionsHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$simLineExecutionsHistoryHash();

  @override
  String toString() {
    return r'simLineExecutionsHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SimLineExecutionsHistory create() => SimLineExecutionsHistory();

  @override
  bool operator ==(Object other) {
    return other is SimLineExecutionsHistoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$simLineExecutionsHistoryHash() =>
    r'5da368dd1b73587ae9c6ade6a7077f1391c70534';

/// Paginated execution history provider.

final class SimLineExecutionsHistoryFamily extends $Family
    with
        $ClassFamilyOverride<
          SimLineExecutionsHistory,
          AsyncValue<List<TopupExecution>>,
          List<TopupExecution>,
          FutureOr<List<TopupExecution>>,
          String
        > {
  SimLineExecutionsHistoryFamily._()
    : super(
        retry: null,
        name: r'simLineExecutionsHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Paginated execution history provider.

  SimLineExecutionsHistoryProvider call(String simLineId) =>
      SimLineExecutionsHistoryProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'simLineExecutionsHistoryProvider';
}

/// Paginated execution history provider.

abstract class _$SimLineExecutionsHistory
    extends $AsyncNotifier<List<TopupExecution>> {
  late final _$args = ref.$arg as String;
  String get simLineId => _$args;

  FutureOr<List<TopupExecution>> build(String simLineId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<TopupExecution>>, List<TopupExecution>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TopupExecution>>,
                List<TopupExecution>
              >,
              AsyncValue<List<TopupExecution>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
