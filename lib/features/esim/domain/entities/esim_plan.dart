import 'esim_catalogue_details.dart';
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
    @Default(false) bool isUnlimited,
    Map<String, dynamic>? catalogueDetails,
    String? description,
    String? imageUrl,
  }) = _EsimPlan;

  factory EsimPlan.fromJson(Map<String, dynamic> json) =>
      _$EsimPlanFromJson(json);

  EsimCatalogueDetails get facts =>
      EsimCatalogueDetails(catalogueDetails ?? const {});
  String get formattedDuration => facts.durationLabel(durationDays);

  double? get pricePerGb {
    if (isUnlimited || facts.isDaily || dataAmountMB <= 0) return null;
    final gb = facts.allowanceBytes != null
        ? facts.allowanceBytes! / 1073741824.0
        : dataAmountMB / 1024.0;
    if (gb <= 0) return null;
    return priceUsd / gb;
  }

  /// Shares one formatter with the comparison list so a card that says "10 GB"
  /// cannot become "9.8 GB" on the checkout sheet the user taps through to.
  /// See [CompareOffer.formatDataMb] for why 1 GB is 1000 MB here.
  String get formattedData =>
      catalogueDetails != null || providerName == 'esimaccess'
      ? facts.formattedData(legacyMb: dataAmountMB, unlimited: isUnlimited)
      : isUnlimited
      ? 'Unlimited'
      : dataAmountMB > 0
      ? CompareOffer.formatDataMb(dataAmountMB)
      : 'Not provided';
}
