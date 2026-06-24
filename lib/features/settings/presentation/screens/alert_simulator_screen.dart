import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/whatsapp_service.dart';
import 'package:keep_sims/features/scheduled_topups/controller/scheduled_topup_controller.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/services/connectivity_service.dart';
import 'package:keep_sims/features/settings/presentation/screens/paypal_simulator_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/zendit_simulator_screen.dart';

class AlertSimulatorScreen extends ConsumerStatefulWidget {
  const AlertSimulatorScreen({super.key});

  @override
  ConsumerState<AlertSimulatorScreen> createState() =>
      _AlertSimulatorScreenState();
}

class _AlertSimulatorScreenState extends ConsumerState<AlertSimulatorScreen> {
  String _selectedCategory = 'top_up_success';
  String? _selectedSimLineId;
  int _selectedDelayMinutes = 0;
  bool _sendLocalWhatsApp = false;
  bool _isSimulatingSchedule = false;
  late final TextEditingController _whatsappPhoneController;

  final Map<String, String> _simulatorCategories = {
    'top_up_success': 'Top-up Successful',
    'top_up_failed': 'Top-up Failed (Critical)',
    'wallet_low': 'Low Wallet Warning',
    'wallet_depleted': 'Wallet Depleted',
    'line_critical': 'SIM Grace Warning (Critical)',
    'line_entering_grace': 'Entering Grace Period',
    'referral_reward': 'Referral Reward Received',
    'system': 'General System Update',
  };

  @override
  void initState() {
    super.initState();
    _whatsappPhoneController = TextEditingController(text: '96891234567');
  }

