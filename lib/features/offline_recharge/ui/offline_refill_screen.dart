import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keep_sims/core/providers/app_config_provider.dart';
import 'package:keep_sims/features/sim_lines/data/models/carrier_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/wallet/controller/wallet_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DARK PALETTE (matches HTML reference CSS variables)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const ink = Color(0xFF0B1622);
  static const surface = Color(0xFF101E30);
  static const surface2 = Color(0xFF182A42);
  static const surface3 = Color(0xFF1F3450);
  static const hairline = Color(0xFF26374F);
  static const signal = Color(0xFF34D399);
  static const signalDim = Color(0x2434D399); // ~14%
  static const amber = Color(0xFFF5A954);
  static const amberDim = Color(0x24F5A954);
  static const danger = Color(0xFFF2545B);
  static const dangerDim = Color(0x24F2545B);
  static const fog = Color(0xFF8FA1B8);
  static const fogDim = Color(0xFF5C7089);
  static const paper = Color(0xFFEEF2F6);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES (IBM Plex Sans / Mono feel via Google Fonts)
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// STATUS ENUM
// ─────────────────────────────────────────────────────────────────────────────
enum _RefillStatus { ready, noFunds, unregistered }

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
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
    with TickerProviderStateMixin {
  String? _selectedSimLineId;
  bool _showTimeline = false;
  int _timelineStep = 0; // 0=none, 1=ringing, 2=detected, 3=sent
  bool _copied = false;
  String? _expandedMethod;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  bool _needsToShowSelector = false;

  // Pulse animation
  late final AnimationController _pulseController;

  // Timeline step animation
  Timer? _timelineTimer;

  @override
  void initState() {
    super.initState();
    _selectedSimLineId = widget.simLineId;
    _needsToShowSelector = widget.autoShowSelector;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timelineTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  // ── Determine status from real data ──────────────────────────────────
  _RefillStatus _computeStatus({
    required bool hasSimLine,
    required double walletBalance,
    required double refillAmount,
  }) {
    if (!hasSimLine) return _RefillStatus.unregistered;
    if (walletBalance < refillAmount) return _RefillStatus.noFunds;
    return _RefillStatus.ready;
  }

  // ── Copy gateway number ──────────────────────────────────────────────
  void _copyNumber(String number) {
    Clipboard.setData(ClipboardData(text: number));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  // ── Launch phone dialer ──────────────────────────────────────────────
  Future<void> _launchDialer(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── Launch SMS ───────────────────────────────────────────────────────
  Future<void> _launchSms(String phoneNumber, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── Launch WhatsApp ──────────────────────────────────────────────────
  Future<void> _launchWhatsApp(String phoneNumber, String text) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Start call simulation + Supabase realtime listener ───────────────
  void _triggerCall(String gatewayNumber, String userPhone) {
    setState(() {
      _showTimeline = true;
      _timelineStep = 1;
    });
    HapticFeedback.mediumImpact();

    // Start realtime listener for refill events
    _startRealtimeListener(userPhone);

    // Launch dialer
    _launchDialer(gatewayNumber);

    // Fallback simulation if no realtime events arrive within 12s
    _timelineTimer?.cancel();
    _timelineTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _timelineStep < 3) {
        _advanceTimeline();
      }
    });
  }

  void _startRealtimeListener(String userPhone) {
    _realtimeSub?.cancel();
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSub = supabase
        .from('refill_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
          // Check for completed events matching this user
          final matching = data.where(
            (r) =>
                r['status'] == 'completed' ||
                r['status'] == 'processing' ||
                r['status'] == 'detected',
          );
          if (matching.isNotEmpty) {
            _advanceTimeline();
          }
        });
  }

  void _advanceTimeline() {
    if (!mounted) return;
    if (_timelineStep >= 3) return;

    setState(() => _timelineStep = _timelineStep + 1);

    if (_timelineStep < 3) {
      _timelineTimer?.cancel();
      _timelineTimer = Timer(const Duration(seconds: 2), () {
        _advanceTimeline();
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  // ── Toggle accordion ────────────────────────────────────────────────
  void _toggleMethod(String method) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedMethod = _expandedMethod == method ? null : method;
    });
  }

  String _getCarrierLabel(String? carrierId) {
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

  // ── Show SIM selector bottom sheet ──────────────────────────────────
  void _showSimSelector(List<dynamic> simLines) {
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
            border: Border(
              top: BorderSide(color: _C.hairline, width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _C.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.selectTargetSimLine,
                style: _sans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: _C.paper,
                ),
              ),
              const SizedBox(height: 16),
              if (simLines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    AppLocalizations.of(context)!.noRegisteredSimLines,
                    style: _sans(size: 13, color: _C.fog),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: simLines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final line = simLines[index];
                      final isSelected = line.id == _selectedSimLineId;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedSimLineId = line.id);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? _C.signalDim : _C.surface2,
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
                                child: const Icon(
                                  Icons.sim_card_rounded,
                                  color: _C.fog,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.nickname ?? line.phoneNumber,
                                      style: _sans(
                                        size: 14,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    if (line.nickname != null)
                                      Text(
                                        line.phoneNumber,
                                        style: _mono(
                                          size: 12,
                                          color: _C.fog,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _C.signal,
                                  size: 20,
                                ),
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

  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final simLinesState = ref.watch(simLinesControllerProvider);
    final walletState = ref.watch(walletControllerProvider);
    final l = AppLocalizations.of(context)!;

    final simLines = simLinesState.value ?? [];
    final walletBalance = walletState.value?.wallet.balance ?? 0.00;

    // Auto-select first SIM if none chosen
    if (_selectedSimLineId == null && simLines.isNotEmpty) {
      _selectedSimLineId = simLines.first.id;
    }

    if (_needsToShowSelector && simLines.isNotEmpty) {
      _needsToShowSelector = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSimSelector(simLines);
      });
    }

    // Find active SIM
    final activeSim = simLines.isEmpty
        ? null
        : simLines.firstWhere(
            (l) => l.id == _selectedSimLineId,
            orElse: () => simLines.first,
          );

    // Fetch carrier for refill amount + gateway number
    final carrierAsync = activeSim?.carrierId != null
        ? ref.watch(carriersForCountryProvider(activeSim!.countryId ?? ''))
        : null;

    Carrier? activeCarrier;
    if (carrierAsync != null && carrierAsync.hasValue) {
      final carriers = carrierAsync.value ?? [];
      activeCarrier = carriers.isEmpty
          ? null
          : carriers.cast<Carrier?>().firstWhere(
                (c) => c!.id == activeSim!.carrierId,
                orElse: () => carriers.first,
              );
    }

    final refillAmount = activeCarrier?.defaultRefillAmount ?? 5.00;
    final gatewayNumber =
        activeCarrier?.gatewayPhoneNumber ?? '+968 24 555 0110';
    final gatewayNumberClean = gatewayNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Contact numbers from system_configs (C3c), cached locally so the last
    // good value survives being offline — which is when this screen matters.
    final ivrNumber = ref
            .watch(
              offlineContactNumberProvider(
                'OFFLINE_IVR_NUMBER',
                '+968 24 555 0111',
              ),
            )
            .value ??
        '+968 24 555 0111';
    final smsNumber = ref
            .watch(
              offlineContactNumberProvider(
                'OFFLINE_SMS_NUMBER',
                '+968 24 555 0112',
              ),
            )
            .value ??
        '+968 24 555 0112';
    final waNumber = ref
            .watch(
              offlineContactNumberProvider(
                'OFFLINE_WHATSAPP_NUMBER',
                '+968 24 555 0113',
              ),
            )
            .value ??
        '+968 24 555 0113';
    String dialable(String n) => n.replaceAll(RegExp(r'[^\d+]'), '');

    final status = _computeStatus(
      hasSimLine: activeSim != null,
      walletBalance: walletBalance,
      refillAmount: refillAmount,
    );

    final carrierLabel = _getCarrierLabel(activeSim?.carrierId);
    final phoneDisplay = activeSim?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: _C.ink,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TOP BAR ──────────────────────────────────
                  _buildTopBar(l),
                  const SizedBox(height: 18),

                  // ── STATUS BANNER ────────────────────────────
                  _buildStatusBanner(
                    status: status,
                    phoneDisplay: phoneDisplay,
                    carrierLabel: carrierLabel,
                    walletBalance: walletBalance,
                    simLines: simLines,
                    l: l,
                  ),
                  const SizedBox(height: 14),

                  // ── HERO CARD ────────────────────────────────
                  _buildHeroCard(
                    status: status,
                    gatewayNumber: gatewayNumber,
                    gatewayNumberClean: gatewayNumberClean,
                    refillAmount: refillAmount,
                    phoneDisplay: phoneDisplay,
                    l: l,
                  ),
                  const SizedBox(height: 22),

                  // ── OTHER WAYS IN ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      l.offlineRefillOtherWays.toUpperCase(),
                      style: _sans(
                        size: 11,
                        weight: FontWeight.w600,
                        color: _C.fogDim,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildMethodCard(
                    method: 'ivr',
                    icon: Icons.smartphone_rounded,
                    title: l.offlineRefillIvrTitle,
                    subtitle: l.offlineRefillIvrSubtitle,
                    cost: l.offlineRefillIvrCost,
                    number: ivrNumber,
                    actionLabel: l.offlineRefillCallThisNumber,
                    // Dial exactly the displayed number — the old hardcoded
                    // dial string was missing its final digit.
                    onAction: () => _launchDialer(dialable(ivrNumber)),
                  ),
                  const SizedBox(height: 8),

                  _buildMethodCard(
                    method: 'sms',
                    icon: Icons.chat_bubble_outline_rounded,
                    title: l.offlineRefillSmsTitle,
                    subtitle: l.offlineRefillSmsSubtitle,
                    cost: l.offlineRefillSmsCost,
                    number: smsNumber,
                    actionLabel: l.offlineRefillSmsAction,
                    onAction: () => _launchSms(
                      dialable(smsNumber),
                      'REFILL ${refillAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildMethodCard(
                    method: 'wa',
                    icon: Icons.forum_outlined,
                    title: l.offlineRefillWaTitle,
                    subtitle: l.offlineRefillWaSubtitle,
                    cost: l.offlineRefillWaCost,
                    number: waNumber,
                    actionLabel: l.offlineRefillWaAction,
                    onAction: () =>
                        _launchWhatsApp(dialable(waNumber), 'REFILL'),
                  ),
                  const SizedBox(height: 22),

                  // ── DISCLAIMER ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      l.offlineRefillDisclaimer,
                      textAlign: TextAlign.center,
                      style: _sans(
                        size: 11,
                        color: _C.fogDim,
                        height: 1.6,
                      ),
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

  // ─── TOP BAR ─────────────────────────────────────────────────────────
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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: _C.fog,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.offlineRefillTitle,
              style: _sans(
                size: 19,
                weight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              l.offlineRefillSubtitle,
              style: _sans(size: 12.5, color: _C.fog),
            ),
          ],
        ),
      ],
    );
  }

  // ─── STATUS BANNER ───────────────────────────────────────────────────
  Widget _buildStatusBanner({
    required _RefillStatus status,
    required String phoneDisplay,
    required String carrierLabel,
    required double walletBalance,
    required List<dynamic> simLines,
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
          carrierLabel,
          '\$${walletBalance.toStringAsFixed(2)}',
        );
      case _RefillStatus.noFunds:
        bg = _C.amberDim;
        borderColor = _C.amber.withValues(alpha: 0.35);
        dotColor = _C.amber;
        title = l.offlineRefillNoFunds;
        subtitle = l.offlineRefillNoFundsSub(
          phoneDisplay,
          '\$${walletBalance.toStringAsFixed(2)}',
        );
      case _RefillStatus.unregistered:
        bg = _C.dangerDim;
        borderColor = _C.danger.withValues(alpha: 0.35);
        dotColor = _C.danger;
        title = l.offlineRefillNotLinked;
        subtitle = l.offlineRefillNotLinkedSub;
    }

    return GestureDetector(
      onTap: simLines.length > 1
          ? () => _showSimSelector(simLines)
          : null,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _sans(size: 13.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: _sans(size: 12, color: _C.fog)),
                ],
              ),
            ),
            if (simLines.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  l.change,
                  style: _sans(
                    size: 11.5,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── HERO CARD ───────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required _RefillStatus status,
    required String gatewayNumber,
    required String gatewayNumberClean,
    required double refillAmount,
    required String phoneDisplay,
    required AppLocalizations l,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(-0.6, -1.0),
          radius: 1.4,
          colors: [Color(0xFF16273D), _C.surface],
          stops: [0.0, 0.55],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          _buildEyebrow(status, l),
          const SizedBox(height: 14),

          // Pulse ring stage
          _buildPulseStage(status),
          const SizedBox(height: 6),

          // Number row
          _buildNumberRow(gatewayNumber, gatewayNumberClean, l),
          const SizedBox(height: 14),

          // Refill tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.offlineRefillAddsToNumber,
                style: _sans(size: 12.5, color: _C.fog),
              ),
              Text(
                '+\$${refillAmount.toStringAsFixed(2)}',
                style: _mono(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: _C.paper,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // CTA Button
          _buildCtaButton(
            status: status,
            gatewayNumberClean: gatewayNumberClean,
            phoneDisplay: phoneDisplay,
            l: l,
          ),

          // Fine print
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Text(
              _finePrint(status, l),
              textAlign: TextAlign.center,
              style: _sans(size: 11.5, color: _C.fog, height: 1.5),
            ),
          ),

          // Timeline
          if (_showTimeline) ...[
            const SizedBox(height: 16),
            _buildTimeline(gatewayNumber, phoneDisplay, refillAmount, l),
          ],
        ],
      ),
    );
  }

  // ─── EYEBROW BADGE ──────────────────────────────────────────────────
  Widget _buildEyebrow(_RefillStatus status, AppLocalizations l) {
    final isReady = status == _RefillStatus.ready;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isReady ? _C.signalDim : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isReady
              ? _C.signal.withValues(alpha: 0.3)
              : _C.hairline,
        ),
      ),
      child: Text(
        switch (status) {
          _RefillStatus.ready => l.offlineRefillFastest,
          _RefillStatus.noFunds => l.offlineRefillNeedsFunds,
          _RefillStatus.unregistered => l.offlineRefillNotSetUp,
        },
        style: _sans(
          size: 11,
          weight: FontWeight.w600,
          color: isReady ? _C.signal : _C.fog,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─── PULSE RING ANIMATION ───────────────────────────────────────────
  Widget _buildPulseStage(_RefillStatus status) {
    final isReady = status == _RefillStatus.ready;
    final isAnimating = _showTimeline && _timelineStep < 3;
    final isDone = _timelineStep >= 3;

    return SizedBox(
      height: 128,
      child: Center(
        child: SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse rings
              if (isReady || isAnimating)
                for (int i = 0; i < 3; i++)
                  _AnimatedPulseRing(
                    controller: _pulseController,
                    delay: i * 0.33,
                    isAnimating: isAnimating,
                    color: _C.signal,
                  ),

              // Phone badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? _C.signal
                      : isAnimating
                          ? _C.signal
                          : _C.surface3,
                  border: Border.all(color: _C.hairline),
                ),
                child: Icon(
                  Icons.phone_rounded,
                  size: 24,
                  color: isDone
                      ? _C.ink
                      : isAnimating
                          ? _C.paper
                          : _C.signal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── GATEWAY NUMBER ROW ─────────────────────────────────────────────
  Widget _buildNumberRow(
    String displayNumber,
    String cleanNumber,
    AppLocalizations l,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayNumber,
              style: _mono(size: 19, weight: FontWeight.w500),
            ),
          ),
          if (_copied)
            Text(
              l.offlineRefillCopied,
              style: _sans(
                size: 10.5,
                weight: FontWeight.w600,
                color: _C.signal,
              ),
            )
          else
            GestureDetector(
              onTap: () => _copyNumber(cleanNumber),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _C.hairline),
                ),
                child: const Icon(Icons.copy_rounded, size: 15, color: _C.fog),
              ),
            ),
        ],
      ),
    );
  }

  // ─── CTA BUTTON ─────────────────────────────────────────────────────
  Widget _buildCtaButton({
    required _RefillStatus status,
    required String gatewayNumberClean,
    required String phoneDisplay,
    required AppLocalizations l,
  }) {
    Color bg;
    Color textColor;
    String label;
    VoidCallback? onTap;

    switch (status) {
      case _RefillStatus.ready:
        bg = _C.signal;
        textColor = const Color(0xFF06251A);
        label = l.offlineRefillCallToTrigger;
        onTap = () => _triggerCall(gatewayNumberClean, phoneDisplay);
      case _RefillStatus.noFunds:
        bg = _C.amber;
        textColor = const Color(0xFF3A2405);
        label = l.offlineRefillAddFunds;
        onTap = () => context.go('/wallet');
      case _RefillStatus.unregistered:
        bg = _C.danger;
        textColor = const Color(0xFF2E0407);
        label = l.offlineRefillLinkFirst;
        onTap = null; // disabled
    }

    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isDisabled ? _C.surface3 : bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_rounded,
              size: 17,
              color: isDisabled ? _C.fogDim : textColor,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: _sans(
                size: 15,
                weight: FontWeight.w700,
                color: isDisabled ? _C.fogDim : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _finePrint(_RefillStatus status, AppLocalizations l) {
    return switch (status) {
      _RefillStatus.ready => l.offlineRefillFinePrintReady,
      _RefillStatus.noFunds => l.offlineRefillFinePrintNoFunds,
      _RefillStatus.unregistered => l.offlineRefillFinePrintUnreg,
    };
  }

  // ─── TIMELINE ───────────────────────────────────────────────────────
  Widget _buildTimeline(
    String gatewayNumber,
    String phoneDisplay,
    double refillAmount,
    AppLocalizations l,
  ) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.hairline)),
      ),
      child: Column(
        children: [
          _buildTimelineStep(
            index: 1,
            label: l.offlineRefillTimelineRinging(gatewayNumber),
            time: _timelineStep >= 2 ? l.offlineRefillJustNow : null,
          ),
          _buildTimelineStep(
            index: 2,
            label: l.offlineRefillTimelineDetected(phoneDisplay),
            time: _timelineStep >= 3 ? l.offlineRefillJustNow : null,
          ),
          _buildTimelineStep(
            index: 3,
            label: l.offlineRefillTimelineSent(
              '\$${refillAmount.toStringAsFixed(2)}',
              phoneDisplay,
            ),
            time: _timelineStep >= 3 ? l.offlineRefillJustNow : null,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required int index,
    required String label,
    String? time,
    bool isLast = false,
  }) {
    final isDone = _timelineStep > index;
    final isActive = _timelineStep == index;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node + line
          SizedBox(
            width: 19,
            child: Column(
              children: [
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? _C.signal : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? _C.signal
                          : isActive
                              ? _C.signal
                              : _C.fogDim,
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Color(0xFF06251A),
                        )
                      : isActive
                          ? const _SpinnerWidget()
                          : null,
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 28,
                    color: _C.hairline,
                    margin: const EdgeInsets.only(top: 4),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: (isActive || isDone) ? _C.paper : _C.fog,
                  ),
                ),
                if (time != null)
                  Text(time, style: _mono(size: 11.5, color: _C.fogDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── METHOD ACCORDION CARD ──────────────────────────────────────────
  Widget _buildMethodCard({
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
    required String cost,
    required String number,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final isOpen = _expandedMethod == method;

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => _toggleMethod(method),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _C.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: _C.fog),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              _sans(size: 13.5, weight: FontWeight.w600),
                        ),
                        Text(
                          subtitle,
                          style: _sans(size: 11.5, color: _C.fog),
                        ),
                      ],
                    ),
                  ),
                  Text(cost, style: _mono(size: 11, color: _C.fog)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isOpen ? 0.25 : 0,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _C.fogDim,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _C.surface2,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: _C.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            number,
                            style: _mono(size: 15.5),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _copyNumber(
                            number.replaceAll(RegExp(r'[^\d+]'), ''),
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: _C.fog,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _C.surface3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.hairline),
                      ),
                      child: Text(
                        actionLabel,
                        textAlign: TextAlign.center,
                        style: _sans(
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── ANIMATED PULSE RING WIDGET ──────────────────────────────────────────
class _AnimatedPulseRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final bool isAnimating;
  final Color color;

  const _AnimatedPulseRing({
    required this.controller,
    required this.delay,
    required this.isAnimating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAnimating) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double progress = (controller.value + delay) % 1.0;
        double scale = 1.0 + progress * 1.6;
        double opacity = (1.0 - progress).clamp(0.0, 0.65);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── SPINNER WIDGET ──────────────────────────────────────────────────────
class _SpinnerWidget extends StatefulWidget {
  const _SpinnerWidget();

  @override
  State<_SpinnerWidget> createState() => _SpinnerWidgetState();
}

class _SpinnerWidgetState extends State<_SpinnerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.rotate(
        angle: _ctrl.value * 6.283,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _C.signal, width: 1.5),
            gradient: const SweepGradient(
              colors: [Colors.transparent, _C.signal],
            ),
          ),
        ),
      ),
    );
  }
}
