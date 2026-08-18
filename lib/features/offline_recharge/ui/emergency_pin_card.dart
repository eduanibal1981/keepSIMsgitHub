import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:keep_sims/core/services/biometric_auth_service.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

import '../controller/offline_voucher_controller.dart';
import '../model/offline_voucher_model.dart';

// The offline screen's palette, kept local for the same reason the screen keeps
// its own: this surface is deliberately dark and fixed, because it is read in
// the dark, at low battery, by someone with no connection.
abstract final class _C {
  static const surface = Color(0xFF101E30);
  static const surface2 = Color(0xFF182A42);
  static const surface3 = Color(0xFF1F3450);
  static const hairline = Color(0xFF26374F);
  static const signal = Color(0xFF34D399);
  static const amber = Color(0xFFF5A954);
  static const amberDim = Color(0x24F5A954);
  static const danger = Color(0xFFF2545B);
  static const dangerDim = Color(0x24F2545B);
  static const fog = Color(0xFF8FA1B8);
  static const fogDim = Color(0xFF5C7089);
  static const paper = Color(0xFFEEF2F6);
}

TextStyle _sans({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _C.paper,
  double? height,
}) => GoogleFonts.ibmPlexSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

TextStyle _mono({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = _C.paper,
  double letterSpacing = 0.01,
}) => GoogleFonts.ibmPlexMono(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// The emergency recharge PIN, for premium lines.
///
/// This is the only channel on the offline screen that works with **no
/// connectivity of any kind**. The other three need the SIM to originate a
/// message or a call, and a prepaid line that has run to zero — the exact case
/// this screen exists for — is frequently barred from doing that. A voucher
/// redeemed through the carrier's own USSD works on a barred line.
///
/// It therefore renders top of the list, and it renders from the KEYSTORE, not
/// from the network: `storedVoucherProvider` reads local storage only.
class EmergencyPinCard extends ConsumerWidget {
  const EmergencyPinCard({
    super.key,
    required this.simLineId,
    required this.phoneNumber,
  });

  final String simLineId;
  final String phoneNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final storedAsync = ref.watch(storedVoucherProvider(simLineId));
    final serverState = ref.watch(offlineVoucherStateControllerProvider).value;
    final lineState = serverState?.forLine(simLineId);

    // The feature is off, or this line is not premium: render nothing at all
    // rather than an upsell. The offline screen is opened by someone in
    // trouble; selling to them there is the wrong moment.
    final enabled = serverState?.enabled ?? false;
    final stored = storedAsync.value;
    if (!enabled && stored == null) return const SizedBox.shrink();
    if (stored == null && lineState != null && !lineState.entitled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stored != null && !stored.isRevealed
              ? _C.signal.withValues(alpha: 0.45)
              : _C.hairline,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(l, stored),
          const SizedBox(height: 12),
          ..._body(context, ref, l, stored, lineState),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l, StoredVoucher? stored) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _C.surface2,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            stored != null && !stored.isRevealed
                ? Icons.lock_outline_rounded
                : Icons.password_rounded,
            size: 18,
            color: _C.signal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.voucherCardTitle,
                style: _sans(size: 14, weight: FontWeight.w600),
              ),
              Text(
                l.voucherCardSubtitle,
                style: _sans(size: 11.5, color: _C.fog),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    StoredVoucher? stored,
    VoucherLineState? lineState,
  ) {
    // ── Something is owed ──────────────────────────────────────────────────
    final grant = lineState?.grant;
    if (stored?.isRevealed == true || grant?.isOutstanding == true) {
      final due = grant?.amountDueUsd ?? stored?.amountDueUsd ?? 0;
      final grantId = grant?.id ?? stored?.grantId;
      return [
        _banner(
          color: _C.amber,
          bg: _C.amberDim,
          icon: Icons.receipt_long_outlined,
          title: l.voucherOwedTitle('\$${due.toStringAsFixed(2)}'),
          body: l.voucherOwedBody,
        ),
        const SizedBox(height: 10),
        _primaryButton(
          label: l.voucherSettleAction('\$${due.toStringAsFixed(2)}'),
          icon: Icons.account_balance_wallet_outlined,
          onTap: grantId == null
              ? null
              : () => _settle(context, ref, grantId, due, l),
        ),
        if (stored != null) ...[
          const SizedBox(height: 8),
          _pinPanel(context, l, stored),
        ],
      ];
    }

    // ── A sealed PIN is on the device ──────────────────────────────────────
    if (stored != null) {
      if (stored.isExpired) {
        return [
          _banner(
            color: _C.danger,
            bg: _C.dangerDim,
            icon: Icons.timer_off_outlined,
            title: l.voucherExpiredTitle,
            body: l.voucherExpiredBody,
          ),
        ];
      }
      return [
        Text(
          l.voucherSealedBody('\$${stored.faceValueUsd.toStringAsFixed(2)}'),
          style: _sans(size: 12.5, color: _C.fog, height: 1.45),
        ),
        const SizedBox(height: 10),
        _primaryButton(
          label: l.voucherRevealAction,
          icon: Icons.visibility_outlined,
          onTap: () => _confirmReveal(context, ref, stored, l),
        ),
      ];
    }

    // ── Nothing stored ─────────────────────────────────────────────────────
    if (lineState == null) {
      return [
        Text(l.voucherUnavailableOffline,
            style: _sans(size: 12.5, color: _C.fog, height: 1.45)),
      ];
    }

    if (lineState.awaitingStock) {
      final due = lineState.request?.dueAt;
      return [
        _banner(
          color: _C.fog,
          bg: Colors.white.withValues(alpha: 0.05),
          icon: Icons.hourglass_bottom_rounded,
          title: l.voucherPreparingTitle,
          body: due == null
              ? l.voucherPreparingBody
              : l.voucherPreparingBodyBy(_shortDate(due)),
        ),
      ];
    }

    if (lineState.canProvision) {
      return [
        Text(l.voucherCollectBody,
            style: _sans(size: 12.5, color: _C.fog, height: 1.45)),
        const SizedBox(height: 10),
        _primaryButton(
          label: l.voucherCollectAction,
          icon: Icons.download_rounded,
          onTap: () => _provision(context, ref, l),
        ),
      ];
    }

    return [
      Text(l.voucherPreparingBody,
          style: _sans(size: 12.5, color: _C.fog, height: 1.45)),
    ];
  }

  // ─────────────────────────────────────────────────────────────── actions ──

  Future<void> _provision(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(offlineVoucherStateControllerProvider.notifier)
        .provision(simLineId);

    if (result.isOk) {
      messenger.showSnackBar(SnackBar(content: Text(l.voucherCollectedToast)));
      return;
    }

    final message = switch (result.code) {
      VoucherProvisionCode.settlementDue => l.voucherOwedTitle(
          '\$${(result.amountDueUsd ?? 0).toStringAsFixed(2)}'),
      VoucherProvisionCode.noStock => result.expectedBy == null
          ? l.voucherPreparingBody
          : l.voucherPreparingBodyBy(_shortDate(result.expectedBy!)),
      VoucherProvisionCode.notPremium => l.voucherPremiumOnly,
      VoucherProvisionCode.offline => l.voucherNeedsConnection,
      VoucherProvisionCode.featureOff => l.voucherPreparingBody,
      _ => l.voucherCollectFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// The reveal is a one-way door: it creates a debt, and it happens where we
  /// cannot ask anything. So the confirmation states the price BEFORE the PIN
  /// appears, and the biometric prompt is the same one every other money action
  /// in the app uses.
  Future<void> _confirmReveal(
    BuildContext context,
    WidgetRef ref,
    StoredVoucher stored,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        title: Text(l.voucherRevealConfirmTitle,
            style: _sans(size: 17, weight: FontWeight.w700)),
        content: Text(
          l.voucherRevealConfirmBody(
            '\$${stored.faceValueUsd.toStringAsFixed(2)}',
            '\$${stored.amountDueUsd.toStringAsFixed(2)}',
          ),
          style: _sans(size: 13.5, color: _C.fog, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: _sans(size: 13, color: _C.fog)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.signal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.voucherRevealConfirmAction,
              style: _sans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: const Color(0xFF06251A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final guard = ref.read(paymentAuthGuardProvider);
    final auth = await guard.confirmPayment(
      reason: 'Authenticate to reveal your emergency recharge PIN',
    );
    if (auth == BiometricResult.cancelled ||
        auth == BiometricResult.failed ||
        auth == BiometricResult.lockedOut) {
      return;
    }

    await ref.read(voucherRevealControllerProvider.notifier).reveal(simLineId);
  }

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    String grantId,
    double due,
    AppLocalizations l,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final guard = ref.read(paymentAuthGuardProvider);
    final auth = await guard.confirmPayment(
      reason: 'Authenticate to settle your emergency recharge PIN',
    );
    if (auth == BiometricResult.cancelled ||
        auth == BiometricResult.failed ||
        auth == BiometricResult.lockedOut) {
      return;
    }

    final result = await ref
        .read(offlineVoucherStateControllerProvider.notifier)
        .settle(grantId);

    if (result['success'] == true) {
      messenger.showSnackBar(SnackBar(content: Text(l.voucherSettledToast)));
      return;
    }

    if (result['code'] == 'INSUFFICIENT_FUNDS') {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.voucherSettleNoFunds(
            '\$${due.toStringAsFixed(2)}',
            '\$${((result['balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
          )),
          action: SnackBarAction(
            label: l.offlineRefillAddFunds,
            onPressed: () => context.go('/wallet'),
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(l.voucherSettleFailed)));
  }

  // ───────────────────────────────────────────────────────────────── parts ──

  Widget _pinPanel(
      BuildContext context, AppLocalizations l, StoredVoucher stored) {
    final code = stored.redeemCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.voucherYourPin,
              style: _sans(size: 11, weight: FontWeight.w600, color: _C.fogDim)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  stored.pin,
                  style: _mono(size: 19, weight: FontWeight.w600, letterSpacing: 1.2),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: stored.pin));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.voucherPinCopied)),
                  );
                },
                child: const Icon(Icons.copy_rounded, size: 16, color: _C.fog),
              ),
            ],
          ),
          if (stored.serial != null) ...[
            const SizedBox(height: 4),
            Text('${l.voucherSerial}: ${stored.serial}',
                style: _mono(size: 11, color: _C.fogDim)),
          ],
          const SizedBox(height: 10),
          Text(stored.instructions,
              style: _sans(size: 12, color: _C.fog, height: 1.45)),
          if (code != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              // `#` is a URI fragment delimiter — encode it or the dialer gets
              // a truncated code. Same fix as the USSD suggestions section.
              onTap: () => launchUrl(
                Uri.parse('tel:${code.replaceAll('#', '%23')}'),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _C.surface3,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _C.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dialpad_rounded, size: 15, color: _C.signal),
                    const SizedBox(width: 8),
                    Text(l.voucherDialAction(code),
                        style: _sans(size: 12.5, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _banner({
    required Color color,
    required Color bg,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _sans(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: _sans(size: 11.5, color: _C.fog, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? _C.signal : _C.surface3,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: on ? const Color(0xFF06251A) : _C.fogDim),
            const SizedBox(width: 8),
            Text(
              label,
              style: _sans(
                size: 13.5,
                weight: FontWeight.w700,
                color: on ? const Color(0xFF06251A) : _C.fogDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day}/${local.month}';
  }
}
