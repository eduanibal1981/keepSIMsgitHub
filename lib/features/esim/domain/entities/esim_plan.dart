import 'package:freezed_annotation/freezed_annotation.dart';

part 'esim_plan.freezed.dart';
part 'esim_plan.g.dart';

@freezed
abstract class EsimPlan with _$EsimPlan {
  const factory EsimPlan({
    required String id,
    required String name,
    required int dataAmountMB,
    required int durationDays,
    required double priceUsd,
    required String providerName,
    @Default([]) List<String> supportedCountries,
    String? description,
  }) = _EsimPlan;

  factory EsimPlan.fromJson(Map<String, dynamic> json) => _$EsimPlanFromJson(json);
}
