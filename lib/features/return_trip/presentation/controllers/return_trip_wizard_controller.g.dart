// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_trip_wizard_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReturnTripWizardController)
final returnTripWizardControllerProvider = ReturnTripWizardControllerFamily._();

final class ReturnTripWizardControllerProvider
    extends
        $NotifierProvider<ReturnTripWizardController, ReturnTripWizardState> {
  ReturnTripWizardControllerProvider._({
    required ReturnTripWizardControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'returnTripWizardControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$returnTripWizardControllerHash();

  @override
  String toString() {
    return r'returnTripWizardControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReturnTripWizardController create() => ReturnTripWizardController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReturnTripWizardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReturnTripWizardState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReturnTripWizardControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$returnTripWizardControllerHash() =>
    r'02e783b432d8211b98e3efd2ca44ebcd3ea9a01c';

final class ReturnTripWizardControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ReturnTripWizardController,
          ReturnTripWizardState,
          ReturnTripWizardState,
          ReturnTripWizardState,
          String
        > {
  ReturnTripWizardControllerFamily._()
    : super(
        retry: null,
        name: r'returnTripWizardControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReturnTripWizardControllerProvider call(String simLineId) =>
      ReturnTripWizardControllerProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'returnTripWizardControllerProvider';
}

abstract class _$ReturnTripWizardController
    extends $Notifier<ReturnTripWizardState> {
  late final _$args = ref.$arg as String;
  String get simLineId => _$args;

  ReturnTripWizardState build(String simLineId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReturnTripWizardState, ReturnTripWizardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReturnTripWizardState, ReturnTripWizardState>,
              ReturnTripWizardState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
