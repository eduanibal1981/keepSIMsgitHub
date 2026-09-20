/// KeepSIMs — Calling Mode Switcher Bar
///
/// Segmented bar to cleanly switch between the 3 distinct calling modes:
/// 1. International Calling (Paid PSTN via Telnyx)
/// 2. Free App-to-App Calling (KeepSIMs VoIP WhatsApp-style)
/// 3. Audio & SIP Trunk Diagnostics (Free hardware/loopback test)
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';

enum CallingMode { international, internet, myNumbers, diagnostics }

class CallingModeSwitcher extends StatelessWidget {
  final CallingMode activeMode;

  const CallingModeSwitcher({super.key, required this.activeMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          // Mode 1: Phone Calls (Paid PSTN via Telnyx)
          Expanded(
            child: _ModeTab(
              icon: Icons.public_rounded,
              label: 'Phone Calls',
              badge: 'PAID',
              badgeColor: AppColors.primary,
              isSelected: activeMode == CallingMode.international,
              onTap: () {
                if (activeMode != CallingMode.international) {
                  context.go(AppRoutes.calling);
                }
              },
            ),
          ),
          const SizedBox(width: 4),

          // Mode 2: KeepSIMs Calls (Free App-to-App)
          Expanded(
            child: _ModeTab(
              icon: Icons.phone_in_talk_rounded,
              label: 'KeepSIMs Calls',
              badge: 'FREE',
              badgeColor: AppColors.secondary,
              isSelected: activeMode == CallingMode.internet,
              onTap: () {
                if (activeMode != CallingMode.internet) {
                  context.go(AppRoutes.internetCalling);
                }
              },
            ),
          ),
          const SizedBox(width: 4),

          // Mode 3: My Numbers (Virtual DIDs & Forwarding)
          Expanded(
            child: _ModeTab(
              icon: Icons.pin_outlined,
              label: 'My Numbers',
              badge: 'DID',
              badgeColor: Colors.purpleAccent,
              isSelected: activeMode == CallingMode.myNumbers,
              onTap: () {
                if (activeMode != CallingMode.myNumbers) {
                  context.go(AppRoutes.myNumbers);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String badge;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? badgeColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? badgeColor.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? badgeColor : Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? badgeColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: isSelected ? badgeColor : Colors.white38,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
