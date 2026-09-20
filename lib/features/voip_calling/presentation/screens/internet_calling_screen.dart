/// KeepSIMs — Free App-to-App Internet Voice Calling Screen
///
/// 100% Free VoIP Audio (WhatsApp-style) between KeepSIMs users over data/Wi-Fi.
/// Features:
/// 1. Realtime contact lookup by phone number
/// 2. Household & family SIM lines quick-call directory
/// 3. One-tap launch to WhatsApp-style active call screen
/// 4. Integrated CallKit / Lockscreen test simulator
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/presentation/widgets/calling_mode_switcher.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

class InternetCallingScreen extends ConsumerStatefulWidget {
  const InternetCallingScreen({super.key});

  @override
  ConsumerState<InternetCallingScreen> createState() =>
      _InternetCallingScreenState();
}

class _InternetCallingScreenState extends ConsumerState<InternetCallingScreen> {
  final TextEditingController _searchController = TextEditingController();
  ContactLookupResult? _matchedUser;
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounceTimer;

  // Simulator state
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.length < 6) {
      setState(() {
        _matchedUser = null;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final repository = ref.read(voipCallingRepositoryProvider);
      final result = await repository.lookupContactByPhone(query);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _matchedUser = result;
          if (result == null) {
            _searchError = 'No registered KeepSIMs user found for this number.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = 'Search failed. Check your internet connection.';
        });
      }
    }
  }

  void _startCallWithUser({
    required String userId,
    required String name,
    String? avatar,
    String? phone,
  }) {
    ref
        .read(voipCallingControllerProvider.notifier)
        .startCall(
          calleeId: userId,
          calleeName: name,
          calleeAvatar: avatar,
          calleePhone: phone,
        );
    context.push(AppRoutes.voipCall);
  }

  void _triggerSimulatedIncomingCall() {
    setState(() => _countdown = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _countdown = 0);

        final callkit = VoipCallkitService();
        await callkit.showIncomingCall(
          callId: 'mock-call-${DateTime.now().millisecondsSinceEpoch}',
          callerName: 'Sarah Connor (KeepSIMs)',
          callerPhone: '+1 555-0199',
        );
      }
    });
  }

  void _previewActiveCallUI() {
    final activeCall = ref.read(voipCallingControllerProvider);
    if (!activeCall.isActive) {
      ref
          .read(voipCallingControllerProvider.notifier)
          .startDebugCall(peerName: 'Sarah Connor', peerPhone: '+1 555-0199');
    }
    context.push(AppRoutes.voipCall);
  }

  @override
  Widget build(BuildContext context) {
    final simLinesState = ref.watch(simLinesControllerProvider);
    final simLines = simLinesState.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: const Text(
          'KeepSIMs Internet Calling',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.voicemail_rounded, color: Colors.purpleAccent, size: 20),
            tooltip: 'AI Voicemail',
            onPressed: () => context.push(AppRoutes.voicemail),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, color: Colors.tealAccent, size: 20),
            tooltip: 'Audio & SIP Test',
            onPressed: () => context.push(AppRoutes.sipDiagnostics),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_calling_3_rounded,
                  color: Color(0xFF22C55E),
                  size: 14,
                ),
                SizedBox(width: 5),
                Text(
                  '100% FREE',
                  style: TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Bar
            const CallingModeSwitcher(activeMode: CallingMode.internet),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // Promotional / Explanatory Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF102820), AppColors.darkCard],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.18),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: Color(0xFF22C55E),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Free Internet Audio Calls',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Call any online KeepSIMs user anywhere in the world over data or Wi-Fi (WhatsApp Style). 0¢ per minute.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Search For Users By Phone Number ──
                  const Text(
                    'Search KeepSIMs User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter phone number (e.g. +968...)',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: _executeSearch,
                          ),
                        ),
                        if (_isSearching)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                      ],
                    ),
                  ),

                  // Search Result Card
                  if (_matchedUser != null) ...[
                    const SizedBox(height: 12),
                    if (_matchedUser!.isSelf)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.person_pin_rounded,
                                color: Colors.amber,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Your Account SIM Line',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'SELF',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_matchedUser!.phone} belongs to your own account. Internet calling connects between separate users. Use Phone Calls to dial this phone.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.phone_forwarded, size: 14),
                              label: const Text(
                                'Dial PSTN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              onPressed: () {
                                context.push(AppRoutes.calling);
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF102820),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.2),
                              backgroundImage: _matchedUser!.avatarUrl != null
                                  ? NetworkImage(_matchedUser!.avatarUrl!)
                                  : null,
                              child: _matchedUser!.avatarUrl == null
                                  ? Text(
                                      _matchedUser!.fullName.isNotEmpty
                                          ? _matchedUser!.fullName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _matchedUser!.fullName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _matchedUser!.isOnline
                                              ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                              : Colors.white12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _matchedUser!.isOnline ? 'ONLINE' : 'REGISTERED',
                                          style: TextStyle(
                                            color: _matchedUser!.isOnline
                                                ? const Color(0xFF22C55E)
                                                : Colors.white70,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _matchedUser!.phone,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.phone, size: 16),
                              label: const Text(
                                'Free Call',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () => _startCallWithUser(
                                userId: _matchedUser!.userId,
                                name: _matchedUser!.fullName,
                                avatar: _matchedUser!.avatarUrl,
                                phone: _matchedUser!.phone,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _searchError!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.phone, size: 14),
                            label: const Text(
                              'Call via PSTN',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => context.push(AppRoutes.calling),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Family Lines & Household Directory ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Account & Family Lines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${simLines.length} lines',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (simLines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No SIM lines added yet. Add a SIM line to call family members.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ...simLines.map((line) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: const Icon(
                                Icons.sim_card_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.nickname ?? line.phoneNumber,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    line.phoneNumber,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.18),
                                foregroundColor: const Color(0xFF22C55E),
                              ),
                              icon: const Icon(Icons.phone, size: 18),
                              tooltip: 'Call via Internet',
                              onPressed: () {
                                _searchController.text = line.phoneNumber;
                                _executeSearch(line.phoneNumber);
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // ── Lockscreen CallKit & Simulation Workbench (Debug Only) ──
                  if (kDebugMode)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.science_rounded,
                              color: AppColors.tertiary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Test CallKit & Lockscreen Ringing',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Test native phone ringing when locked, without needing a second physical device.',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _countdown > 0
                                      ? Colors.amberAccent
                                      : Colors.white70,
                                  side: BorderSide(
                                    color: _countdown > 0
                                        ? Colors.amberAccent
                                        : Colors.white24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.phone_callback_rounded,
                                  size: 16,
                                  color: _countdown > 0
                                      ? Colors.amberAccent
                                      : AppColors.secondary,
                                ),
                                label: Text(
                                  _countdown > 0
                                      ? 'Ringing in $_countdown...'
                                      : 'Simulate Incoming Call (3s)',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: _countdown > 0
                                    ? null
                                    : _triggerSimulatedIncomingCall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                size: 20,
                              ),
                              tooltip: 'Preview Call UI',
                              onPressed: _previewActiveCallUI,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
