/// KeepSIMs — WhatsApp-Style Free Internet Voice Calling Screen (Free Call)
///
/// 100% Free VoIP Audio between KeepSIMs users over Wi-Fi & Mobile Data.
/// Part of the KeepSIMs Smart Calling ecosystem.
///
/// WhatsApp-Inspired Design:
/// 1. Top Search Bar: Search by name or international phone number
/// 2. Invite Call Link Banner: Share invite via WhatsApp, SMS, or link
/// 3. Tab 1: Recent Calls: Incoming, Outgoing, and Missed calls with 1-tap redial
/// 4. Tab 2: Family & Contacts: Linked family accounts with free calling + secondary account SIMs with invite/cellular fallback
/// 5. Honest UX: No calling oneself, no misleading "free" buttons on regular cellular lines
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
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

  static const Color kWhatsAppGreen = Color(0xFF22C55E);

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
    if (trimmed.length < 4) {
      setState(() {
        _matchedUser = null;
        _searchError = null;
        _isSearching = false;
        _searchedQuery = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
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

  void _shareInviteLink([String? targetPhone]) {
    HapticHelper.lightTick();
    final message = targetPhone != null && targetPhone.isNotEmpty
        ? 'Hey! Call me for free with zero roaming charges on KeepSIMs. Download the app here: https://keepsims.com/app'
        : 'Join me on KeepSIMs for 100% free international voice calls over Wi-Fi or data! Download the app: https://keepsims.com/app';

    Share.share(message, subject: 'Call me for free on KeepSIMs');
  }

  String _formatSessionTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return 'Today, ${DateFormat('h:mm a').format(dt)}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFilteringBySearch =
        _searchedQuery != null && _searchController.text.trim().isNotEmpty;

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
              'KeepSIMs Free Call',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'WhatsApp-Style Internet Audio (App-to-App)',
              style: TextStyle(
                color: kWhatsAppGreen,
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
              color: kWhatsAppGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kWhatsAppGreen.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_calling_3_rounded,
                  color: kWhatsAppGreen,
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  '100% FREE',
                  style: TextStyle(
                    color: kWhatsAppGreen,
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
            // Top Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
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
                          hintText: 'Search name or number (+968...)',
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kWhatsAppGreen,
                        ),
                      )
                    else if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
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
                          if (data?.text != null &&
                              data!.text!.trim().isNotEmpty) {
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
            ),

            // If user is actively searching, show search result overlay
            if (isFilteringBySearch)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSearchResultView(),
                  ],
                ),
              )
            else ...[
              // Free Call Link Banner (WhatsApp-Style Create Call Link)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D251C), AppColors.darkCard],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kWhatsAppGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kWhatsAppGreen.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          color: kWhatsAppGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Free Call Link',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Anyone with KeepSIMs can call you free over data or Wi-Fi.',
                              style: TextStyle(
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
                          backgroundColor: kWhatsAppGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _shareInviteLink(),
                      ),
                    ],
                  ),
                ),
              ),

              // Segmented Tab Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: kWhatsAppGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kWhatsAppGreen.withValues(alpha: 0.6),
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: kWhatsAppGreen,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Recent Calls'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_alt_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Family & Contacts'),
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
                    _buildRecentCallsTab(),
                    _buildFamilyAndContactsTab(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultView() {
    if (_matchedUser != null) {
      if (_matchedUser!.isSelf) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
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
                          'Your Account Number',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '(THIS DEVICE)',
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
                      '${_matchedUser!.phone} belongs to this account. Free Call connects between different KeepSIMs accounts. Use Smart Call if you need to test cellular connectivity.',
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }

      // Matched valid user
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D251C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kWhatsAppGreen.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: kWhatsAppGreen.withValues(alpha: 0.2),
              backgroundImage: _matchedUser!.avatarUrl != null
                  ? NetworkImage(_matchedUser!.avatarUrl!)
                  : null,
              child: _matchedUser!.avatarUrl == null
                  ? Text(
                      _matchedUser!.fullName.isNotEmpty
                          ? _matchedUser!.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: kWhatsAppGreen,
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
                          color: kWhatsAppGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ON KEEPSIMS',
                          style: TextStyle(
                            color: kWhatsAppGreen,
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
                backgroundColor: kWhatsAppGreen,
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
      );
    }

    // Unregistered phone number result
    return Container(
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
                  _searchError ?? 'Not on KeepSIMs Yet',
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
            '$_searchedQuery does not have a registered KeepSIMs app account. Free Call connects directly between users over the internet.\n\nYou can invite them to download the app, or dial their cellular phone directly using KeepSIMs Smart Call.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kWhatsAppGreen,
                    side: BorderSide(
                      color: kWhatsAppGreen.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text(
                    'Invite to App',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _shareInviteLink(_searchedQuery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.phone_forwarded, size: 15),
                  label: const Text(
                    'Smart Call',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }

  /// WhatsApp-Style Recent Calls Tab
  Widget _buildRecentCallsTab() {
    final historyAsync = ref.watch(voipCallHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: kWhatsAppGreen,
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Unable to load call history',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => ref.refresh(voipCallHistoryProvider),
                child: const Text('Retry', style: TextStyle(color: kWhatsAppGreen)),
              ),
            ],
          ),
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kWhatsAppGreen.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: kWhatsAppGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Recent Free Calls',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Call any KeepSIMs user using the search bar above, or invite your family to start calling 100% free over the internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kWhatsAppGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text(
                      'Invite Friends & Family',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _shareInviteLink(),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: kWhatsAppGreen,
          backgroundColor: AppColors.darkCard,
          onRefresh: () async => ref.refresh(voipCallHistoryProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: sessions.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isMissed = session.status == 'missed' ||
                  session.status == 'timeout' ||
                  (!session.isOutgoing && session.status != 'completed');

              final peerDisplayName = session.peerName?.isNotEmpty == true
                  ? session.peerName!
                  : (session.peerPhone?.isNotEmpty == true
                      ? session.peerPhone!
                      : 'KeepSIMs User');

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: isMissed
                      ? AppColors.error.withValues(alpha: 0.15)
                      : kWhatsAppGreen.withValues(alpha: 0.15),
                  backgroundImage: session.peerAvatarUrl != null
                      ? NetworkImage(session.peerAvatarUrl!)
                      : null,
                  child: session.peerAvatarUrl == null
                      ? Text(
                          peerDisplayName.isNotEmpty
                              ? peerDisplayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: isMissed ? AppColors.error : kWhatsAppGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  peerDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      isMissed
                          ? Icons.call_missed_rounded
                          : (session.isOutgoing
                              ? Icons.call_made_rounded
                              : Icons.call_received_rounded),
                      size: 14,
                      color: isMissed ? AppColors.error : kWhatsAppGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMissed ? 'Missed • ' : '',
                      style: TextStyle(
                        color: isMissed ? AppColors.error : Colors.white60,
                        fontSize: 12,
                        fontWeight:
                            isMissed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      _formatSessionTime(session.startedAt),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    if (session.durationSeconds > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${session.formattedDuration})',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.phone_rounded,
                    color: kWhatsAppGreen,
                    size: 22,
                  ),
                  tooltip: 'Free Call',
                  onPressed: () => _startCallWithUser(
                    userId: session.peerId,
                    name: peerDisplayName,
                    avatar: session.peerAvatarUrl,
                    phone: session.peerPhone,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// WhatsApp-Style Family Circle & Contacts Tab
  Widget _buildFamilyAndContactsTab() {
    final householdState = ref.watch(householdControllerProvider);
    final simLinesState = ref.watch(simLinesControllerProvider);
    final simLines = simLinesState.value ?? [];

    // Filter out current account/device's own phone number from raw SIMs
    final repo = ref.watch(voipCallingRepositoryProvider);
    final currentPhone = repo.currentUserPhone
            ?.replaceAll(RegExp(r'[^0-9]'), '') ??
        '';

    final secondarySimLines = simLines.where((l) {
      final clean = l.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      return clean.isNotEmpty && clean != currentPhone;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Family Circle (Household Members)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.family_restroom_rounded,
                  color: kWhatsAppGreen,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Family Circle',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: kWhatsAppGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Invite Member',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => context.push(AppRoutes.household),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Linked family accounts can call each other 100% free with 1 tap.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 10),

        householdState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kWhatsAppGreen,
              ),
            ),
          ),
          error: (_, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Unable to load family circle members.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          data: (state) {
            final members = state.members;
            if (members.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white10,
                      ),
                      child: const Icon(
                        Icons.group_add_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Family Members Linked',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Invite your spouse or kids so they can call your phone for free from anywhere.',
                            style: TextStyle(
                              color: Colors.white60,
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
                        backgroundColor: kWhatsAppGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => context.push(AppRoutes.household),
                      child: const Text(
                        'Invite',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: members.map((member) {
                final hasRegisteredAccount =
                    member.memberId != null && member.memberId!.isNotEmpty;
                final displayName =
                    member.memberName ?? member.memberEmail;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            kWhatsAppGreen.withValues(alpha: 0.15),
                        backgroundImage: member.memberAvatar != null
                            ? NetworkImage(member.memberAvatar!)
                            : null,
                        child: member.memberAvatar == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'F',
                                style: const TextStyle(
                                  color: kWhatsAppGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${member.role.toUpperCase()} • ${member.memberEmail}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasRegisteredAccount)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kWhatsAppGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.phone, size: 14),
                          label: const Text(
                            'Free Call',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _startCallWithUser(
                            userId: member.memberId!,
                            name: displayName,
                            avatar: member.memberAvatar,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Invite Pending',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // Section 2: Secondary Account SIM Lines (Honest Cellular/Invite handling)
        if (secondarySimLines.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.sim_card_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                'Secondary Account SIMs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Cellular SIMs managed under your account. To reach them over cellular network, use Smart Call.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...secondarySimLines.map((line) {
            final title =
                line.nickname ?? line.detectedOperatorName ?? line.phoneNumber;
            final countryCode = (line.countryId ?? 'SIM').toUpperCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white10,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      countryCode.length > 3
                          ? countryCode.substring(0, 3)
                          : countryCode,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line.phoneNumber,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kWhatsAppGreen,
                      side: BorderSide(
                        color: kWhatsAppGreen.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(54, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _shareInviteLink(line.phoneNumber),
                    child: const Text('Invite', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(64, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      context.go(
                        '${AppRoutes.calling}?number=${Uri.encodeComponent(line.phoneNumber)}',
                      );
                    },
                    child: const Text(
                      'Smart Call',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
