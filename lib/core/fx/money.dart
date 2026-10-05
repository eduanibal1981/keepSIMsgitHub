/// SIM Shield — money rendering (G11)
///
/// The whole product prices in USD and always will. This file adds a *second*,
/// clearly approximate line in the user's own currency, because an expat
/// reading "$12.50" has to do the arithmetic themselves before they can decide.
///
/// ── The rule every call site follows ──────────────────────────────────────
///
/// The dollar figure stays primary and stays visible. The local figure is
/// secondary, always prefixed `≈`, and never appears alone next to a control
/// that commits money — a "Confirm & Pay" button reads `$12.50`, full stop.
/// The user is charged dollars; if the only number on the button were `E£634`
/// then their card statement would disagree with the app, and they would be
/// right to call that a bug.
///
/// There is no local→USD direction here on purpose. See [FxContext].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class Money {
  const Money._();

  /// The canonical figure. This is what the user is actually charged.
  static String usd(double amount) => '\$${amount.toStringAsFixed(2)}';

  /// The approximate equivalent in the user's currency, or null when there is
  /// nothing worth adding — USD display, a stale rate, or the feature off.
  /// Callers render nothing at all when this is null; they must not fall back
  /// to a bare number, which would read as a second, contradictory price.
  static String? approxLocal(double usdAmount, FxContext fx) {
    if (!fx.convertsMoney) return null;

    final local = usdAmount * fx.rate;

    // Cents on an estimate are false precision: `≈ E£634` is honest, and
    // `≈ E£633.67` invites someone to reconcile it against a receipt. Below
    // 100 units the minor part still carries meaning, so keep it.
    final digits = local.abs() >= 100 ? 0 : fx.decimalDigits;
    final formatted = NumberFormat.decimalPatternDigits(
      decimalDigits: digits,
    ).format(local);

    return '≈ ${_symbolPrefix(fx.symbol)}$formatted';
  }

  /// Display-only precision for rates and small running cost estimates.
  /// A positive amount smaller than the precision limit is never shown as free.
  static String? approxLocalRate(
    double usdAmount,
    FxContext fx, {
    String unit = '',
    int? minDigits,
    int? maxDigits,
  }) {
    if (!fx.convertsMoney || !usdAmount.isFinite || usdAmount < 0) return null;
    final maximum = maxDigits ?? (unit == '/min' ? 4 : 5);
    final minimum = minDigits ?? fx.decimalDigits;
    if (maximum < 0 || maximum > 6 || minimum < 0 || minimum > maximum) {
      throw ArgumentError('Rate precision must satisfy 0 <= min <= max <= 6');
    }
    final local = usdAmount * fx.rate;
    if (!local.isFinite) return null;
    final prefix = _symbolPrefix(fx.symbol);
    if (usdAmount == 0) return '≈ ${prefix}0$unit';

    final threshold = 1 / math.pow(10, maximum);
    // Check the positive USD source too, in case multiplication underflows.
    if (local < threshold) {
      final formatted = NumberFormat.decimalPatternDigits(
        decimalDigits: maximum,
      ).format(threshold);
      return '≈ < $prefix$formatted$unit';
    }
    var digits = minimum;
    if (local < 0.1) {
      var shifted = local;
      var leadingPlaces = 0;
      while (shifted < 1 && leadingPlaces < maximum) {
        shifted *= 10;
        leadingPlaces++;
      }
      digits = math.max(minimum, math.min(leadingPlaces + 1, maximum));
    }
    final formatted = NumberFormat.decimalPatternDigits(
      decimalDigits: digits,
    ).format(local);
    return '≈ $prefix$formatted$unit';
  }

  /// Letter-only codes read as words and need a space (`AED 45`, `Rs 1,197`);
  /// true glyphs sit tight against the number (`E£634`, `₹1,197`).
  static String _symbolPrefix(String symbol) =>
      RegExp(r'^[A-Za-z]+$').hasMatch(symbol) ? '$symbol ' : symbol;
}

/// The secondary local line, as a widget, so wiring a screen is one line.
///
/// Renders nothing whenever there is no conversion to show — which means it is
/// safe to drop next to any price without guarding the call site, and means a
/// USD user's layout is byte-for-byte what it was before G11.
class ApproxLocalText extends ConsumerWidget {
  const ApproxLocalText(
    this.usdAmount, {
    super.key,
    this.style,
    this.textAlign,
  });

  final double usdAmount;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.asData?.value` and not `.value`: while the context is loading or has
    // errored there is no conversion to show, and rendering nothing is the
    // correct answer in both cases.
    final state = ref.watch(fxControllerProvider);
    final fx = state.asData?.value;
    if (state.isLoading || state.hasError || fx == null) {
      return const SizedBox.shrink();
    }

    final text = Money.approxLocal(usdAmount, fx);
    if (text == null) return const SizedBox.shrink();

    return Text(
      text,
      textAlign: textAlign,
      style:
          style ??
          TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

/// Secondary rate display; subscribes here so parent widgets need not do so.
class ApproxLocalRateText extends ConsumerWidget {
  const ApproxLocalRateText(
    this.usdAmount, {
    super.key,
    this.unit = '',
    this.minDigits,
    this.maxDigits,
    this.style,
    this.textAlign,
  });

  final double usdAmount;
  final String unit;
  final int? minDigits;
  final int? maxDigits;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fxControllerProvider);
    final fx = state.asData?.value;
    if (state.isLoading || state.hasError || fx == null) {
      return const SizedBox.shrink();
    }
    final text = Money.approxLocalRate(
      usdAmount,
      fx,
      unit: unit,
      minDigits: minDigits,
      maxDigits: maxDigits,
    );
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: textAlign,
      style:
          style ??
          TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

/// USD inputs keep their value; this listens to both typing and preset/MAX edits.
class ApproxLocalAmountPreview extends StatelessWidget {
  const ApproxLocalAmountPreview(this.controller, {super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final amount = double.tryParse(value.text.trim());
          if (amount == null || !amount.isFinite || amount <= 0) {
            return const SizedBox.shrink();
          }
          return ApproxLocalText(amount);
        },
      );
}

/// A render-only explanation beside prices, never a payment amount.
class FxChargeNotice extends ConsumerWidget {
  const FxChargeNotice({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fxControllerProvider);
    final fx = state.asData?.value;
    if (state.isLoading || state.hasError || fx == null || !fx.convertsMoney) {
      return const SizedBox.shrink();
    }
    return Text(
      AppLocalizations.of(context)?.fxChargesInUsd(fx.currency) ??
          '${fx.currency} amounts are approximate. Charges are in USD.',
      style: style ?? Theme.of(context).textTheme.bodySmall,
    );
  }
}
