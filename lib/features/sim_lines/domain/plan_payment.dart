import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/wallet/model/pending_plan_fee.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
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

  /// Calculates the shortfall deposit needed to fund the wallet for a plan fee.
  /// Enforces minimum deposit of $5.00. Returns 0.0 if available balance covers fee.
  static double calculateShortfall({
    required double fee,
    required double availableBalance,
  }) {
    final diff = fee - availableBalance;
    if (diff <= 0.001) return 0.0;
    return diff < 5.00 ? 5.00 : double.parse(diff.toStringAsFixed(2));
  }

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
  }) => tryPlanFromWallet(ref, simLineId: simLineId);

  /// [tryStandardFromWallet] for any plan.
  ///
  /// Premium goes through the same rail as Standard (J8) rather than being
  /// PayPal-only, for three reasons that are all the reported bug:
  ///
  ///  * the add-line form used to push PayPal with `paymentKind: 'deposit'`
  ///    for Premium and then **skip the debit entirely** — the money landed in
  ///    the wallet, the line was created, and
  ///    `queue_premium_refill_executions` refused it with KS403 because
  ///    nothing had been paid *for the plan*. No Premium line bought on that
  ///    screen had ever been paid for;
  ///  * a wallet debit is a single synchronous round-trip, so the entitlement
  ///    exists before the line is inserted. A `kind: 'plan'` PayPal charge is
  ///    recorded by a webhook that can land *after* checkout reports success —
  ///    see [waitForPlanPayment];
  ///  * the wallet gateway takes 0% + $0.00, so it is also the cheaper rail.
  ///
  /// [rule] is required for Premium: the server prices the year from that
  /// carrier rule, which on a new line is the only handle it has (the line
  /// does not exist yet). It is also what stops a Premium plan being sold for
  /// a carrier the refill queue would refuse — `plan_price_net` raises KS422
  /// for those before any money moves.
  static Future<bool> tryPlanFromWallet(
    WidgetRef ref, {
    String plan = 'standard',
    CarrierRule? rule,
    String? simLineId,
  }) async {
    final isPremium = plan == 'premium';
    if (isPremium && rule == null) {
      throw ArgumentError('A carrier rule is required to price a premium plan.');
    }

    final fee = isPremium
        ? await premiumWalletTotal(ref, rule!)
        : await ref.read(baseServiceFeeUsdProvider.future);
    final cache = ref.read(localCacheServiceProvider);

    // A fee already paid for a line that never got created is spendable now,
    // and replaying its reference id debits nothing. Without this every failure
    // after the debit bills the user again on the next attempt.
    //
    // **Only if it covers this plan.** Since J8 the two tiers cost different
    // amounts, and a replay answers `already_paid` with whatever the ledger
    // holds — so a leftover $2.50 Standard fee would otherwise be adopted as
    // payment for a $9.52 Premium year and the line created for the
    // difference. A cheaper pending fee is left on disk for the tier it was
    // actually charged for, and this purchase pays its own way.
    final stored = PendingPlanFee.fromJson(cache.readJson(_pendingFeeKey));
    final pending = (stored != null && stored.amount + 0.001 >= fee)
        ? stored
        : null;
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
        .payPlanFee(
          simLineId: simLineId,
          referenceId: reference,
          plan: plan,
          carrierRuleId: rule?.id,
        );

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

  /// Blocks until the `plan_payments` row a `kind: 'plan'` PayPal charge
  /// produces is visible, returning false if it never arrives within [timeout].
  ///
  /// **The entitlement is not in place when checkout says "Payment Confirmed".**
  /// That signal is `paypal_orders.status = 'captured'`, and there are two ways
  /// it gets written: `paypal-webhook`'s PAYMENT.CAPTURE.COMPLETED handler,
  /// which inserts the `plan_payments` row *first*, and the client-driven
  /// `capture-paypal-order` fallback, which marks the order captured and writes
  /// no payment row at all — that one only appears when PayPal's webhook lands
  /// afterwards. So on the fallback path a caller that commits immediately asks
  /// `queue_premium_refill_executions` to queue a year of refills for a line
  /// whose payment is not yet recorded, and gets KS403: the same "no paid,
  /// unexpired premium plan" sentence the deposit bug produced, but
  /// intermittent. Same shape as [waitForWalletCredit], same reason.
  ///
  /// Polls Supabase directly rather than a provider: there is no lifecycle to
  /// trip over, and RLS already scopes `plan_payments` to the caller.
  static Future<bool> waitForPlanPayment(
    WidgetRef ref, {
    required DateTime since,
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(milliseconds: 1500),
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final deadline = DateTime.now().add(timeout);

    while (true) {
      try {
        final rows = await client
            .from('plan_payments')
            .select('id')
            .eq('user_id', userId)
            .eq('kind', 'plan')
            .gte('created_at', since.toUtc().toIso8601String())
            .limit(1)
            .timeout(const Duration(seconds: 10));
        if (rows.isNotEmpty) return true;
      } catch (_) {
        // A failed or timed-out read is not a verdict — the deadline is.
      }
      if (DateTime.now().isAfter(deadline)) return false;
      await Future.delayed(interval);
    }
  }

  /// `inapp_pricing` is an override for MANUAL and TASKER_SCRIPT carriers.
  /// For API-fulfilled carriers, pricing is calculated dynamically from live
  /// supplier catalog offers.
  static double? overrideFor(CarrierRule rule, {Carrier? carrier}) {
    if (carrier != null && carrier.fulfillmentGateway == 'API') {
      return null;
    }
    return rule.inappPricing > 0 ? rule.inappPricing : null;
  }

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
  /// The single up-front charge for a year of premium, for display during
  /// build(). Until the gateway row loads it quotes without PayPal's fee
  /// rather than guessing a rate; [premiumYearlyTotal] awaits the real row
  /// before anything is charged.
  static double premiumYearlyTotalSync(
    WidgetRef ref,
    CarrierRule rule, {
    bool isUpgrade = false,
  }) {
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
      isUpgrade: isUpgrade,
    );
  }

  /// The up-front charge for a year of premium when paid via wallet, for
  /// display during build(). Uses 0% + $0.00 gateway fees.
  static double premiumWalletTotalSync(
    WidgetRef ref,
    CarrierRule rule, {
    bool isUpgrade = false,
  }) {
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
      gatewayFeePercentage: 0,
      gatewayFeeFixed: 0,
      inappPricingOverride: overrideFor(rule),
      isUpgrade: isUpgrade,
    );
  }

  /// What a year of Premium costs when it is bought from the wallet.
  ///
  /// The same total as [premiumYearlyTotal] with **no gateway grossing-up**,
  /// because the wallet gateway is 0% + $0.00 — buying from the balance is
  /// genuinely cheaper than buying through PayPal, exactly as it is for
  /// Standard. Mirrors `round(plan_price_net('premium', …), 2)`, which is what
  /// the server actually debits.
  static Future<double> premiumWalletTotal(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
    bool isUpgrade = false,
  }) async {
    final baseFee = await ref.read(baseServiceFeeUsdProvider.future);
    final appFee = await ref.read(appFeePercentProvider.future);
    final margin = await ref.read(premiumMarginPercentProvider.future);
    final marginFlat = await ref.read(premiumMarginPerRefillUsdProvider.future);

    final serverQuote = await fetchQuotedPlanPrice(
      simLineId: simLineId,
      plan: 'premium',
      gateway: 'wallet',
      carrierRuleId: rule.id,
    );
    if (serverQuote != null && serverQuote > 0) {
      return serverQuote;
    }

    return RefillPricing.premiumYearlyTotal(
      baseServiceFeeUsd: baseFee,
      minimumTopupAmount: rule.minimumTopupAmount,
      inactivityLimitDays: rule.inactivityLimitDays,
      refillIntervalDaysOverride: rule.refillIntervalDaysOverride,
      appFeePercent: appFee,
      premiumMarginPercent: margin,
      premiumMarginPerRefillUsd: marginFlat,
      gatewayFeePercentage: 0,
      gatewayFeeFixed: 0,
      inappPricingOverride: overrideFor(rule),
      isUpgrade: isUpgrade,
    );
  }

  /// Authoritative premium yearly total for the charge itself: awaits the
  /// config and gateway rows instead of pricing on cached build() state.
  static Future<double> premiumYearlyTotal(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
    bool isUpgrade = false,
  }) async {
    final serverQuote = await fetchQuotedPlanPrice(
      simLineId: simLineId,
      plan: 'premium',
      gateway: 'paypal',
      carrierRuleId: rule.id,
    );
    if (serverQuote != null && serverQuote > 0) {
      return serverQuote;
    }

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
      isUpgrade: isUpgrade,
    );
  }

  /// Queries the database RPC `quote_plan_price` to fetch the exact, authoritative
  /// server-quoted plan price for a SIM line or carrier rule.
  static Future<double?> fetchQuotedPlanPrice({
    String? simLineId,
    String plan = 'premium',
    String gateway = 'paypal',
    String? carrierRuleId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('quote_plan_price', params: {
        'p_sim_line_id': simLineId,
        'p_plan': plan,
        'p_gateway': gateway,
        'p_carrier_rule_id': carrierRuleId,
      }).timeout(const Duration(seconds: 10));

      if (response != null) {
        return (response as num).toDouble();
      }
    } catch (_) {
      // Fallback to local calculation if offline or RPC fails
    }
    return null;
  }
  /// Queries the database RPC `quote_premium_breakdown` to fetch the itemized quote
  /// ($2.50 annual protection fee + 1st SIM recharge cost = total today).
  static Future<PremiumInitialBreakdown?> fetchPremiumBreakdown({
    String? carrierRuleId,
    String? simLineId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('quote_premium_breakdown', params: {
        'p_carrier_rule_id': carrierRuleId,
        'p_sim_line_id': simLineId,
      }).timeout(const Duration(seconds: 10));

      if (response is Map) {
        final annualFee = (response['annual_fee_usd'] as num?)?.toDouble() ?? 2.50;
        final firstRefill = (response['first_refill_cost_usd'] as num?)?.toDouble() ?? 0.0;
        final total = (response['total_charge_usd'] as num?)?.toDouble() ?? (annualFee + firstRefill);
        final interval = (response['refill_interval_days'] as num?)?.toInt() ?? 30;
        final isUpgrade = response['is_upgrade'] == true;
        final upgradeCredit = (response['upgrade_credit_usd'] as num?)?.toDouble() ?? (isUpgrade ? 2.50 : 0.0);
        final fullAnnualFee = (response['full_annual_fee_usd'] as num?)?.toDouble() ?? 5.00;
        return PremiumInitialBreakdown(
          annualFeeUsd: annualFee,
          firstRefillUsd: firstRefill,
          totalUsd: total,
          refillIntervalDays: interval,
          isUpgrade: isUpgrade,
          upgradeCreditUsd: upgradeCredit,
          fullAnnualFeeUsd: fullAnnualFee,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Calculates synchronous itemized breakdown for build() rendering.
  static PremiumInitialBreakdown premiumBreakdownSync(
    WidgetRef ref,
    CarrierRule rule, {
    bool isUpgrade = false,
  }) {
    return RefillPricing.premiumInitialBreakdown(
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
      inappPricingOverride: overrideFor(rule),
      isUpgrade: isUpgrade,
    );
  }

  /// Creates a SIM setup order tracking the onboarding/upgrade intent and hold requirements.
  static Future<Map<String, dynamic>?> createSimSetupOrder({
    required String phoneNumber,
    required String plan,
    String? carrierRuleId,
    String? countryCode,
    String? carrierCode,
    String? simLineId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('create_sim_setup_order', params: {
        'p_phone_number': phoneNumber,
        'p_plan': plan,
        'p_carrier_rule_id': carrierRuleId,
        'p_country_code': countryCode,
        'p_carrier_code': carrierCode,
        'p_sim_line_id': simLineId,
      }).timeout(const Duration(seconds: 10));
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (_) {}
    return null;
  }

  /// Fetches authoritative server quote for SIM setup (Pay-Per-Refill model + Free eligibility).
  static Future<SimSetupQuote?> fetchSimSetupQuote({
    required String phoneNumber,
    required String plan,
    String? carrierRuleId,
    String? simLineId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('quote_sim_setup', params: {
        'p_phone_number': phoneNumber,
        'p_plan': plan,
        'p_carrier_rule_id': carrierRuleId,
        'p_sim_line_id': simLineId,
      }).timeout(const Duration(seconds: 10));

      if (response is Map) {
        return SimSetupQuote.fromJson(Map<String, dynamic>.from(response));
      }
    } catch (e) {
      // Failed to fetch quote
    }
    return null;
  }

  /// Reserves the dual holds (or single fee hold) in wallet_holds atomically.
  static Future<Map<String, dynamic>> reserveSimSetupHolds(
    String orderId, {
    SupabaseClient? client,
  }) async {
    final response = await (client ?? Supabase.instance.client)
        .rpc('reserve_sim_setup_holds', params: {'p_order_id': orderId})
        .timeout(const Duration(seconds: 10));
    final result = Map<String, dynamic>.from(response as Map);
    // Older servers use code/available_balance; the deposit flow uses
    // error/current_balance. Accept both contracts during rollout.
    if (result['success'] == false && result['code'] == 'insufficient_funds') {
      result['error'] = 'insufficient_balance';
      result['current_balance'] = result['available_balance'];
    }
    return result;
  }

  /// Dispatches the setup verification execution via the topup_executions queue.
  static Future<Map<String, dynamic>> dispatchSimSetupVerification({
    required String orderId,
    required String simLineId,
  }) async {
    final client = Supabase.instance.client;
    final response = await client.rpc('dispatch_sim_setup_verification', params: {
      'p_order_id': orderId,
      'p_sim_line_id': simLineId,
    }).timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }

  /// Finalizes setup order state based on execution delivery and captures holds server-side.
  static Future<Map<String, dynamic>> finalizeSimSetupOrder(
    String orderId, {
    String? simLineId,
  }) async {
    final client = Supabase.instance.client;
    final params = <String, dynamic>{'p_order_id': orderId};
    if (simLineId != null) {
      params['p_sim_line_id'] = simLineId;
    }
    final response = await client.rpc('finalize_sim_setup_order', params: params).timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }

  /// Cancels setup order and releases any active holds.
  static Future<Map<String, dynamic>> cancelSimSetupOrder(
    String orderId, {
    String reason = 'Cancelled by user',
  }) async {
    final client = Supabase.instance.client;
    final response = await client.rpc('cancel_sim_setup_order', params: {
      'p_order_id': orderId,
      'p_reason': reason,
    }).timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }

  /// Atomically falls back a failed setup to 6-month Free ($0) or Standard ($2.50).
  static Future<Map<String, dynamic>> fallbackSimSetupToReminders({
    required String orderId,
    required String simLineId,
    required String fallbackPlan,
  }) async {
    final client = Supabase.instance.client;
    final response = await client.rpc('fallback_sim_setup_to_reminders', params: {
      'p_order_id': orderId,
      'p_sim_line_id': simLineId,
      'p_fallback_plan': fallbackPlan,
    }).timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }
}

/// Unified, server-persisted quote for SIM setup and onboarding.
class SimSetupQuote {
  final String plan;
  final String phoneNumber;
  final double annualFeeUsd;
  final double firstRefillCostUsd;
  final double totalChargeUsd;
  final int refillIntervalDays;
  final bool freeEligible;

  const SimSetupQuote({
    required this.plan,
    required this.phoneNumber,
    required this.annualFeeUsd,
    required this.firstRefillCostUsd,
    required this.totalChargeUsd,
    required this.refillIntervalDays,
    required this.freeEligible,
  });

  factory SimSetupQuote.fromJson(Map<String, dynamic> json) {
    return SimSetupQuote(
      plan: json['plan']?.toString() ?? 'standard',
      phoneNumber: json['phone_number']?.toString() ?? '',
      annualFeeUsd: (json['annual_fee_usd'] as num?)?.toDouble() ?? 2.50,
      firstRefillCostUsd: (json['first_refill_cost_usd'] as num?)?.toDouble() ?? 0.0,
      totalChargeUsd: (json['total_charge_usd'] as num?)?.toDouble() ?? 2.50,
      refillIntervalDays: (json['refill_interval_days'] as num?)?.toInt() ?? 30,
      freeEligible: json['free_eligible'] as bool? ?? true,
    );
  }
}



