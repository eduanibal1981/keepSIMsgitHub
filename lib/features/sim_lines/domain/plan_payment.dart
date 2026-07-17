import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

/// One implementation of "charge the Standard yearly fee", shared by
/// onboarding, the add-line form and the upgrade sheet — the three screens
/// that each used to invent their own plan price (C3c).
///
/// Standard bills **wallet-first** (owner's decision): the wallet gateway
/// costs 0% + $0.00 in `payment_gateways`, while PayPal's $0.49 fixed fee eats
/// 23% of a standalone $2.50 charge. Only when the balance cannot cover the
/// fee does the caller fall back to a PayPal charge, grossed up via
/// [RefillPricing.grossUpTotal] so the fee survives PayPal's cut. PayPal plan
/// charges must be tagged `paymentKind: 'plan'` — tagged 'deposit' they are
/// credited straight back into the payer's wallet by the webhook.
class PlanPayment {
  const PlanPayment._();

  /// What the PayPal fallback bills so exactly the service fee survives
  /// PayPal's percentage + fixed cut.
  static Future<double> standardPayPalTotal(WidgetRef ref) async {
    final fee = await ref.read(baseServiceFeeUsdProvider.future);
    final paypal = await ref.read(paymentGatewayProvider('paypal').future);
    return RefillPricing.grossUpTotal(
      net: fee,
      gatewayFeePercentage: paypal?.feePercentage ?? 0,
      gatewayFeeFixed: paypal?.feeFixed ?? 0,
    );
  }

  /// Attempts the wallet debit; true means the fee is paid in full.
  ///
  /// False means the balance cannot cover it and **nothing was charged** —
  /// the caller should proceed to the PayPal fallback. Other failures throw.
  /// The amount is priced server-side by `pay_plan_fee_from_wallet`; the
  /// balance is only pre-checked here to skip a doomed round-trip.
  static Future<bool> tryStandardFromWallet(
    WidgetRef ref, {
    String? simLineId,
  }) async {
    final fee = await ref.read(baseServiceFeeUsdProvider.future);
    final balance = ref.read(walletControllerProvider).value?.wallet.balance;
    if (balance == null || balance < fee) return false;
    return ref
        .read(walletControllerProvider.notifier)
        .payPlanFee(simLineId: simLineId);
  }

  /// `inapp_pricing` is an override, not the default: the column parses null
  /// to 0, so only a positive value counts as a deliberate per-carrier price.
  static double? overrideFor(CarrierRule rule) =>
      rule.inappPricing > 0 ? rule.inappPricing : null;

  /// What one premium refill costs, before the gateway's cut. Safe to call
  /// during build(); prices from whatever the config providers have loaded.
  static double premiumRefillPriceSync(WidgetRef ref, CarrierRule rule) =>
      RefillPricing.premiumRefillPrice(
        minimumTopupAmount: rule.minimumTopupAmount,
        appFeePercent:
            ref.watch(appFeePercentProvider).value ?? kDefaultAppFeePercent,
        premiumMarginPercent:
            ref.watch(premiumMarginPercentProvider).value ?? 0,
        premiumMarginPerRefillUsd:
            ref.watch(premiumMarginPerRefillUsdProvider).value ?? 0,
        inappPricingOverride: overrideFor(rule),
      );

  /// The single up-front charge for a year of premium, for display during
  /// build(). Until the gateway row loads it quotes without PayPal's fee
  /// rather than guessing a rate; [premiumYearlyTotal] awaits the real row
  /// before anything is charged.
  static double premiumYearlyTotalSync(WidgetRef ref, CarrierRule rule) {
    final paypal = ref.watch(paymentGatewayProvider('paypal')).value;
    return RefillPricing.premiumYearlyTotal(
      baseServiceFeeUsd:
          ref.watch(baseServiceFeeUsdProvider).value ?? kDefaultBaseServiceFeeUsd,
      minimumTopupAmount: rule.minimumTopupAmount,
      topupValidityDays: rule.topupValidityDays,
      appFeePercent:
          ref.watch(appFeePercentProvider).value ?? kDefaultAppFeePercent,
      premiumMarginPercent: ref.watch(premiumMarginPercentProvider).value ?? 0,
      premiumMarginPerRefillUsd:
          ref.watch(premiumMarginPerRefillUsdProvider).value ?? 0,
      gatewayFeePercentage: paypal?.feePercentage ?? 0,
      gatewayFeeFixed: paypal?.feeFixed ?? 0,
      inappPricingOverride: overrideFor(rule),
    );
  }

  /// Authoritative premium yearly total for the charge itself: awaits the
  /// config and gateway rows instead of pricing on cached build() state.
  static Future<double> premiumYearlyTotal(
    WidgetRef ref,
    CarrierRule rule,
  ) async {
    final baseFee = await ref.read(baseServiceFeeUsdProvider.future);
    final appFee = await ref.read(appFeePercentProvider.future);
    final margin = await ref.read(premiumMarginPercentProvider.future);
    final marginFlat = await ref.read(premiumMarginPerRefillUsdProvider.future);
    final paypal = await ref.read(paymentGatewayProvider('paypal').future);

    return RefillPricing.premiumYearlyTotal(
      baseServiceFeeUsd: baseFee,
      minimumTopupAmount: rule.minimumTopupAmount,
      topupValidityDays: rule.topupValidityDays,
      appFeePercent: appFee,
      premiumMarginPercent: margin,
      premiumMarginPerRefillUsd: marginFlat,
      gatewayFeePercentage: paypal?.feePercentage ?? 0,
      gatewayFeeFixed: paypal?.feeFixed ?? 0,
      inappPricingOverride: overrideFor(rule),
    );
  }
}
