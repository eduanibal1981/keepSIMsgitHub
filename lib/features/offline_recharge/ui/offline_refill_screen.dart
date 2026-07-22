import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/offline_recharge/controller/offline_refill_controller.dart';
import 'package:keep_sims/features/offline_recharge/model/offline_refill_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keep_sims/core/services/biometric_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DARK PALETTE
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const ink = Color(0xFF0B1622);
  static const surface = Color(0xFF101E30);
  static const surface2 = Color(0xFF182A42);
  static const surface3 = Color(0xFF1F3450);
  static const hairline = Color(0xFF26374F);
  static const signal = Color(0xFF34D399);
  static const signalDim = Color(0x2434D399);
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
  double letterSpacing = 0,
}) =>
    GoogleFonts.ibmPlexSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

TextStyle _mono({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = _C.paper,
  double letterSpacing = 0.01,
}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

enum _RefillStatus { ready, noFunds, unregistered }

/// A resolved offline channel: everything the card needs to render + launch.
class _Channel {
  final String key; // OfflineChannel.*
  final IconData icon;
  final String title;
  final String subtitle;
  final String number; // display contact number from system_configs
  final double fee; // per-channel message fee, USD
  final String actionLabel;
  final Future<bool> Function() launch;

  const _Channel({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.number,
    required this.fee,
    required this.actionLabel,
    required this.launch,
  });
}

class OfflineRefillScreen extends ConsumerStatefulWidget {
  final String? simLineId;
  final bool autoShowSelector;
  const OfflineRefillScreen({
    super.key,
    this.simLineId,
    this.autoShowSelector = false,
  });

  @override
  ConsumerState<OfflineRefillScreen> createState() =>
      _OfflineRefillScreenState();
}

class _OfflineRefillScreenState extends ConsumerState<OfflineRefillScreen>
    with WidgetsBindingObserver {
  String? _selectedSimLineId;
  bool _needsToShowSelector = false;
  String? _copiedValue;
  // One cooldown for the whole line: the server rate-limits instant refills per
  // SIM line (10s), so a second trigger on any channel within the window would
  // be rejected. Disable all three buttons together.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _selectedSimLineId = widget.simLineId;
    _needsToShowSelector = widget.autoShowSelector;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reconcile the pending queue against the server when the user returns —
    // they were just in WhatsApp / the dialer, and the refill may have landed.
    if (state == AppLifecycleState.resumed) {
      ref
          .read(pendingOfflineRefillsControllerProvider.notifier)
          .refresh();
    }
  }

  // ── Launch helpers ───────────────────────────────────────────────────────
  Future<bool> _open(Uri uri, {bool external = false}) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(
          uri,
          mode: external
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      }
    } catch (_) {/* fall through */}
    return false;
  }

  Future<bool> _launchDialer(String number) =>
      _open(Uri(scheme: 'tel', path: _dialable(number)));

  Future<bool> _launchUssd(String code) =>
      // `#` is a URI fragment delimiter — encode it so the whole code dials.
      _open(Uri.parse('tel:${code.replaceAll('#', '%23')}'));

  Future<bool> _launchSms(String number, String body) => _open(
        Uri(
          scheme: 'sms',
          path: _dialable(number),
          queryParameters: {'body': body},
        ),
      );

  Future<bool> _launchWhatsApp(String number, String text) => _open(
        Uri.parse(
          'https://wa.me/${number.replaceAll(RegExp(r'[^\d]'), '')}'
          '?text=${Uri.encodeComponent(text)}',
        ),
        external: true,
      );

  String _dialable(String n) => n.replaceAll(RegExp(r'[^\d+]'), '');

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    setState(() => _copiedValue = value);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copiedValue = null);
    });
  }

  void _startCooldown() {
    setState(() => _cooldown = 12);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown = _cooldown > 0 ? _cooldown - 1 : 0;
        if (_cooldown == 0) t.cancel();
      });
    });
  }

  // ── Trigger a channel: persist BEFORE launching, then launch ─────────────
  Future<void> _trigger(_Channel channel, SimLine line, double amount) async {
    if (_cooldown > 0) return;

    final authGuard = ref.read(paymentAuthGuardProvider);
    final authResult = await authGuard.confirmPayment(
      reason: 'Authenticate to confirm offline refill request',
    );
    if (authResult == BiometricResult.cancelled ||
        authResult == BiometricResult.failed ||
        authResult == BiometricResult.lockedOut) {
      return;
    }

    final notifier = ref.read(pendingOfflineRefillsControllerProvider.notifier);

    PendingOfflineRefill? pending;
    try {
      pending = await notifier.enqueue(
        channel: channel.key,
        simLineId: line.id,
        phoneNumber: line.phoneNumber,
        amount: amount,
      );
    } catch (_) {/* persistence is best-effort; still let them launch */}

    HapticFeedback.mediumImpact();
    final launched = await channel.launch();
    if (!launched && pending != null) {
      await notifier.markFailed(pending, 'launch_failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(channel.title)),
        );
      }
    }
    _startCooldown();
  }

  // ── Line selection persists as the offline target line ───────────────────
  void _selectLine(String lineId) {
    setState(() => _selectedSimLineId = lineId);
    // The server resolves an offline refill to settings.target_sim_line_id, so
    // picking a line here (while online) is what makes an offline message/call
    // top up THIS line. Best-effort — offline it caches and syncs later.
    final current = ref.read(offlineRefillControllerProvider).value;
    final base = current ?? const OfflineRefillSettings(userId: '');
    if (base.targetSimLineId == lineId && base.isEnabled) return;
    ref.read(offlineRefillControllerProvider.notifier).saveSettings(
          base.copyWith(isEnabled: true, targetSimLineId: lineId),
        );
  }

  PendingOfflineRefill? _latestFor(
    List<PendingOfflineRefill> pendings,
    String lineId,
    String channelKey,
  ) {
    final matches = pendings
        .where((p) => p.simLineId == lineId && p.channel == channelKey)
        .toList()
      ..sort((a, b) => b.launchedAt.compareTo(a.launchedAt));
    return matches.isEmpty ? null : matches.first;
  }

  String _carrierLabel(String? carrierId) {
    if (carrierId == null) return 'Carrier';
    final cid = carrierId.toLowerCase();
    if (cid.contains('ooredoo')) return 'Ooredoo';
    if (cid.contains('omantel')) return 'Omantel';
    if (cid.contains('vodafone')) return 'Vodafone';
    if (cid.contains('orange')) return 'Orange';
    if (cid.contains('stc')) return 'STC';
    if (cid.contains('etisalat')) return 'Etisalat';
    return 'Carrier';
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final simLines = ref.watch(simLinesControllerProvider).value ?? [];
    final walletBalance =
        ref.watch(walletControllerProvider).value?.wallet.balance ?? 0.00;
    final pendings =
        ref.watch(pendingOfflineRefillsControllerProvider).value ?? [];
    final settings = ref.watch(offlineRefillControllerProvider).value;

    if (_selectedSimLineId == null && simLines.isNotEmpty) {
      _selectedSimLineId = simLines.first.id;
    }

    if (_needsToShowSelector && simLines.isNotEmpty) {
      _needsToShowSelector = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSimSelector(simLines);
      });
    }

    final SimLine? activeSim = simLines.isEmpty
        ? null
        : simLines.firstWhere(
            (s) => s.id == _selectedSimLineId,
            orElse: () => simLines.first,
          );

    // Carrier (for its default refill amount) — cached for offline (C3b-3).
    Carrier? activeCarrier;
    if (activeSim?.carrierId != null) {
      final carriers = ref
              .watch(carriersForCountryProvider(activeSim!.countryId ?? ''))
              .value ??
          const <Carrier>[];
      if (carriers.isNotEmpty) {
        activeCarrier = carriers.cast<Carrier?>().firstWhere(
              (c) => c!.id == activeSim.carrierId,
              orElse: () => carriers.first,
            );
      }
    }

    final refillAmount = activeCarrier?.defaultRefillAmount ??
        settings?.defaultRefillAmount ??
        5.00;

    final status = _computeStatus(
      hasSimLine: activeSim != null,
      walletBalance: walletBalance,
      refillAmount: refillAmount,
    );

    // Contact numbers + per-channel fees, both cached so they survive offline.
    final waNumber = ref
            .watch(offlineContactNumberProvider(
                'OFFLINE_WHATSAPP_NUMBER', '+968 24 555 0113'))
            .value ??
        '+968 24 555 0113';
    final smsNumber = ref
            .watch(offlineContactNumberProvider(
                'OFFLINE_SMS_NUMBER', '+968 24 555 0112'))
            .value ??
        '+968 24 555 0112';
    final callNumber = ref
            .watch(offlineContactNumberProvider(
                'OFFLINE_IVR_NUMBER', '+968 24 555 0111'))
            .value ??
        '+968 24 555 0111';
    final waFee = ref
            .watch(offlineMessageFeeUsdProvider(
                'OFFLINE_WHATSAPP_MESSAGE_FEE_USD', 0.05))
            .value ??
        0.05;
    final smsFee = ref
            .watch(offlineMessageFeeUsdProvider(
                'OFFLINE_SMS_MESSAGE_FEE_USD', 0.03))
            .value ??
        0.03;
    final callFee = ref
            .watch(offlineMessageFeeUsdProvider(
                'OFFLINE_MISSED_CALL_FEE_USD', 0.02))
            .value ??
        0.02;

    final amountStr = refillAmount.toStringAsFixed(0);
    final channels = <_Channel>[
      _Channel(
        key: OfflineChannel.whatsapp,
        icon: Icons.forum_outlined,
        title: l.offlineRefillWaTitle,
        subtitle: l.offlineRefillWaSubtitle,
        number: waNumber,
        fee: waFee,
        actionLabel: l.offlineRefillWaAction,
        launch: () => _launchWhatsApp(waNumber, 'REFILL $amountStr'),
      ),
      _Channel(
        key: OfflineChannel.sms,
        icon: Icons.chat_bubble_outline_rounded,
        title: l.offlineRefillSmsTitle,
        subtitle: l.offlineRefillSmsSubtitle,
        number: smsNumber,
        fee: smsFee,
        actionLabel: l.offlineRefillSmsAction,
        launch: () => _launchSms(smsNumber, 'REFILL $amountStr'),
      ),
      _Channel(
        key: OfflineChannel.missedCall,
        icon: Icons.phone_in_talk_outlined,
        title: l.offlineRefillMissedCallTitle,
        subtitle: l.offlineRefillMissedCallSubtitle,
        number: callNumber,
        fee: callFee,
        actionLabel: l.offlineRefillCallAction,
        launch: () => _launchDialer(callNumber),
      ),
    ];

    final ussdAsync = activeSim?.carrierId != null
        ? ref.watch(carrierUssdSuggestionsProvider(activeSim!.carrierId!))
        : null;
    final ussd = ussdAsync?.value ?? const <CarrierUssdSuggestion>[];

    return Scaffold(
      backgroundColor: _C.ink,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(l),
                  const SizedBox(height: 18),
                  _buildStatusBanner(
                    status: status,
                    phoneDisplay: activeSim?.phoneNumber ?? '',
                    carrierLabel: _carrierLabel(activeSim?.carrierId),
                    walletBalance: walletBalance,
                    simLines: simLines,
                    l: l,
                  ),
                  const SizedBox(height: 14),
                  _buildSummary(refillAmount, status, l),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      l.offlineRefillChannelsHeader.toUpperCase(),
                      style: _sans(
                        size: 11,
                        weight: FontWeight.w600,
                        color: _C.fogDim,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final channel in channels) ...[
                    _buildChannelCard(
                      channel: channel,
                      status: status,
                      pending: activeSim == null
                          ? null
                          : _latestFor(pendings, activeSim.id, channel.key),
                      line: activeSim,
                      amount: refillAmount,
                      l: l,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (ussd.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildUssdSection(ussd, l),
                  ],
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      l.offlineRefillDisclaimer,
                      textAlign: TextAlign.center,
                      style: _sans(size: 11, color: _C.fogDim, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _RefillStatus _computeStatus({
    required bool hasSimLine,
    required double walletBalance,
    required double refillAmount,
  }) {
    if (!hasSimLine) return _RefillStatus.unregistered;
    if (walletBalance < refillAmount) return _RefillStatus.noFunds;
    return _RefillStatus.ready;
  }

  // ─── TOP BAR ───────────────────────────────────────────────────────────
  Widget _buildTopBar(AppLocalizations l) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.hairline),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: _C.fog),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.offlineRefillTitle,
                style: _sans(
                    size: 19, weight: FontWeight.w700, letterSpacing: -0.2),
              ),
              const SizedBox(height: 1),
              Text(l.offlineRefillSubtitle,
                  style: _sans(size: 12.5, color: _C.fog)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STATUS BANNER ─────────────────────────────────────────────────────
  Widget _buildStatusBanner({
    required _RefillStatus status,
    required String phoneDisplay,
    required String carrierLabel,
    required double walletBalance,
    required List<SimLine> simLines,
    required AppLocalizations l,
  }) {
    Color bg, borderColor, dotColor;
    String title, subtitle;

    switch (status) {
      case _RefillStatus.ready:
        bg = _C.signalDim;
        borderColor = _C.signal.withValues(alpha: 0.35);
        dotColor = _C.signal;
        title = l.offlineRefillLinked(phoneDisplay);
        subtitle = l.offlineRefillWalletInfo(
            carrierLabel, '\$${walletBalance.toStringAsFixed(2)}');
      case _RefillStatus.noFunds:
        bg = _C.amberDim;
        borderColor = _C.amber.withValues(alpha: 0.35);
        dotColor = _C.amber;
        title = l.offlineRefillNoFunds;
        subtitle = l.offlineRefillNoFundsSub(
            phoneDisplay, '\$${walletBalance.toStringAsFixed(2)}');
      case _RefillStatus.unregistered:
        bg = _C.dangerDim;
        borderColor = _C.danger.withValues(alpha: 0.35);
        dotColor = _C.danger;
        title = l.offlineRefillNotLinked;
        subtitle = l.offlineRefillNotLinkedSub;
    }

    final canSwitch = simLines.length > 1;
    return GestureDetector(
      onTap: canSwitch ? () => _showSimSelector(simLines) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _sans(size: 13.5, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _sans(size: 12, color: _C.fog)),
                ],
              ),
            ),
            if (canSwitch)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Text(l.change,
                    style: _sans(size: 11.5, weight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── SUMMARY ───────────────────────────────────────────────────────────
  Widget _buildSummary(
      double amount, _RefillStatus status, AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(-0.6, -1.0),
          radius: 1.4,
          colors: [Color(0xFF16273D), _C.surface],
          stops: [0.0, 0.7],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.hairline),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 19, color: _C.signal),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.offlineRefillTopUpFromWallet('\$${amount.toStringAsFixed(2)}'),
                  style: _sans(size: 13.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(l.offlineRefillWalletFunded,
                    style: _sans(size: 11.5, color: _C.fog)),
              ],
            ),
          ),
          if (status == _RefillStatus.noFunds)
            GestureDetector(
              onTap: () => context.go('/wallet'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l.offlineRefillAddFunds,
                  style: _sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: const Color(0xFF3A2405)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── CHANNEL CARD ──────────────────────────────────────────────────────
  Widget _buildChannelCard({
    required _Channel channel,
    required _RefillStatus status,
    required PendingOfflineRefill? pending,
    required SimLine? line,
    required double amount,
    required AppLocalizations l,
  }) {
    final enabled = status == _RefillStatus.ready && line != null;
    final onCooldown = _cooldown > 0;
    final feeStr = '\$${channel.fee.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(channel.icon, size: 18, color: _C.signal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.title,
                        style: _sans(size: 14, weight: FontWeight.w600)),
                    Text(channel.subtitle,
                        style: _sans(size: 11.5, color: _C.fog)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _C.hairline),
                ),
                child: Text(l.offlineRefillServiceFee(feeStr),
                    style: _mono(size: 10.5, color: _C.fog)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Number row (copyable)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _C.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(channel.number, style: _mono(size: 14.5))),
                GestureDetector(
                  onTap: () => _copy(_dialable(channel.number)),
                  child: Icon(
                    _copiedValue == _dialable(channel.number)
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 15,
                    color: _copiedValue == _dialable(channel.number)
                        ? _C.signal
                        : _C.fog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // Action button
          GestureDetector(
            onTap: (enabled && !onCooldown)
                ? () => _trigger(channel, line, amount)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: (enabled && !onCooldown) ? _C.signal : _C.surface3,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(channel.icon,
                      size: 16,
                      color: (enabled && !onCooldown)
                          ? const Color(0xFF06251A)
                          : _C.fogDim),
                  const SizedBox(width: 8),
                  Text(
                    onCooldown
                        ? l.offlineRefillWaitSeconds(_cooldown)
                        : channel.actionLabel,
                    style: _sans(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: (enabled && !onCooldown)
                          ? const Color(0xFF06251A)
                          : _C.fogDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pending != null) ...[
            const SizedBox(height: 10),
            _buildStatusRow(pending, channel, line, amount, l),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    PendingOfflineRefill pending,
    _Channel channel,
    SimLine? line,
    double amount,
    AppLocalizations l,
  ) {
    late Color color;
    late IconData icon;
    late String label;
    var showRetry = false;

    switch (pending.status) {
      case PendingRefillStatus.sent:
        color = _C.fog;
        icon = Icons.schedule_rounded;
        label = l.offlineRefillStatusSent;
      case PendingRefillStatus.processing:
        color = _C.amber;
        icon = Icons.sync_rounded;
        label = l.offlineRefillStatusProcessing;
      case PendingRefillStatus.confirmed:
        color = _C.signal;
        icon = Icons.check_circle_rounded;
        label = l.offlineRefillStatusConfirmed;
      case PendingRefillStatus.failed:
        color = _C.danger;
        icon = Icons.error_outline_rounded;
        label = l.offlineRefillStatusFailed;
        showRetry = true;
      case PendingRefillStatus.timedOut:
        color = _C.danger;
        icon = Icons.timer_off_outlined;
        label = l.offlineRefillStatusTimedOut;
        showRetry = true;
      default:
        color = _C.fog;
        icon = Icons.schedule_rounded;
        label = l.offlineRefillStatusSent;
    }

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: _sans(size: 12, weight: FontWeight.w600, color: color)),
        ),
        if (showRetry && line != null && _cooldown == 0)
          GestureDetector(
            onTap: () => _trigger(channel, line, amount),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _C.hairline),
              ),
              child: Text(l.offlineRefillRetry,
                  style: _sans(size: 11.5, weight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  // ─── USSD SUGGESTIONS ──────────────────────────────────────────────────
  Widget _buildUssdSection(
      List<CarrierUssdSuggestion> ussd, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 16, color: _C.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.offlineRefillUssdTitle,
                    style: _sans(size: 13.5, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(l.offlineRefillUssdSubtitle,
              style: _sans(size: 11.5, color: _C.fog, height: 1.4)),
          const SizedBox(height: 12),
          for (var i = 0; i < ussd.length; i++) ...[
            _buildUssdRow(ussd[i], l),
            if (i < ussd.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildUssdRow(CarrierUssdSuggestion s, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.planName,
                    style: _sans(size: 12.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(s.ussdCode,
                        style: _mono(size: 11.5, color: _C.signal)),
                    Text('  ·  \$${s.cost.toStringAsFixed(2)}',
                        style: _mono(size: 11.5, color: _C.fogDim)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _launchUssd(s.ussdCode),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _C.surface3,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _C.hairline),
              ),
              child: Text(l.offlineRefillUssdDial,
                  style: _sans(size: 12, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SIM SELECTOR ──────────────────────────────────────────────────────
  void _showSimSelector(List<SimLine> simLines) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: _C.hairline, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _C.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(l.offlineRefillSelectNumber,
                  style: _sans(
                      size: 17, weight: FontWeight.w700, color: _C.paper)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: simLines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final line = simLines[index];
                    final isSelected = line.id == _selectedSimLineId;
                    return GestureDetector(
                      onTap: () {
                        _selectLine(line.id);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? _C.signalDim : _C.surface2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _C.signal.withValues(alpha: 0.4)
                                : _C.hairline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _C.surface3,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sim_card_rounded,
                                  color: _C.fog, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.nickname ?? line.phoneNumber,
                                      style: _sans(
                                          size: 14, weight: FontWeight.w600)),
                                  if (line.nickname != null)
                                    Text(line.phoneNumber,
                                        style:
                                            _mono(size: 12, color: _C.fog)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: _C.signal, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
