import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo_state.freezed.dart';

@freezed
abstract class GeoState with _$GeoState {
  const factory GeoState({
    required String currentCountry,
    required String currentIsoCode,
    @Default(false) bool travelModeEnabled,
    @Default(false) bool promptFreeze,
    @Default(false) bool promptResume,
    @Default([]) List<String> logs,
    @Default(false) bool isProcessing,
  }) = _GeoState;
}
