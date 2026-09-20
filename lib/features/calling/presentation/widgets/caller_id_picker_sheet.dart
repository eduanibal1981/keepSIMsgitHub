/// KeepSIMs — Caller ID Picker & Switcher Bottom Sheet
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/features/calling/data/models/caller_id_model.dart';
import 'package:keep_sims/features/calling/data/repositories/calling_repository.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';

class CallerIdPickerSheet extends ConsumerStatefulWidget {
  const CallerIdPickerSheet({super.key});

  @override
  ConsumerState<CallerIdPickerSheet> createState() =>
      _CallerIdPickerSheetState();
}

class _CallerIdPickerSheetState extends ConsumerState<CallerIdPickerSheet> {
  String? _switchingTarget;

  Future<void> _selectGateway() async {
    setState(() => _switchingTarget = 'gateway');
    try {
      await ref
          .read(callingRepositoryProvider)
          .setDefaultCallerId(phoneNumber: 'gateway');
      ref.invalidate(callerIdListProvider);
      ref.invalidate(userCallerIdsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              'KeepSIMs Voice Gateway set as active Outbound Caller ID',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingTarget = null);
    }
  }

  Future<void> _selectCallerId(CallerIdModel item) async {
    setState(() => _switchingTarget = item.id);
    try {
      await ref
          .read(callingRepositoryProvider)
          .setDefaultCallerId(callerIdId: item.id);
      ref.invalidate(callerIdListProvider);
      ref.invalidate(userCallerIdsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondary,
            content: Text(
              '${item.phoneNumber} set as active Outbound Caller ID',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingTarget = null);
    }
  }

  Future<void> _deleteNumber(CallerIdModel item) async {
    try {
      await ref
          .read(callingRepositoryProvider)
          .deleteCallerId(callerIdId: item.id);
      ref.invalidate(callerIdListProvider);
      ref.invalidate(userCallerIdsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
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
                  child: const Icon(
                    Icons.phone_forwarded_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outbound Caller ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                final verifiedList = result.callerIds
                    .where((c) => c.isVerified)
                    .toList();
                final isGatewayActive = result.isGatewayActive;
                final gatewayNumber = result.defaultGatewayNumber;

                return Column(
                  children: [
                    // ── 1. KeepSIMs Voice Gateway Option ──
                    _CallerIdTile(
                      title: 'KeepSIMs Voice Gateway',
                      phoneNumber: gatewayNumber,
                      subtitle:
                          'Shared international gateway (Bypasses local carrier blocks)',
                      icon: Icons.shield_outlined,
                      isSelected: isGatewayActive,
                      isLoading: _switchingTarget == 'gateway',
                      badgeText: 'DEFAULT',
                      badgeColor: AppColors.primary,
                      onTap: _selectGateway,
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
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      ...verifiedList.map((item) {
                        final isThisSelected =
                            !isGatewayActive && item.isDefault;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CallerIdTile(
                            title: item.label.isNotEmpty
                                ? item.label
                                : 'Personal Mobile',
                            phoneNumber: item.phoneNumber,
                            subtitle:
                                'Recipients will see your real phone number',
                            icon: Icons.phone_android,
                            isSelected: isThisSelected,
                            isLoading: _switchingTarget == item.id,
                            badgeText: 'VERIFIED',
                            badgeColor: AppColors.secondary,
                            onTap: () => _selectCallerId(item),
                            onDelete: () => _deleteNumber(item),
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
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        label: const Text(
                          'Verify & Add Another Number',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text(
                'Error loading numbers: $err',
                style: const TextStyle(color: AppColors.error),
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? badgeColor.withValues(alpha: 0.12)
            : AppColors.darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? badgeColor : AppColors.darkBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: isLoading ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? badgeColor.withValues(alpha: 0.2)
                : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? badgeColor : Colors.white70,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              phoneNumber,
              style: TextStyle(
                color: isSelected ? badgeColor : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(Icons.check_circle, color: badgeColor, size: 22)
                  else
                    const Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.white38,
                      size: 22,
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Remove',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
