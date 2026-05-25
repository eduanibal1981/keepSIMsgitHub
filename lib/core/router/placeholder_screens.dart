/// SIM Shield — Placeholder Screens
///
/// Temporary screens for GoRouter until real features are built.
/// Each will be replaced as its corresponding feature step is completed.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';

// ── Splash Screen ─────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // Navigate after splash animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // TODO: Replace with auth check — go to login or home
        context.go(AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shield icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SIM Shield',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Protect your SIM, wherever you are.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Login Placeholder ─────────────────────────────────────────
class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to SIM Shield',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to protect your SIM cards',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in with Google'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Onboarding Placeholder ────────────────────────────────────
class OnboardingPlaceholder extends StatelessWidget {
  const OnboardingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.rocket_launch_rounded,
      title: 'Onboarding',
      subtitle: 'Step 4 will build this',
    );
  }
}

// ── Home Placeholder ──────────────────────────────────────────
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard',
      subtitle: 'Step 5 will build this',
    );
  }
}

// ── SIM Lines Placeholder ─────────────────────────────────────
class SimLinesPlaceholder extends StatelessWidget {
  const SimLinesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.sim_card_rounded,
      title: 'My SIM Lines',
      subtitle: 'Step 6 will build this',
    );
  }
}

// ── Wallet Placeholder ────────────────────────────────────────
class WalletPlaceholder extends StatelessWidget {
  const WalletPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Wallet',
      subtitle: 'Step 7 will build this',
    );
  }
}

// ── Notifications Placeholder ─────────────────────────────────
class NotificationsPlaceholder extends StatelessWidget {
  const NotificationsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      subtitle: 'Step 10 will build this',
    );
  }
}

// ── Settings Placeholder ──────────────────────────────────────
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderPage(
      icon: Icons.settings_rounded,
      title: 'Settings',
      subtitle: 'Step 15 will build this',
    );
  }
}

// ── App Shell (Bottom Nav) ────────────────────────────────────
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/notifications')) return 0; // Alerts is in Home header
    if (location.startsWith('/wallet')) return 1;
    if (location.startsWith('/settings')) return 2;
    if (location.startsWith('/sim-lines')) return 2; // Under More menu
    if (location.startsWith('/household')) return 2; // Under More menu
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: CurvedBottomNavigationBar(
        selectedIndex: _currentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.home);
            case 1:
              context.go(AppRoutes.wallet);
            case 2:
              context.go(AppRoutes.settings);
          }
        },
        items: const [
          CurvedNavigationBarItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          CurvedNavigationBarItem(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
          ),
          CurvedNavigationBarItem(
            icon: Icons.menu_rounded,
            selectedIcon: Icons.menu_rounded,
            label: 'More',
          ),
        ],
      ),
    );
  }
}

// ── Curved Navigation Item Model ─────────────────────────────
class CurvedNavigationBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const CurvedNavigationBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ── Custom Curved Navigation Bar Painter ──────────────────────
class CurvedNavigationBarPainter extends CustomPainter {
  final double activeIndex;
  final int itemCount;
  final Color backgroundColor;
  final Color borderColor;

  CurvedNavigationBarPainter({
    required this.activeIndex,
    required this.itemCount,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final singleWidth = width / itemCount;

    // Calculate animated center X position of active tab
    final x = (activeIndex + 0.5) * singleWidth;

    const R = 38.0; // Radius of cutout
    const D = 25.0; // Depth of cutout
    const cornerRadius = 24.0;

    // Background Top-left corner
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Line to start of cutout dip
    path.lineTo(x - R, 0);

    // Smooth Bezier Curve dip
    path.cubicTo(
      x - R + 10, 0,
      x - R + 6, D,
      x, D,
    );
    path.cubicTo(
      x + R - 6, D,
      x + R - 10, 0,
      x + R, 0,
    );

    // Line to top-right corner
    path.lineTo(width - cornerRadius, 0);
    path.quadraticBezierTo(width, 0, width, cornerRadius);

    // Complete background perimeter (right edge, bottom edge, left edge)
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Draw custom soft elevation shadow
    canvas.drawShadow(
      path.shift(const Offset(0, -1)),
      Colors.black.withValues(alpha: 0.35),
      12,
      true,
    );

    // Paint background surface
    canvas.drawPath(path, paint);

    // Draw active top-border curve only
    final borderPath = Path();
    borderPath.moveTo(0, cornerRadius);
    borderPath.quadraticBezierTo(0, 0, cornerRadius, 0);
    borderPath.lineTo(x - R, 0);
    borderPath.cubicTo(
      x - R + 10, 0,
      x - R + 6, D,
      x, D,
    );
    borderPath.cubicTo(
      x + R - 6, D,
      x + R - 10, 0,
      x + R, 0,
    );
    borderPath.lineTo(width - cornerRadius, 0);
    borderPath.quadraticBezierTo(width, 0, width, cornerRadius);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CurvedNavigationBarPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}

// ── Premium Curved Bottom Navigation Bar ──────────────────────
class CurvedBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final List<CurvedNavigationBarItem> items;

  const CurvedBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<CurvedBottomNavigationBar> createState() => _CurvedBottomNavigationBarState();
}

class _CurvedBottomNavigationBarState extends State<CurvedBottomNavigationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = Tween<double>(
      begin: widget.selectedIndex.toDouble(),
      end: widget.selectedIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant CurvedBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final singleWidth = width / widget.items.length;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final activeX = (_animation.value + 0.5) * singleWidth;

        return Container(
          height: 85,
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom Bezier Paint Background Bar
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CurvedNavigationBarPainter(
                      activeIndex: _animation.value,
                      itemCount: widget.items.length,
                      backgroundColor: context.surfaceColor,
                      borderColor: context.onSurfaceColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),

              // Floating Active Icon Circle with glow shadow
              Positioned(
                left: activeX - 30, // center 60px wide circle
                top: -15, // float elevated
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.items[widget.selectedIndex].selectedIcon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),

              // Inactive Icons & Text Labels Row
              Positioned.fill(
                child: Row(
                  children: List.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final isSelected = index == widget.selectedIndex;

                    // Calculate distance to active index to fade out standard icon
                    final distance = (index - _animation.value).abs();
                    final opacity = (distance * 1.5).clamp(0.0, 1.0);

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await HapticHelper.lightTick();
                          widget.onTap(index);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(height: 20),
                            // Inactive normal icon
                            Opacity(
                              opacity: opacity,
                              child: Icon(
                                item.icon,
                                color: context.onSurfaceColor.withValues(alpha: 0.6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Text Label
                            Text(
                              item.label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : context.onSurfaceColor.withValues(alpha: 0.4),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable Placeholder Widget ───────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
