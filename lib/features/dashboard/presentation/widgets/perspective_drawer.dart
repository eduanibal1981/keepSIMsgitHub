/// SIM Shield — 3D Cascading Perspective Drawer
///
/// Wraps the main screen with a 3D perspective / scaled deck drawer
/// that smoothly slides and cascades layered cards behind the main screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/perspective_drawer_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class PerspectiveDrawerScaffold extends ConsumerStatefulWidget {
  const PerspectiveDrawerScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PerspectiveDrawerScaffold> createState() =>
      _PerspectiveDrawerScaffoldState();
}

class _PerspectiveDrawerScaffoldState
    extends ConsumerState<PerspectiveDrawerScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details, bool isRtl, double width) {
    final delta = details.primaryDelta ?? 0;
    final progress = isRtl ? -delta / (width * 0.65) : delta / (width * 0.65);
    _controller.value += progress;
  }

  void _handleDragEnd(DragEndDetails details, bool isRtl) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 400) {
      if (isRtl ? velocity < 0 : velocity > 0) {
        ref.read(perspectiveDrawerControllerProvider.notifier).open();
      } else {
        ref.read(perspectiveDrawerControllerProvider.notifier).close();
      }
    } else {
      if (_controller.value > 0.45) {
        ref.read(perspectiveDrawerControllerProvider.notifier).open();
      } else {
        ref.read(perspectiveDrawerControllerProvider.notifier).close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(perspectiveDrawerControllerProvider);
    final isDark = context.isDarkMode;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;

    // React to provider state
    if (isOpen &&
        _controller.status != AnimationStatus.forward &&
        _controller.status != AnimationStatus.completed) {
      _controller.forward();
    } else if (!isOpen &&
        _controller.status != AnimationStatus.reverse &&
        _controller.status != AnimationStatus.dismissed) {
      _controller.reverse();
    }

    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(perspectiveDrawerControllerProvider.notifier).close();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Background Drawer Menu ──────────────────────────
            Positioned.fill(
              child: _PerspectiveDrawerMenu(
                onClose: () {
                  ref
                      .read(perspectiveDrawerControllerProvider.notifier)
                      .close();
                },
              ),
            ),

            // ── Cascading Ghost Card 2 (Deepest) ────────────────
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final value = _animation.value;
                if (value == 0) return const SizedBox.shrink();

                final slideX =
                    (screenWidth * 0.65 - 32) * (isRtl ? -1 : 1) * value;
                final scale = 1.0 - (0.24 * value);

                return Transform(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..translateByDouble(slideX, 0.0, 0.0, 1.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: Opacity(
                    opacity: (0.30 * value).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF003847).withValues(alpha: 0.50)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28 * value),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF4CD7F6).withValues(
                                  alpha: 0.16 * value,
                                )
                              : Colors.black.withValues(alpha: 0.05 * value),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: (isDark ? 0.35 : 0.14) * value,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Cascading Ghost Card 1 (Middle) ─────────────────
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final value = _animation.value;
                if (value == 0) return const SizedBox.shrink();

                final slideX =
                    (screenWidth * 0.65 - 16) * (isRtl ? -1 : 1) * value;
                final scale = 1.0 - (0.22 * value);

                return Transform(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..translateByDouble(slideX, 0.0, 0.0, 1.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: Opacity(
                    opacity: (0.55 * value).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF00485C).withValues(alpha: 0.60)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28 * value),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF4CD7F6).withValues(
                                  alpha: 0.24 * value,
                                )
                              : Colors.black.withValues(alpha: 0.07 * value),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: (isDark ? 0.45 : 0.18) * value,
                            ),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Foreground Main Screen (Scaled & Transformed) ───
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final value = _animation.value;
                final slideX = (screenWidth * 0.65) * (isRtl ? -1 : 1) * value;
                final scale = 1.0 - (0.20 * value);

                return Transform(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..translateByDouble(slideX, 0.0, 0.0, 1.0)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28 * value),
                      border: value > 0
                          ? Border.all(
                              color: isDark
                                  ? const Color(0xFF4CD7F6).withValues(
                                      alpha: 0.32 * value,
                                    )
                                  : Colors.black.withValues(alpha: 0.08 * value),
                              width: 1.2,
                            )
                          : null,
                      boxShadow: value > 0
                          ? [
                              // Deep dark drop shadow
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: (isDark ? 0.60 : 0.28) * value,
                                ),
                                blurRadius: 32,
                                offset: Offset(isRtl ? -14 : 14, 10),
                                spreadRadius: 2,
                              ),
                              // Luminous ambient rim glow in dark mode
                              if (isDark)
                                BoxShadow(
                                  color: const Color(0xFF4CD7F6).withValues(
                                    alpha: 0.16 * value,
                                  ),
                                  blurRadius: 24,
                                  offset: Offset(isRtl ? -6 : 6, 2),
                                  spreadRadius: 0,
                                ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28 * value),
                      child: Stack(
                        children: [
                          widget.child,

                          // Tap and swipe overlay when drawer is open
                          if (value > 0)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  await HapticHelper.lightTick();
                                  ref
                                      .read(
                                        perspectiveDrawerControllerProvider
                                            .notifier,
                                      )
                                      .close();
                                },
                                onHorizontalDragUpdate: (details) =>
                                    _handleDragUpdate(
                                      details,
                                      isRtl,
                                      screenWidth,
                                    ),
                                onHorizontalDragEnd: (details) =>
                                    _handleDragEnd(details, isRtl),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer Menu Background (Theme-Adaptive) ────────────────────────
class _PerspectiveDrawerMenu extends ConsumerWidget {
  const _PerspectiveDrawerMenu({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final authProfile = ref.watch(authControllerProvider).value;
    final userName = authProfile?.fullName ?? 'KeepSIMs User';
    final userEmail = authProfile?.email ?? '';
    final isPowerUser = authProfile?.isPowerUser ?? false;

    // Theme adaptive background gradients (Option 1: Deep Cyber Cyan for Dark Mode)
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF00222D), Color(0xFF001118)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF005A6F), Color(0xFF003D4C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(gradient: bgGradient),
      child: Stack(
        children: [
          // ── Background Logo Watermark ─────────────────────────
          Positioned(
            bottom: -35,
            right: isRtl ? null : -25,
            left: isRtl ? -25 : null,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.05 : 0.08,
                child: Image.asset(
                  'assets/images/Logo.png',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // ── Scrollable Menu Content ───────────────────────────
          SafeArea(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.65,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  const SizedBox(height: 12),

                  // User Profile Snippet (Tappable to view Profile)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        onClose();
                        context.push(AppRoutes.profile);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/Logo.png',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (userEmail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      userEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPowerUser
                                          ? Colors.amberAccent.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPowerUser ? 'POWER USER' : 'STANDARD',
                                      style: TextStyle(
                                        color: isPowerUser
                                            ? Colors.amberAccent
                                            : Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.15),
                    thickness: 1,
                  ),
                  const SizedBox(height: 12),

                  // ── Navigation Menu Items ─────────────────────
                  _buildMenuItem(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Protected SIMs',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.simLines);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.phone_in_talk_outlined,
                    title: AppLocalizations.of(context)!.smartCall,
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.calling);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: AppLocalizations.of(context)!.wallet,
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.wallet);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.language_rounded,
                    title: 'eSIM Store',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.esim);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.wifi_off_rounded,
                    title: 'Offline Refill',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.offlineRefill);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.group_outlined,
                    title: 'Household & Family',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.household);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.card_giftcard_rounded,
                    title: 'Refer & Earn',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.referrals);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.settings);
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    onTap: () {
                      onClose();
                      context.push(AppRoutes.supportFaq);
                    },
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.15),
                    thickness: 1,
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    icon: Icons.logout_rounded,
                    title: AppLocalizations.of(context)!.logOut,
                    color: const Color(0xFFFF6B6B),
                    onTap: () async {
                      onClose();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.logOut,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          content: const Text(
                            'Are you sure you want to sign out of KeepSIMs?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D4D),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await HapticHelper.lightTick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
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
