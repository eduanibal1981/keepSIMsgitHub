/// KeepSIMs — Smart Calling Unified Route-Aware Navigation Bar
///
/// Implements the 6-destination navigation for KeepSIMs Smart Calling:
/// 1. Dialer (/calling)
/// 2. Free Call (/calling/internet)
/// 3. Numbers (/calling/my-numbers)
/// 4. Savings (/calling/savings)
/// 5. Voicemail (/calling/voicemail)
/// 6. Inspector (/calling/sip-test)
///
/// Ensures minimum 48px tap targets, route-derived active selection,
/// deduplicated navigation taps, and unread notification badge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/calling/presentation/screens/voicemail_inbox_screen.dart';

class SmartCallNavigation extends ConsumerWidget {
  const SmartCallNavigation({super.key});

  static int getSelectedIndex(String location) {
    if (location.startsWith(AppRoutes.internetCalling)) return 1;
    if (location.startsWith(AppRoutes.myNumbers)) return 2;
    if (location.startsWith(AppRoutes.callingSavings)) return 3;
    if (location.startsWith(AppRoutes.voicemail)) return 4;
    if (location.startsWith(AppRoutes.sipDiagnostics)) return 5;
    if (location.startsWith(AppRoutes.calling)) return 0;
    return 0;
  }

  static String getRouteForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.calling;
      case 1:
        return AppRoutes.internetCalling;
      case 2:
        return AppRoutes.myNumbers;
      case 3:
        return AppRoutes.callingSavings;
      case 4:
        return AppRoutes.voicemail;
      case 5:
        return AppRoutes.sipDiagnostics;
      default:
        return AppRoutes.calling;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = getSelectedIndex(location);

    // Watch voicemails to display unread badge on Voicemail tab
    final unreadVoicemailsCount =
        ref
            .watch(voicemailsProvider)
            .asData
            ?.value
            .where((m) => !m.isRead)
            .length ??
        0;

    final items = [
      const _NavItemData(
        icon: Icons.tag_rounded,
        selectedIcon: Icons.tag_rounded,
        label: 'Dialer',
        route: AppRoutes.calling,
      ),
      const _NavItemData(
        icon: Icons.language_rounded,
        selectedIcon: Icons.language_rounded,
        label: 'Free Call',
        route: AppRoutes.internetCalling,
      ),
      const _NavItemData(
        icon: Icons.layers_outlined,
        selectedIcon: Icons.layers_rounded,
        label: 'Numbers',
        route: AppRoutes.myNumbers,
      ),
      const _NavItemData(
        icon: Icons.calculate_outlined,
        selectedIcon: Icons.calculate_rounded,
        label: 'Savings',
        route: AppRoutes.callingSavings,
      ),
      _NavItemData(
        icon: Icons.notifications_none_rounded,
        selectedIcon: Icons.notifications_rounded,
        label: 'Voicemail',
        route: AppRoutes.voicemail,
        badgeCount: unreadVoicemailsCount,
      ),
      const _NavItemData(
        icon: Icons.dns_outlined,
        selectedIcon: Icons.dns_rounded,
        label: 'Inspector',
        route: AppRoutes.sipDiagnostics,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF090E17),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive treatment: if screen width is narrow (<360dp), make it cleanly scrollable
            final isNarrow = constraints.maxWidth < 360;

            final content = Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return _SmartCallNavItem(
                  data: item,
                  isSelected: isSelected,
                  minWidth: isNarrow ? 60.0 : (constraints.maxWidth / 6.0),
                  onTap: () {
                    if (selectedIndex == index) return; // Prevent duplicate push
                    HapticHelper.lightTick();
                    context.go(item.route);
                  },
                );
              }),
            );

            if (isNarrow) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: content,
              );
            }

            return content;
          },
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  final int badgeCount;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    this.badgeCount = 0,
  });
}

class _SmartCallNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final double minWidth;
  final VoidCallback onTap;

  const _SmartCallNavItem({
    required this.data,
    required this.isSelected,
    required this.minWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF818CF8); // Indigo highlight from references
    const inactiveColor = Colors.white54;

    return Semantics(
      label: data.label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            minHeight: 56, // Guaranteed >= 48px touch target
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? data.selectedIcon : data.icon,
                      color: isSelected ? activeColor : inactiveColor,
                      size: 22,
                    ),
                    if (data.badgeCount > 0)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
