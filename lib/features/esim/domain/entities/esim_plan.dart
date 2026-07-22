import 'package:freezed_annotation/freezed_annotation.dart';

part 'esim_plan.freezed.dart';
part 'esim_plan.g.dart';

@freezed
abstract class EsimPlan with _$EsimPlan {
  const EsimPlan._();

  const factory EsimPlan({
    required String id,
    required String name,
    required int dataAmountMB,
    required int durationDays,
    required double priceUsd,
    required String providerName,
    @Default([]) List<String> supportedCountries,
    @Default([]) List<String> roamingEnabled,
    String? description,
    String? imageUrl,
  }) = _EsimPlan;

  factory EsimPlan.fromJson(Map<String, dynamic> json) => _$EsimPlanFromJson(json);

  double get pricePerGb {
    if (dataAmountMB <= 0) return 0.0;
    final gb = dataAmountMB / 1024.0;
    return priceUsd / gb;
  }

  String get formattedData {
    if (dataAmountMB <= 0) return 'Unlimited';
    if (dataAmountMB >= 1024) {
      final gb = dataAmountMB / 1024.0;
      return '${gb == gb.roundToDouble() ? gb.toInt() : gb.toStringAsFixed(1)} GB';
    }
    return '$dataAmountMB MB';
  }
}
