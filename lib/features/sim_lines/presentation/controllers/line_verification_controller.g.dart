// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_verification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LineVerificationController)
final lineVerificationControllerProvider = LineVerificationControllerFamily._();

final class LineVerificationControllerProvider
    extends
        $NotifierProvider<LineVerificationController, LineVerificationState> {
  LineVerificationControllerProvider._({
    required LineVerificationControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lineVerificationControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lineVerificationControllerHash();

  @override
  String toString() {
    return r'lineVerificationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LineVerificationController create() => LineVerificationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LineVerificationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LineVerificationState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LineVerificationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lineVerificationControllerHash() =>
    r'36ea7eb2b5d90a9008c57fda012ea577c6a7b0e8';

final class LineVerificationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          LineVerificationController,
          LineVerificationState,
          LineVerificationState,
          LineVerificationState,
          String
        > {
  LineVerificationControllerFamily._()
    : super(
        retry: null,
        name: r'lineVerificationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LineVerificationControllerProvider call(String simLineId) =>
      LineVerificationControllerProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'lineVerificationControllerProvider';
}

abstract class _$LineVerificationController
    extends $Notifier<LineVerificationState> {
  late final _$args = ref.$arg as String;
  String get simLineId => _$args;

  LineVerificationState build(String simLineId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LineVerificationState, LineVerificationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LineVerificationState, LineVerificationState>,
              LineVerificationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
