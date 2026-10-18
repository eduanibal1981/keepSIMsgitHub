import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/providers.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/features/wallet/model/pending_plan_fee.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_rule_model.dart';
import 'package:keep_sims/features/sim_lines/domain/refill_pricing.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';

/// Cached retail server quotes for display. Errors/missing contracts stay
/// unavailable; checkout always fetches a fresh server quote.
final premiumDisplayQuoteProvider = FutureProvider.autoDispose
    .family<PremiumInitialBreakdown?, ({String ruleId, String? lineId})>((
      ref,
      key,
    ) {
      return PlanPayment.fetchPremiumBreakdown(
        carrierRuleId: key.ruleId,
        simLineId: key.lineId,
      );
    });

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
    final price = await fetchQuotedPlanPrice(
      plan: 'standard',
      gateway: 'paypal',
    );
    if (price == null || !price.isFinite || price < 0) {
      throw StateError(
        'The current plan price is unavailable. Please try again.',
      );
    }
    return price;
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
  /// Premium and Standard use server-priced wallet payment with a durable
  /// receipt. Premium also requires a carrier rule to check refill eligibility.
  /// Future refills remain individually wallet-funded, within the customer's
  /// reviewed authorization ceiling; the annual fee does not prepay a queue.
  static Future<bool> tryPlanFromWallet(
    WidgetRef ref, {
    String plan = 'standard',
    CarrierRule? rule,
    String? simLineId,
  }) async {
    final isPremium = plan == 'premium';
    if (isPremium && rule == null) {
      throw ArgumentError(
        'A carrier rule is required to price a premium plan.',
      );
    }

    final cache = ref.read(localCacheServiceProvider);
    var stored = PendingPlanFee.fromJson(cache.readJson(_pendingFeeKey));
    if (stored != null) {
      final receipt = await Supabase.instance.client.rpc(
        'get_owned_plan_payment_receipt',
        params: {'p_reference_id': stored.referenceId},
      );
      if (receipt is Map) {
        if (receipt['plan'] == plan && receipt['sim_line_id'] == simLineId) {
          return ref
              .read(walletControllerProvider.notifier)
              .payPlanFee(
                simLineId: simLineId,
                referenceId: stored.referenceId,
                plan: plan,
                carrierRuleId: rule?.id,
                expectedAmount: (receipt['amount'] as num).toDouble(),
              );
        }
        stored = null; // A different purchase cannot spend this receipt.
      }
    }
    final fee = isPremium
        ? await premiumWalletTotal(ref, rule!, simLineId: simLineId)
        : await fetchQuotedPlanPrice(
            plan: plan,
            gateway: 'wallet',
            simLineId: simLineId,
          );
    if (fee == null || !fee.isFinite || fee < 0) {
      throw StateError(
        'The current plan price is unavailable. Please try again.',
      );
    }

    // A failed uncollected attempt keeps its reference across a price refresh.
    final pending = stored;
    if (pending == null && fee > 0) {
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
          expectedAmount: fee,
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
        if (result case Success(
          data: final wallet,
        ) when wallet.balance >= atLeast) {
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
  /// Capture fulfillment and webhook retries share the same payment receipt.
  /// Wait for that receipt before activating the line or its schedule. Checkout
  /// confirmation alone is not evidence of an unexpired paid entitlement.
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

  static PremiumInitialBreakdown? premiumBreakdownSync(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
  }) => ref
      .watch(premiumDisplayQuoteProvider((ruleId: rule.id, lineId: simLineId)))
      .value;

  static double? premiumRefillPriceSync(WidgetRef ref, CarrierRule rule) =>
      premiumBreakdownSync(ref, rule)?.firstRefillUsd;

  // The current checkout rail is wallet funded, so this display has no gateway
  // surcharge. The deprecated yearly name remains for existing callers.
  static double? premiumYearlyTotalSync(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
  }) => premiumBreakdownSync(ref, rule, simLineId: simLineId)?.totalUsd;

  static double? premiumWalletTotalSync(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
  }) => premiumYearlyTotalSync(ref, rule, simLineId: simLineId);

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
  }) async {
    final price = await fetchQuotedPlanPrice(
      simLineId: simLineId,
      plan: 'premium',
      gateway: 'wallet',
      carrierRuleId: rule.id,
    );
    if (price == null || !price.isFinite || price < 0) {
      throw StateError(
        'The current plan price is unavailable. Please try again.',
      );
    }
    return price;
  }

  /// Authoritative premium yearly total for the charge itself: awaits the
  /// config and gateway rows instead of pricing on cached build() state.
  static Future<double> premiumYearlyTotal(
    WidgetRef ref,
    CarrierRule rule, {
    String? simLineId,
  }) async {
    final price = await fetchQuotedPlanPrice(
      simLineId: simLineId,
      plan: 'premium',
      gateway: 'paypal',
      carrierRuleId: rule.id,
    );
    if (price == null || !price.isFinite || price < 0) {
      throw StateError(
        'The current plan price is unavailable. Please try again.',
      );
    }
    return price;
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
      final response = await client
          .rpc(
            'quote_plan_price',
            params: {
              'p_sim_line_id': simLineId,
              'p_plan': plan,
              'p_gateway': gateway,
              'p_carrier_rule_id': carrierRuleId,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response != null) {
        return (response as num).toDouble();
      }
    } catch (_) {
      // Checkout callers stop when the authoritative price is unavailable.
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
      final response = await client
          .rpc(
            'quote_premium_breakdown',
            params: {
              'p_carrier_rule_id': carrierRuleId,
              'p_sim_line_id': simLineId,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response is Map) {
        return PremiumInitialBreakdown.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
    } catch (_) {}
    return null;
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
      final response = await client
          .rpc(
            'create_sim_setup_order',
            params: {
              'p_phone_number': phoneNumber,
              'p_plan': plan,
              'p_carrier_rule_id': carrierRuleId,
              'p_country_code': countryCode,
              'p_carrier_code': carrierCode,
              'p_sim_line_id': simLineId,
            },
          )
          .timeout(const Duration(seconds: 10));
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
      final response = await client
          .rpc(
            'quote_sim_setup',
            params: {
              'p_phone_number': phoneNumber,
              'p_plan': plan,
              'p_carrier_rule_id': carrierRuleId,
              'p_sim_line_id': simLineId,
            },
          )
          .timeout(const Duration(seconds: 10));

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
    final response = await client
        .rpc(
          'dispatch_sim_setup_verification',
          params: {'p_order_id': orderId, 'p_sim_line_id': simLineId},
        )
        .timeout(const Duration(seconds: 10));
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
    final response = await client
        .rpc('finalize_sim_setup_order', params: params)
        .timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }

  /// Cancels setup order and releases any active holds.
  static Future<Map<String, dynamic>> cancelSimSetupOrder(
    String orderId, {
    String reason = 'Cancelled by user',
  }) async {
    final client = Supabase.instance.client;
    final response = await client
        .rpc(
          'cancel_sim_setup_order',
          params: {'p_order_id': orderId, 'p_reason': reason},
        )
        .timeout(const Duration(seconds: 10));
    return Map<String, dynamic>.from(response as Map);
  }

  /// Atomically falls back a failed setup to 6-month Free ($0) or Standard ($2.50).
  static Future<Map<String, dynamic>> fallbackSimSetupToReminders({
    required String orderId,
    required String simLineId,
    required String fallbackPlan,
  }) async {
    final client = Supabase.instance.client;
    final response = await client
        .rpc(
          'fallback_sim_setup_to_reminders',
          params: {
            'p_order_id': orderId,
            'p_sim_line_id': simLineId,
            'p_fallback_plan': fallbackPlan,
          },
        )
        .timeout(const Duration(seconds: 10));
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
      firstRefillCostUsd:
          (json['first_refill_cost_usd'] as num?)?.toDouble() ?? 0.0,
      totalChargeUsd: (json['total_charge_usd'] as num?)?.toDouble() ?? 2.50,
      refillIntervalDays: (json['refill_interval_days'] as num?)?.toInt() ?? 30,
      freeEligible: json['free_eligible'] as bool? ?? true,
    );
  }
}
