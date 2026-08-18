import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:keep_sims/features/esim/domain/entities/compare_offer.dart';

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

  /// Shares one formatter with the comparison list so a card that says "10 GB"
  /// cannot become "9.8 GB" on the checkout sheet the user taps through to.
  /// See [CompareOffer.formatDataMb] for why 1 GB is 1000 MB here.
  String get formattedData =>
      dataAmountMB <= 0 ? 'Unlimited' : CompareOffer.formatDataMb(dataAmountMB);
}
