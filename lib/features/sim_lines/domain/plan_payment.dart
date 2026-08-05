import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/wallet/model/pending_plan_fee.dart';
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
  ///
  /// That pre-check reads the **repository**, never
  /// `walletControllerProvider.value`. `ref.invalidate` merely *schedules* a
  /// rebuild, so a `.value` read taken straight after a refresh still returns
  /// the pre-refresh balance. Right after a PayPal top-up that reads as $0.00,
  /// the fee is silently skipped, and the caller is told the wallet could not
  /// cover a balance that had in fact already arrived.
  static Future<bool> tryStandardFromWallet(
    WidgetRef ref, {
    String? simLineId,
  }) async {
    final fee = await ref.read(baseServiceFeeUsdProvider.future);
    final cache = ref.read(localCacheServiceProvider);

    // A fee already paid for a line that never got created is spendable now,
    // and replaying its reference id debits nothing. Without this every failure
    // after the debit bills the user again on the next attempt.
    final pending = PendingPlanFee.fromJson(cache.readJson(_pendingFeeKey));
    if (pending == null) {
      final result = await ref
          .read(walletRepositoryProvider)
          .getWallet()
          .timeout(const Duration(seconds: 10));
      switch (result) {
        case Success(data: final wallet):
          if (wallet.balance < fee) return false;
        case Failure():
          return false;
      }
    }

    // Recorded *before* the charge: a crash between the debit landing and the
    // response arriving must still leave the reference recoverable.
    final reference =
        pending?.referenceId ??
        'planfee_${DateTime.now().microsecondsSinceEpoch}';
    await cache.writeJson(
      _pendingFeeKey,
      PendingPlanFee(
        referenceId: reference,
        amount: fee,
        chargedAt: pending?.chargedAt ?? DateTime.now(),
      ).toJson(),
    );

    final paid = await ref
        .read(walletControllerProvider.notifier)
        .payPlanFee(simLineId: simLineId, referenceId: reference);

    // Not paid means not charged, so nothing is owed and nothing is held.
    if (!paid) await cache.remove(_pendingFeeKey);
    return paid;
  }

  static const String _pendingFeeKey = 'pending_plan_fee';

  /// Called once the SIM line the fee bought actually exists. Until this runs,
  /// the next attempt reuses the same reference and is not billed again.
  static Future<void> consumePendingFee(WidgetRef ref) =>
      ref.read(localCacheServiceProvider).remove(_pendingFeeKey);

  /// Blocks until a just-completed PayPal top-up has actually reached the
  /// wallet, returning false if it never does within [timeout].
  ///
  /// Checkout reports success off `paypal_orders.status = 'captured'`, which
  /// the CHECKOUT.ORDER.APPROVED webhook writes. The wallet is credited by a
  /// *different, later* webhook — PAYMENT.CAPTURE.COMPLETED — so at the moment
  /// the user sees "Payment Confirmed" the balance is still the old one. A
  /// caller that charges the wallet right then reads the stale balance, decides
  /// it cannot afford the fee and skips the charge; an 11-second gap between
  /// the two has been observed in production.
  ///
  /// This polls the **repository**, not `walletControllerProvider`. Reading
  /// `provider.future` in a loop deadlocks: `payPlanFee` calls
  /// `invalidateSelf()` on the same provider, and a `.future` awaited across an
  /// invalidation can be left waiting on a build that was superseded and will
  /// never complete — which hung the form on an un-cancellable spinner. A plain
  /// repository read has no provider lifecycle to trip over. The caller
  /// refreshes the provider once afterwards.
  ///
  /// Every round is bounded so a stalled socket cannot outlive [timeout].
  static Future<bool> waitForWalletCredit(
    WidgetRef ref, {
    required double atLeast,
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(milliseconds: 1500),
  }) async {
    final repo = ref.read(walletRepositoryProvider);
    final deadline = DateTime.now().add(timeout);

    while (true) {
      try {
        final result = await repo.getWallet().timeout(
          const Duration(seconds: 10),
        );
        if (result case Success(data: final wallet)
            when wallet.balance >= atLeast) {
          // Deliberately does *not* invalidate the controller here. Invalidating
          // disposes its state, and `payPlanFee` opens with a `state.value` null
          // check that returns false — so refreshing right before the charge can
          // itself cancel the charge. `payPlanFee` calls `invalidateSelf()` once
          // the debit lands, which is the right moment for the UI to catch up.
          return true;
        }
      } catch (_) {
        // A failed or timed-out read is not a verdict — the deadline is.
      }
      if (DateTime.now().isAfter(deadline)) return false;
      await Future.delayed(interval);
    }
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
      inactivityLimitDays: rule.inactivityLimitDays,
      refillIntervalDaysOverride: rule.refillIntervalDaysOverride,
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
      inactivityLimitDays: rule.inactivityLimitDays,
      refillIntervalDaysOverride: rule.refillIntervalDaysOverride,
      appFeePercent: appFee,
      premiumMarginPercent: margin,
      premiumMarginPerRefillUsd: marginFlat,
      gatewayFeePercentage: paypal?.feePercentage ?? 0,
      gatewayFeeFixed: paypal?.feeFixed ?? 0,
      inappPricingOverride: overrideFor(rule),
    );
  }
}
