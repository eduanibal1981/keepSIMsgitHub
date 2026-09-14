import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import '../../domain/entities/active_return_trip_info.dart';
import '../../data/repositories/return_trip_repository_impl.dart';
import '../controllers/active_return_trip_provider.dart';
import 'active_return_package_bottom_sheet.dart';

class ManageReturnTripBottomSheet extends ConsumerStatefulWidget {
  final String simLineId;
  final String? countryName;
  final String? flagEmoji;
  final int initialTabIndex;

  const ManageReturnTripBottomSheet({
    super.key,
    required this.simLineId,
    this.countryName,
    this.flagEmoji,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String simLineId,
    String? countryName,
    String? flagEmoji,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManageReturnTripBottomSheet(
        simLineId: simLineId,
        countryName: countryName,
        flagEmoji: flagEmoji,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  ConsumerState<ManageReturnTripBottomSheet> createState() =>
      _ManageReturnTripBottomSheetState();
}

class _ManageReturnTripBottomSheetState
    extends ConsumerState<ManageReturnTripBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final destination = widget.countryName ?? 'Destination';
    final activeTripAsync = ref.watch(activeReturnTripInfoProvider(widget.simLineId));
    final historyAsync = ref.watch(returnTripHistoryProvider(widget.simLineId));

    final activeTrip = activeTripAsync.value;
    final allTrips = historyAsync.value ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // An old preparation is either in the past, cancelled, completed, or prior to current active trip
    final oldPreparations = allTrips.where((t) {
      final tripDay = DateTime(t.arrivalDate.year, t.arrivalDate.month, t.arrivalDate.day);
      final isPast = tripDay.isBefore(today);
      final isEnded = t.status == 'completed' || t.status == 'cancelled';
      final isNotActive = activeTrip != null && t.tripId != activeTrip.tripId;
      return isPast || isEnded || isNotActive;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101726) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0C4A6E).withValues(alpha: 0.35)
                        : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.flagEmoji ?? '✈️',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Travel · $destination',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.onSurfaceColor,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Return preparations & voucher history',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TabBar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF182234) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF0284C7) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: isDark ? Colors.white : const Color(0xFF0284C7),
                unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                dividerHeight: 0,
                tabs: [
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune_rounded, size: 15),
                        SizedBox(width: 6),
                        Text('Active Trip'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          oldPreparations.isNotEmpty
                              ? 'History (${oldPreparations.length})'
                              : 'History',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Active Trip Tab
                  _buildActiveTripTab(context, isDark, activeTrip, destination),

                  // Tab 2: History Tab
                  _buildHistoryTab(context, isDark, oldPreparations, historyAsync.isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripTab(
    BuildContext context,
    bool isDark,
    ActiveReturnTripInfo? activeTrip,
    String destination,
  ) {
    if (activeTrip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flight_takeoff_rounded,
                size: 44,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              Text(
                'No Active Trip Preparation',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prepare data for your next visit to $destination.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/sim-lines/${widget.simLineId}/return-trip');
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Prepare Return Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasUssd = activeTrip.ussdRechargeCode != null &&
        activeTrip.ussdRechargeCode!.trim().isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Package Highlight Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PREPARED FOR ${activeTrip.formattedArrivalDate.toUpperCase()}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (activeTrip.badgeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          activeTrip.badgeLabel!,
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activeTrip.packageTitle,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.onSurfaceColor,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activeTrip.formattedAllowance} allowance · Valid for ${activeTrip.formattedDuration} · ${activeTrip.carrierName ?? destination}',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 11.5,
                  ),
                ),
                if (hasUssd) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeTrip.ussdRechargeCode!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticHelper.lightTick();
                            Clipboard.setData(ClipboardData(text: activeTrip.ussdRechargeCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Recharge code copied!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0284C7)),
                              SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Option 1: Change Arrival Date
          _buildOptionTile(
            isDark: isDark,
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF0284C7),
            iconBgColor: isDark
                ? const Color(0xFF0C4A6E).withValues(alpha: 0.35)
                : const Color(0xFFE0F2FE),
            title: 'Change Arrival Date',
            subtitle: 'Current: ${activeTrip.formattedArrivalDate} · Adjust schedule & alerts',
            onTap: () => _handleChangeArrivalDate(context, activeTrip),
          ),
          const SizedBox(height: 10),

          // Option 2: View / Share Touchdown Guide
          _buildOptionTile(
            isDark: isDark,
            icon: Icons.share_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFFDCFCE7),
            title: 'View / Share Touchdown Guide',
            subtitle: 'Full instructions and USSD code for offline access',
            onTap: () {
              Navigator.pop(context);
              ActiveReturnPackageBottomSheet.show(
                context,
                tripInfo: activeTrip,
                countryName: widget.countryName,
                flagEmoji: widget.flagEmoji,
              );
            },
          ),
          const SizedBox(height: 10),

          // Option 3: Buy Additional Data Package
          _buildOptionTile(
            isDark: isDark,
            icon: Icons.add_shopping_cart_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.35)
                : const Color(0xFFFEF3C7),
            title: 'Plan Different Package / Add Data',
            subtitle: 'Need more data or a different bundle?',
            onTap: () {
              Navigator.pop(context);
              context.push('/sim-lines/${widget.simLineId}/return-trip');
            },
          ),
          const SizedBox(height: 10),