  @override
  void dispose() {
    _whatsappPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Simulators',
          style: AppTextStyles.headlineLarge.copyWith(
            color: context.onSurfaceColor,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Colors.deepPurple.withOpacity(0.08),
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.deepPurple, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ZenditSimulatorScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.phonelink_ring, size: 16),
              label: const Text(
                'Zendit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF003087).withOpacity(0.08),
                foregroundColor: const Color(0xFF0070BA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF0070BA), width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PaypalSimulatorScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.payment_rounded, size: 16),
              label: const Text(
                'PayPal Test',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildSimulatorDashboard(context),
      ),
    );
  }

  Widget _buildSimulatorDashboard(BuildContext context) {
    final simLinesAsync = ref.watch(simLinesControllerProvider);
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFEAEEF1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.primary : AppColors.lightPrimary)
              .withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                .withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Live Incident Simulator',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dropdown for categories
          Text(
            'Select Incident Template',
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                dropdownColor: context.scaffoldBackgroundColor,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.lightPrimaryMid,
                ),
                items: _simulatorCategories.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.onSurfaceColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    await HapticHelper.lightTick();
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Side-by-side SIM Card and Timing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Link to SIM Card (Optional)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link to SIM Card',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    simLinesAsync.maybeWhen(
                      data: (lines) {
                        if (lines.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No SIM lines.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          );
                        }

                        // Pre-select first line if null
                        if (_selectedSimLineId == null && lines.isNotEmpty) {
                          _selectedSimLineId = lines.first.id;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSimLineId,
                              isExpanded: true,
                              dropdownColor: context.scaffoldBackgroundColor,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.lightPrimaryMid,
                              ),
                              items: lines.map((l) {
                                return DropdownMenuItem<String>(
                                  value: l.id,
                                  child: Text(
                                    l.nickname ?? l.phoneNumber,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: context.onSurfaceColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) async {
                                await HapticHelper.lightTick();
                                setState(() {
                                  _selectedSimLineId = val;
                                  if (val != null) {
                                    final match = lines.firstWhere(
                                      (l) => l.id == val,
                                    );
                                    _whatsappPhoneController.text =
                                        match.phoneNumber;
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Delivery Timing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Timing',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDelayMinutes,
                          isExpanded: true,
                          dropdownColor: context.scaffoldBackgroundColor,
                          icon: Icon(
                            Icons.schedule_rounded,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.lightPrimaryMid,
                            size: 16,
                          ),
                          items: [
                            DropdownMenuItem<int>(
                              value: 0,
                              child: Text(
                                'Instant',
                                style: TextStyle(color: context.onSurfaceColor),
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Text(
                                '1 Min',
                                style: TextStyle(color: context.onSurfaceColor),
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 10,
                              child: Text(
                                '10 Min',
                                style: TextStyle(color: context.onSurfaceColor),
                              ),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              await HapticHelper.lightTick();
                              setState(() {
                                _selectedDelayMinutes = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Local WhatsApp Server test toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _sendLocalWhatsApp
                    ? (isDark ? AppColors.primary : AppColors.lightPrimary)
                          .withValues(alpha: 0.3)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Theme(
              data: ThemeData(
                unselectedWidgetColor: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              child: CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                title: Text(
                  'Trigger WhatsApp Server Alert',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Sends alert via local server.js to WhatsApp',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                value: _sendLocalWhatsApp,
                activeColor: isDark
                    ? AppColors.primary
                    : AppColors.lightPrimary,
                checkColor: Colors.white,
                onChanged: (val) async {
                  await HapticHelper.lightTick();
                  setState(() {
                    _sendLocalWhatsApp = val ?? false;
                  });
                },
              ),
            ),
          ),

          if (_sendLocalWhatsApp) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _whatsappPhoneController,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.onSurfaceColor,
              ),
              decoration: InputDecoration(
                labelText: 'WhatsApp Recipient Phone Number',
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                hintText: 'e.g. 96891234567',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.primaryColor),
                ),
                prefixIcon: Icon(
                  Icons.phone_iphone_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  size: 18,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Trigger Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () async {
                await HapticHelper.mediumImpact();
                _triggerSimulatedAlert();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Inject simulated incident'),
            ),
          ),
          const SizedBox(height: 24),

          // Schedule Execution Simulator
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: isDark ? AppColors.secondary : AppColors.lightSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Schedule Execution Simulator',
                style: AppTextStyles.titleMedium.copyWith(
                  color: context.onSurfaceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedSimLineId != null)
            _buildScheduleSimulatorSection(context),
        ],
      ),
    );
  }

  Widget _buildScheduleSimulatorSection(BuildContext context) {
    if (_selectedSimLineId == null) return const SizedBox.shrink();

    final notifySchedule = ref.watch(
      scheduledNotifyForLineProvider(_selectedSimLineId!),
    );
    final miniRefill = ref.watch(
      scheduledMiniRefillForLineProvider(_selectedSimLineId!),
    );
    final customRefill = ref.watch(
      scheduledCustomRefillForLineProvider(_selectedSimLineId!),
    );
    final refillSchedule = customRefill ?? miniRefill;

    if (notifySchedule == null && refillSchedule == null) {
      return Text(
        'No active schedules for this SIM line.',
        style: AppTextStyles.bodySmall.copyWith(
          color: context.isDarkMode
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
      );
    }

    return Column(
      children: [
        if (notifySchedule != null)
          _buildSimulateButton(
            context: context,
            label: 'Simulate Notify',
            scheduleId: notifySchedule.id,
            isRefill: false,
          ),
        if (notifySchedule != null && refillSchedule != null)
          const SizedBox(height: 10),
        if (refillSchedule != null)
          _buildSimulateButton(
            context: context,
            label: 'Simulate Refill',
            scheduleId: refillSchedule.id,
            isRefill: true,
          ),
      ],
    );
  }

  Widget _buildSimulateButton({
    required BuildContext context,
    required String label,
    required String scheduleId,
    required bool isRefill,
  }) {
    final networkStatus = ref.watch(connectivityServiceProvider);
    final isOffline = networkStatus == NetworkStatus.offline;

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: ElevatedButton.icon(
        onPressed: _isSimulatingSchedule
            ? null
            : (isOffline
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRefill
                                ? 'Refill simulation requires an active internet connection.'
                                : 'Notify simulation requires an active internet connection.',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  : () => _simulateSchedule(scheduleId, isRefill)),
        icon: _isSimulatingSchedule
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.onSurfaceColor,
                ),
              )
            : Icon(
                isOffline ? Icons.lock_outline_rounded : Icons.flash_on_rounded,
                size: 16,
                color: isOffline
                    ? context.onSurfaceColor.withOpacity(0.4)
                    : Colors.white,
              ),
        label: Text(
          isOffline ? 'Simulation Locked 🔒' : label,
          style: TextStyle(
            color: isOffline
                ? context.onSurfaceColor.withOpacity(0.4)
                : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOffline
              ? Colors.grey.withOpacity(0.12)
              : (isRefill ? AppColors.secondaryDark : AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _simulateSchedule(String scheduleId, bool isRefill) async {
    setState(() => _isSimulatingSchedule = true);
    try {
      final result = await ref
          .read(scheduledTopupControllerProvider.notifier)
          .executeMockTopup(scheduleId);

      if (mounted) {
        switch (result) {
          case Success():
            ref.invalidate(simLinesControllerProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.onSurfaceColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRefill
                            ? 'Auto-refill execution simulated! Balance deducted & validity extended.'
                            : 'Renewal execution simulated! Validity extended.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          case Failure(error: final err):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err.message),
                backgroundColor: AppColors.error,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulated execution failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulatingSchedule = false);
    }
  }

  void _triggerSimulatedAlert() {
    String title = '';
    String body = '';

    switch (_selectedCategory) {
      case 'top_up_success':
        title = 'Renewal Successful';
        body =
            'Auto-refill of \$15.00 executed successfully. Your SIM validity has been extended by 30 days.';
        break;
      case 'top_up_failed':
        title = 'Renewal Failed (Critical)';
        body =
            'Immediate attention required! Auto-refill of \$10.00 failed due to insufficient wallet funds.';
        break;
      case 'wallet_low':
        title = 'Low Wallet Balance';
        body =
            'Your primary wallet balance is \$8.50, which is below your \$10.00 threshold limit.';
        break;
      case 'wallet_depleted':
        title = 'Wallet Depleted';
        body =
            'Your wallet has reached \$0.00. Automatic renewals are now suspended until you add funds.';
        break;
      case 'line_critical':
        title = 'SIM Approaching Expiry';
        body =
            'Your SIM card validity expires in 48 hours. Auto-renewal has been queued for immediate backup rescue.';
        break;
      case 'line_entering_grace':
        title = 'Entering Grace Period';
        body =
            'Your prepaid SIM card has entered carrier grace period. Please perform a top-up immediately to avoid deactivation.';
        break;
      case 'referral_reward':
        title = 'Referral Credit Awarded';
        body =
            'Congratulations! Your friend successfully joined. \$2.00 has been credited to your primary wallet.';
        break;
      case 'system':
      default:
        title = 'System Maintenance Completed';
        body =
            'Carrier rule engines updated for expat carrier nodes. All deactivation thresholds updated successfully.';
        break;
    }

    ref
        .read(notificationsControllerProvider.notifier)
        .simulateMockNotification(
          category: _selectedCategory,
          title: title,
          body: body,
          simLineId: _selectedSimLineId,
          delayMinutes: _selectedDelayMinutes,
        );

    if (_sendLocalWhatsApp) {
      final phone = _whatsappPhoneController.text.trim();
      if (phone.isNotEmpty) {
        WhatsAppService.sendMessage(
          phone: phone,
          message: '$title: $body',
        ).then((sent) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sent
                      ? 'WhatsApp mock alert sent successfully!'
                      : 'Failed to send WhatsApp mock alert (check server.js!)',
                ),
                backgroundColor: sent ? AppColors.success : AppColors.healthRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    }

    HapticHelper.successFeedback();

    final message = _selectedDelayMinutes > 0
        ? 'Scheduled mock alert "$title" to deliver in $_selectedDelayMinutes min!'
        : 'Simulated alert "$title" injected successfully!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
