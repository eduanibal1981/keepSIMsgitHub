// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage_forecast_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The forecast for one SIM line, or null when the job has not produced one yet
/// (a line added since the last nightly run, or one that is no longer active).
///
/// A failure here must never take the detail screen down with it — the forecast
/// is an enhancement to the page, not the page.

@ProviderFor(usageForecastForLine)
final usageForecastForLineProvider = UsageForecastForLineFamily._();

/// The forecast for one SIM line, or null when the job has not produced one yet
/// (a line added since the last nightly run, or one that is no longer active).
///
/// A failure here must never take the detail screen down with it — the forecast
/// is an enhancement to the page, not the page.

final class UsageForecastForLineProvider
    extends
        $FunctionalProvider<
          AsyncValue<UsageForecast?>,
          UsageForecast?,
          FutureOr<UsageForecast?>
        >
    with $FutureModifier<UsageForecast?>, $FutureProvider<UsageForecast?> {
  /// The forecast for one SIM line, or null when the job has not produced one yet
  /// (a line added since the last nightly run, or one that is no longer active).
  ///
  /// A failure here must never take the detail screen down with it — the forecast
  /// is an enhancement to the page, not the page.
  UsageForecastForLineProvider._({
    required UsageForecastForLineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'usageForecastForLineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usageForecastForLineHash();

  @override
  String toString() {
    return r'usageForecastForLineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UsageForecast?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UsageForecast?> create(Ref ref) {
    final argument = this.argument as String;
    return usageForecastForLine(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UsageForecastForLineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usageForecastForLineHash() =>
    r'25b7f70fe5eb3193e6a45d74c15848c64a4c7829';

/// The forecast for one SIM line, or null when the job has not produced one yet
/// (a line added since the last nightly run, or one that is no longer active).
///
/// A failure here must never take the detail screen down with it — the forecast
/// is an enhancement to the page, not the page.

final class UsageForecastForLineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UsageForecast?>, String> {
  UsageForecastForLineFamily._()
    : super(
        retry: null,
        name: r'usageForecastForLineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The forecast for one SIM line, or null when the job has not produced one yet
  /// (a line added since the last nightly run, or one that is no longer active).
  ///
  /// A failure here must never take the detail screen down with it — the forecast
  /// is an enhancement to the page, not the page.

  UsageForecastForLineProvider call(String simLineId) =>
      UsageForecastForLineProvider._(argument: simLineId, from: this);

  @override
  String toString() => r'usageForecastForLineProvider';
}

/// Every forecast row the user can see, cached to disk (G4).
///
/// The per-line provider above is a live read for one screen; this one exists
/// because the home-screen widget needs the whole set, and needs it to survive
/// a cold offline start — the countdown it renders on a plane comes from here.
///
/// Cached rather than fetched-or-nothing: a forecast is regenerated nightly and
/// is about validity windows measured in weeks, so yesterday's copy is a good
/// answer and a blank widget is not.

@ProviderFor(usageForecasts)
final usageForecastsProvider = UsageForecastsProvider._();

/// Every forecast row the user can see, cached to disk (G4).
///
/// The per-line provider above is a live read for one screen; this one exists
/// because the home-screen widget needs the whole set, and needs it to survive
/// a cold offline start — the countdown it renders on a plane comes from here.
///
/// Cached rather than fetched-or-nothing: a forecast is regenerated nightly and
/// is about validity windows measured in weeks, so yesterday's copy is a good
/// answer and a blank widget is not.

final class UsageForecastsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UsageForecast>>,
          List<UsageForecast>,
          FutureOr<List<UsageForecast>>
        >
    with
        $FutureModifier<List<UsageForecast>>,
        $FutureProvider<List<UsageForecast>> {
  /// Every forecast row the user can see, cached to disk (G4).
  ///
  /// The per-line provider above is a live read for one screen; this one exists
  /// because the home-screen widget needs the whole set, and needs it to survive
  /// a cold offline start — the countdown it renders on a plane comes from here.
  ///
  /// Cached rather than fetched-or-nothing: a forecast is regenerated nightly and
  /// is about validity windows measured in weeks, so yesterday's copy is a good
  /// answer and a blank widget is not.
  UsageForecastsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usageForecastsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usageForecastsHash();

  @$internal
  @override
  $FutureProviderElement<List<UsageForecast>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UsageForecast>> create(Ref ref) {
    return usageForecasts(ref);
  }
}

String _$usageForecastsHash() => r'd0947edd2e6282a0eee9e53717dd0080259ceada';