          // Option 4: Cancel Preparation
          _buildOptionTile(
            isDark: isDark,
            icon: Icons.cancel_outlined,
            iconColor: AppColors.error,
            iconBgColor: AppColors.error.withValues(alpha: 0.12),
            title: 'Cancel Preparation',
            subtitle: 'Archive trip and move to History',
            onTap: () => _handleCancelTrip(context, activeTrip),
          ),
          const SizedBox(height: 10),

          // Option 5: Voucher Policy
          _buildOptionTile(
            isDark: isDark,
            icon: Icons.info_outline_rounded,
            iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            iconBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            title: 'Voucher & Policy Notice',
            subtitle: 'Carrier PIN code policies and usage guidance',
            onTap: () => _showVoucherPolicyDialog(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    BuildContext context,
    bool isDark,
    List<ActiveReturnTripInfo> oldPreparations,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (oldPreparations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 46,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 12),
              Text(
                'No Past Preparations',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onSurfaceColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your completed, past, and archived travel packages will appear here for reference.',
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: oldPreparations.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final item = oldPreparations[index];
        return _buildHistoryItemCard(context, isDark, item);
      },
    );
  }

  Widget _buildHistoryItemCard(
    BuildContext context,
    bool isDark,
    ActiveReturnTripInfo item,
  ) {
    final hasUssd = item.ussdRechargeCode != null && item.ussdRechargeCode!.trim().isNotEmpty;
    final isCancelled = item.status == 'cancelled';
    final isCompleted = item.status == 'completed';

    Color statusColor;
    String statusLabel;
    if (isCancelled) {
      statusColor = AppColors.error;
      statusLabel = 'CANCELLED';
    } else if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'COMPLETED';
    } else {
      statusColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      statusLabel = 'PAST TRIP';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182234) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.isEsim ? Icons.sim_card_download_rounded : Icons.confirmation_number_outlined,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TRIP FOR ${item.formattedArrivalDate.toUpperCase()}',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.packageTitle,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.onSurfaceColor,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.formattedAllowance} · Valid ${item.formattedDuration}${item.carrierName != null ? " · ${item.carrierName}" : ""}',
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 11,
            ),
          ),
          if (hasUssd) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.ussdRechargeCode!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticHelper.lightTick();
                      Clipboard.setData(ClipboardData(text: item.ussdRechargeCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recharge code copied!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 13, color: Color(0xFF0284C7)),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              HapticHelper.lightTick();
              ActiveReturnPackageBottomSheet.show(
                context,
                tripInfo: item,
                countryName: widget.countryName,
                flagEmoji: widget.flagEmoji,
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Touchdown Instructions',
                  style: TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Color(0xFF0284C7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticHelper.lightTick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF182234) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.onSurfaceColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangeArrivalDate(
    BuildContext context,
    ActiveReturnTripInfo activeTrip,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: activeTrip.arrivalDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select New Arrival Date',
      confirmText: 'Update Date',
    );

    if (picked != null && picked != activeTrip.arrivalDate) {
      try {
        final repo = ref.read(returnTripRepositoryProvider);
        await repo.updateArrivalDate(activeTrip.tripId, picked);
        ref.invalidate(activeReturnTripInfoProvider(widget.simLineId));
        ref.invalidate(returnTripHistoryProvider(widget.simLineId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Arrival date updated to ${DateFormat('MMM d, yyyy').format(picked)}!',
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update arrival date: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCancelTrip(
    BuildContext context,
    ActiveReturnTripInfo activeTrip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip Preparation?'),
        content: const Text(
          'This will cancel this upcoming return trip preparation and archive it in your history. Any prepaid USSD voucher codes remain valid on the carrier network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Trip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Trip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(returnTripRepositoryProvider);
        await repo.cancelTrip(activeTrip.tripId);
        ref.invalidate(activeReturnTripInfoProvider(widget.simLineId));
        ref.invalidate(returnTripHistoryProvider(widget.simLineId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip preparation archived in History.'),
              backgroundColor: Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel trip: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showVoucherPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.policy_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Voucher & Prep Policy', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digital PIN Codes & eSIMs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Carrier PIN vouchers and eSIM profiles are digital goods provisioned immediately. Once issued, they cannot be returned to telecom partners.',
                style: TextStyle(fontSize: 12.5),
              ),
              SizedBox(height: 12),
              Text(
                'Date Rescheduling',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'You may adjust your arrival date at any time without extra fees. Your code remains safely stored in KeepSIMs.',
                style: TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
