/// KeepSIMs — Caller ID Picker & Switcher Bottom Sheet
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';

final callerIdListProvider = FutureProvider<CallerIdListResult>((ref) async {
  return ref.watch(callingRepositoryProvider).getCallerIdList();
});

class CallerIdPickerSheet extends ConsumerStatefulWidget {
  const CallerIdPickerSheet({super.key});

  @override
  ConsumerState<CallerIdPickerSheet> createState() => _CallerIdPickerSheetState();
}

class _CallerIdPickerSheetState extends ConsumerState<CallerIdPickerSheet> {
  String? _switchingNumber;

  Future<void> _selectCallerId(String phoneNumber) async {
    setState(() => _switchingNumber = phoneNumber);
    try {
      await ref.read(callingRepositoryProvider).setDefaultCallerId(phoneNumber);
      ref.invalidate(callerIdListProvider);
      ref.invalidate(userCallerIdsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              phoneNumber == 'gateway' || phoneNumber == '+17543180369'
                  ? 'KeepSIMs Gateway set as active Outbound Caller ID'
                  : '$phoneNumber set as active Outbound Caller ID',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingNumber = null);
    }
  }

  Future<void> _deleteNumber(String phoneNumber) async {
    try {
      await ref.read(callingRepositoryProvider).deleteCallerId(phoneNumber);
      ref.invalidate(callerIdListProvider);
      ref.invalidate(userCallerIdsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
        );
      }
    }
  }

  void _openAddNewNumberSheet() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VerifyCallerIdSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(callerIdListProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_forwarded_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outbound Caller ID',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Choose what number recipients see when you call',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            listAsync.when(
              data: (result) {
                final verifiedList = result.callerIds.where((c) => c.isVerified).toList();
                final hasActiveVerified = verifiedList.any((c) => c.isDefault);
                final isGatewayActive = !hasActiveVerified;
                final gatewayNumber = result.defaultGatewayNumber;

                return Column(
                  children: [
                    // ── 1. KeepSIMs Voice Gateway Option ──
                    _CallerIdTile(
                      title: 'KeepSIMs Voice Gateway',
                      phoneNumber: gatewayNumber,
                      subtitle: 'Shared international gateway (Bypasses local carrier blocks)',
                      icon: Icons.shield_outlined,
                      isSelected: isGatewayActive,
                      isLoading: _switchingNumber == 'gateway' || _switchingNumber == gatewayNumber,
                      badgeText: 'DEFAULT',
                      badgeColor: AppColors.primary,
                      onTap: () => _selectCallerId('gateway'),
                    ),

                    const SizedBox(height: 12),

                    // ── 2. User Verified Numbers ──
                    if (verifiedList.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'MY VERIFIED NUMBERS',
                            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ),
                      ...verifiedList.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CallerIdTile(
                            title: item.label.isNotEmpty ? item.label : 'Personal Mobile',
                            phoneNumber: item.phoneNumber,
                            subtitle: 'Recipients will see your real phone number',
                            icon: Icons.phone_android,
                            isSelected: item.isDefault,
                            isLoading: _switchingNumber == item.phoneNumber,
                            badgeText: 'VERIFIED',
                            badgeColor: AppColors.secondary,
                            onTap: () => _selectCallerId(item.phoneNumber),
                            onDelete: () => _deleteNumber(item.phoneNumber),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 16),

                    // ── 3. Add New Number Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _openAddNewNumberSheet,
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                        label: const Text(
                          'Verify & Add Another Number',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, _) => Text('Error loading numbers: $err', style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _CallerIdTile extends StatelessWidget {
  final String title;
  final String phoneNumber;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isLoading;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _CallerIdTile({
    required this.title,
    required this.phoneNumber,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.isLoading = false,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.12) : AppColors.darkBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? badgeColor : AppColors.darkBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? badgeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? badgeColor : Colors.white70, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phoneNumber,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (isSelected)
              Icon(Icons.check_circle, color: badgeColor, size: 22)
            else if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
