/// KeepSIMs — Free App-to-App Internet Voice Calling Screen (Free Call)
///
/// 100% Free VoIP Audio between KeepSIMs users over data/Wi-Fi.
/// Part of the KeepSIMs Smart Calling ecosystem.
///
/// Features:
/// 1. Realtime contact lookup by phone number
/// 2. Household & family SIM lines directory with registered recipient check
/// 3. One-tap launch to active Free Call screen
/// 4. Honest fallback to paid Smart Call when recipient is not registered
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/data/repositories/voip_calling_repository.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';

class InternetCallingScreen extends ConsumerStatefulWidget {
  const InternetCallingScreen({super.key});

  @override
  ConsumerState<InternetCallingScreen> createState() =>
      _InternetCallingScreenState();
}

class _InternetCallingScreenState extends ConsumerState<InternetCallingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  ContactLookupResult? _matchedUser;
  bool _isSearching = false;
  String? _searchError;
  String? _searchedQuery;
  Timer? _debounceTimer;

  // Track resolving state for specific SIM lines in the household tab
  String? _resolvingLinePhone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
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
        _searchedQuery = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchedQuery = trimmed;
    });

    try {
      final repository = ref.read(voipCallingRepositoryProvider);
      final result = await repository.lookupContactByPhone(trimmed);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _matchedUser = result;
          if (result == null) {
            _searchError = 'No registered KeepSIMs user found for this number.';
          }
        });
      }
    } catch (_) {
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
    HapticHelper.mediumImpact();
    ref.read(voipCallingControllerProvider.notifier).startCall(
          calleeId: userId,
          calleeName: name,
          calleeAvatar: avatar,
          calleePhone: phone,
        );
    context.push(AppRoutes.voipCall);
  }

  Future<void> _handleHouseholdLineTap(SimLine line) async {
    HapticHelper.lightTick();
    final phone = line.phoneNumber.trim();
    if (phone.isEmpty) return;

    setState(() {
      _resolvingLinePhone = phone;
    });

    try {
      final repository = ref.read(voipCallingRepositoryProvider);
      final result = await repository.lookupContactByPhone(phone);

      if (!mounted) return;
      setState(() {
        _resolvingLinePhone = null;
      });

      if (result != null) {
        if (result.isSelf) {
          _showSelfLineDialog(line);
        } else {
          _startCallWithUser(
            userId: result.userId,
            name: result.fullName,
            avatar: result.avatarUrl,
            phone: result.phone,
          );
        }
      } else {
        _showUnregisteredLineSheet(line);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvingLinePhone = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to verify line registration. Check your connection.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSelfLineDialog(SimLine line) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text(
              'Your Account SIM Line',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '${line.phoneNumber} belongs to your own account. Free Call connects between separate KeepSIMs users. Would you like to dial this number via KeepSIMs Smart Call instead?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(
                '${AppRoutes.calling}?number=${Uri.encodeComponent(line.phoneNumber)}',
              );
            },
            child: const Text('Make Smart Call'),
          ),
        ],
      ),
    );
  }

  void _showUnregisteredLineSheet(SimLine line) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_off_outlined,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Not Registered for Free Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line.nickname ?? line.phoneNumber,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${line.phoneNumber} does not have an active KeepSIMs app account. Free Call requires both users to be on the KeepSIMs app over data or Wi-Fi.\n\nYou can reach them over the regular telephone network using KeepSIMs Smart Call.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: AppColors.darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.phone_forwarded, size: 16),
                      label: const Text(
                        'Make Smart Call',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.go(
                          '${AppRoutes.calling}?number=${Uri.encodeComponent(line.phoneNumber)}',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KeepSIMs Smart Calling',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'Free Call (App-to-App)',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
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
                  size: 13,
                ),
                SizedBox(width: 4),
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Intro Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D251C), AppColors.darkCard],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                      ),
                      child: const Icon(
                        Icons.wifi_calling_3_rounded,
                        color: Color(0xFF22C55E),
                        size: 22,
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
                            'Call other KeepSIMs users over Wi-Fi or travel eSIM mobile data with no Smart Call wallet deduction.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Selector (Segmented Bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF22C55E),
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text('Household Lines (${simLines.length})'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('User Search'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHouseholdLinesTab(simLinesState, simLines),
                  _buildUserSearchTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdLinesTab(
    AsyncValue<List<SimLine>> simLinesState,
    List<SimLine> simLines,
  ) {
    if (simLinesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF22C55E),
        ),
      );
    }

    if (simLines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkCard,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(
                  Icons.sim_card_outlined,
                  color: Colors.white38,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Household Lines',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add SIM lines to your account to easily call family members for free.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add SIM Line'),
                onPressed: () => context.go(AppRoutes.simLines),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: simLines.length,
      itemBuilder: (context, index) {
        final line = simLines[index];
        final isResolving = _resolvingLinePhone == line.phoneNumber;
        final countryCode = (line.countryId ?? 'SIM').toUpperCase();

        // Determine SIM type badge only if known
        String? simTypeBadge;
        final iconLower = line.avatarIcon.toLowerCase();
        if (iconLower.contains('esim')) {
          simTypeBadge = 'eSIM';
        } else if (iconLower.contains('physical') || iconLower.contains('plastic')) {
          simTypeBadge = 'Physical SIM';
        }

        final title = line.nickname ?? line.detectedOperatorName ?? line.phoneNumber;

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
              // Avatar with Country ISO or SIM icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  countryCode.length > 3 ? countryCode.substring(0, 3) : countryCode,
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (simTypeBadge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              simTypeBadge,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),
              if (isResolving)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(44, 38),
                  ),
                  icon: const Icon(Icons.phone, size: 15),
                  label: const Text(
                    'Free',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => _handleHouseholdLineTap(line),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search Input Bar
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
                  focusNode: _searchFocusNode,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter phone number (e.g. +968...)',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF22C55E),
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      final pasted = data.text!.trim();
                      _searchController.text = pasted;
                      _onSearchChanged(pasted);
                      _executeSearch(pasted);
                    }
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Matched User State
        if (_matchedUser != null) ...[
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
                        const Row(
                          children: [
                            Text(
                              'Your Account SIM Line',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '(SELF)',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_matchedUser!.phone} belongs to your own account. Free Call connects between separate users. Use Smart Call to dial this phone.',
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
                  ElevatedButton(
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
                    onPressed: () {
                      context.go(
                        '${AppRoutes.calling}?number=${Uri.encodeComponent(_matchedUser!.phone)}',
                      );
                    },
                    child: const Text(
                      'Smart Call',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D251C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.2),
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
                                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'REGISTERED',
                                style: TextStyle(
                                  color: Color(0xFF22C55E),
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
        ] else if (_searchedQuery != null && !_isSearching) ...[
          // Unregistered Fallback / Prompt
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _searchError ?? 'No registered KeepSIMs user found',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_searchedQuery is not registered for free app-to-app calls. You can still reach this number over regular phone networks using KeepSIMs Smart Call.',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.phone_forwarded, size: 16),
                    label: const Text(
                      'Make Smart Call',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      context.go(
                        '${AppRoutes.calling}?number=${Uri.encodeComponent(_searchedQuery!)}',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Search Helper Tip
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.wifi_calling_3_rounded,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Free App-to-App Calling',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter an international phone number above\nto find another registered KeepSIMs user.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
