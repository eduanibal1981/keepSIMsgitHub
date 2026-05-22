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
import 'package:keep_sims/core/utils/theme_extension.dart';

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
    if (location.startsWith('/sim-lines')) return 1;
    if (location.startsWith('/wallet')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.onSurfaceColor.withValues(alpha: 0.1), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex(context),
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go(AppRoutes.home);
              case 1:
                context.go(AppRoutes.simLines);
              case 2:
                context.go(AppRoutes.wallet);
              case 3:
                context.go(AppRoutes.notifications);
              case 4:
                context.go(AppRoutes.settings);
            }
          },
          backgroundColor: context.surfaceColor,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: context.onSurfaceColor.withValues(alpha: 0.6)),
              selectedIcon: const Icon(
                Icons.dashboard_rounded,
                color: AppColors.primary,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sim_card_outlined, color: context.onSurfaceColor.withValues(alpha: 0.6)),
              selectedIcon: const Icon(
                Icons.sim_card_rounded,
                color: AppColors.primary,
              ),
              label: 'SIM Lines',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: context.onSurfaceColor.withValues(alpha: 0.6)),
              selectedIcon: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined, color: context.onSurfaceColor.withValues(alpha: 0.6)),
              selectedIcon: const Icon(
                Icons.notifications_rounded,
                color: AppColors.primary,
              ),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: context.onSurfaceColor.withValues(alpha: 0.6)),
              selectedIcon: const Icon(
                Icons.settings_rounded,
                color: AppColors.primary,
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
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
