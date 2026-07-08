// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_formatter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrencyCodeController)
final currencyCodeControllerProvider = CurrencyCodeControllerProvider._();

final class CurrencyCodeControllerProvider
    extends $NotifierProvider<CurrencyCodeController, String> {
  CurrencyCodeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencyCodeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencyCodeControllerHash();

  @$internal
  @override
  CurrencyCodeController create() => CurrencyCodeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$currencyCodeControllerHash() =>
    r'd789195eb8588a0b64c9ace14b75897618bb079e';

abstract class _$CurrencyCodeController extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
