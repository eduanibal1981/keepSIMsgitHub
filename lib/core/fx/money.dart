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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';

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
    final formatted =
        NumberFormat.decimalPatternDigits(decimalDigits: digits).format(local);

    return '≈ ${_symbolPrefix(fx.symbol)}$formatted';
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
    final fx = ref.watch(fxControllerProvider).asData?.value;
    if (fx == null) return const SizedBox.shrink();

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
