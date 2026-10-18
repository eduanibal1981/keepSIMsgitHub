/// SIM Shield — Placeholder Screens
///
/// Temporary screens for GoRouter until real features are built.
/// Each will be replaced as its corresponding feature step is completed.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/dashboard/presentation/widgets/perspective_drawer.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/perspective_drawer_controller.dart';

// ── Splash Screen ─────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Fast check: if an accepted VoIP call is pending, bypass splash and navigate directly
    FlutterCallkitIncoming.activeCalls()
        .then((calls) {
          if (!mounted) return;
          for (final c in calls) {
            if (c.isAccepted) {
              final id = c.id;
              debugPrint(
                '[SplashScreen] Detected accepted call at launch: $id',
              );
              ref.read(splashCompletedProvider.notifier).complete();
              if (id.isNotEmpty) {
                context.go('${AppRoutes.voipCall}/$id');
              } else {
                _navigateToNext();
              }
              return;
            }
          }
        })
        .catchError((_) {});

    _videoController = VideoPlayerController.asset('assets/splashfastcp.mp4');

    // Mute video to bypass modern browser autoplay blocking rules (critical for Web)
    _videoController.setVolume(0.0);

    _videoController
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            _videoController.play();
          }
        })
        .catchError((error) {
          debugPrint('Splash video initialization failed: $error');
          _navigateToNext(); // Navigate immediately if load/init fails
        });

    _videoController.addListener(() {
      if (mounted) {
        final val = _videoController.value;
        // Fallback immediately if an error occurs during playback
        if (val.hasError) {
          debugPrint('Splash video playback error: ${val.errorDescription}');
          _navigateToNext();
          return;
        }
        // Ensure the video is initialized, has a valid duration, and has completed playing
        if (val.isInitialized &&
            val.duration > Duration.zero &&
            val.position >= val.duration) {
          _navigateToNext();
        }
      }
    });

    // Safety fallback timer: guarantee navigation after 3.5 seconds under all circumstances
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    if (mounted) {
      ref.read(splashCompletedProvider.notifier).complete();
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0A295A,
      ), // Matches the exact background color of presplash.png and splashfastcp.mp4
      body: Stack(
        children: [
          // 1. Full-screen Video Player (renders when initialized)
          if (_isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),

          // 2. Static presplash first-frame image (crossfades out once initialized)
          AnimatedOpacity(
            opacity: _isInitialized ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: SizedBox.expand(
              child: Image.asset(
                'assets/images/presplash.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
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
      backgroundColor: context.isDarkMode
          ? AppColors.darkBg
          : AppColors.lightBg,
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
    return const _PlaceholderPage(
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
    return const _PlaceholderPage(
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
    return const _PlaceholderPage(
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
    return const _PlaceholderPage(
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
    return const _PlaceholderPage(
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
    return const _PlaceholderPage(
      icon: Icons.settings_rounded,
      title: 'Settings',
      subtitle: 'Step 15 will build this',
    );
  }
}

// ── App Shell (Bottom Nav) ────────────────────────────────────
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int? _currentIndex(BuildContext context, WidgetRef ref) {
    final isDrawerOpen = ref.watch(perspectiveDrawerControllerProvider);
    if (isDrawerOpen) return 2;

    final location = GoRouterState.of(context).uri.path;
    if (location == AppRoutes.home || location == '${AppRoutes.home}/') {
      return 0;
    }
    if (location == AppRoutes.myNumbers ||
        location.startsWith('${AppRoutes.myNumbers}/')) {
      return null;
    }
    if (location == AppRoutes.calling ||
        location.startsWith('${AppRoutes.calling}/')) {
      return 1;
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIdx = _currentIndex(context, ref);
    final location = GoRouterState.of(context).uri.path;
    final isHome =
        location == AppRoutes.home || location == '${AppRoutes.home}/';

    return PopScope(
      canPop: isHome || Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final isDrawerOpen = ref.read(perspectiveDrawerControllerProvider);
          if (isDrawerOpen) {
            ref.read(perspectiveDrawerControllerProvider.notifier).close();
            return;
          }
          if (context.mounted && !isHome) {
            context.go(AppRoutes.home);
          }
        }
      },
      child: PerspectiveDrawerScaffold(
        child: Scaffold(
          body: child,
          bottomNavigationBar: AppBottomNavigationBar(
            selectedIndex: selectedIdx,
            onTap: (index) {
              switch (index) {
                case 0:
                  ref
                      .read(perspectiveDrawerControllerProvider.notifier)
                      .close();
                  context.go(AppRoutes.home);
                case 1:
                  ref
                      .read(perspectiveDrawerControllerProvider.notifier)
                      .close();
                  context.go(AppRoutes.calling);
                case 2:
                  ref
                      .read(perspectiveDrawerControllerProvider.notifier)
                      .toggle();
              }
            },
            items: [
              AppNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: AppLocalizations.of(context)!.navHome,
              ),
              AppNavigationBarItem(
                icon: const Icon(Icons.call_outlined),
                selectedIcon: const Icon(Icons.call_rounded),
                label: AppLocalizations.of(context)!.smartCall,
              ),
              AppNavigationBarItem(
                icon: const Icon(Icons.menu_rounded),
                selectedIcon: const Icon(Icons.menu_rounded),
                label: AppLocalizations.of(context)!.navMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Navigation ────────────────────────────────────────
class AppNavigationBarItem {
  final Widget icon;
  final Widget selectedIcon;
  final String label;
  const AppNavigationBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AppBottomNavigationBar extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onTap;
  final List<AppNavigationBarItem> items;
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final accent = dark ? AppColors.primary : const Color(0xFF009FB5);
    return Material(
      color: dark ? AppColors.darkSurface : Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.darkBorder : const Color(0xFFE2E8EF),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = selectedIndex == index;
                final color = selected
                    ? accent
                    : (dark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF7C879D));
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      onTap: () async {
                        await HapticHelper.lightTick();
                        onTap(index);
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconTheme(
                                data: IconThemeData(size: 24, color: color),
                                child: selected ? item.selectedIcon : item.icon,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontSize: 11,
                                  height: 1.25,
                                  color: color,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
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
