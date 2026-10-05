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
    final isHome = location == AppRoutes.home || location == '${AppRoutes.home}/';

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
          bottomNavigationBar: CurvedBottomNavigationBar(
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
              CurvedNavigationBarItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: AppLocalizations.of(context)!.navHome,
              ),
              CurvedNavigationBarItem(
                icon: Icons.phone_outlined,
                selectedIcon: Icons.phone_rounded,
                label: AppLocalizations.of(context)!.smartCall,
              ),
              CurvedNavigationBarItem(
                icon: Icons.menu_rounded,
                selectedIcon: Icons.menu_rounded,
                label: AppLocalizations.of(context)!.navMore,
              ),
            ],
          ),
        ),
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
  final double cutoutProgress;
  final int itemCount;
  final Color backgroundColor;
  final Color borderColor;
  final TextDirection textDirection;

  CurvedNavigationBarPainter({
    required this.activeIndex,
    required this.cutoutProgress,
    required this.itemCount,
    required this.backgroundColor,
    required this.borderColor,
    required this.textDirection,
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
    final isRtl = textDirection == TextDirection.rtl;
    final effectiveIndex = isRtl ? (itemCount - 1 - activeIndex) : activeIndex;
    final x = (effectiveIndex + 0.5) * singleWidth;

    const R = 38.0; // Radius of cutout
    const D = 25.0; // Depth of cutout
    const cornerRadius = 24.0;

    final currentR = R * cutoutProgress;
    final currentD = D * cutoutProgress;

    // Background Top-left corner
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    if (cutoutProgress > 0.005) {
      // Line to start of cutout dip
      path.lineTo(x - currentR, 0);

      // Smooth Bezier Curve dip
      path.cubicTo(
        x - currentR + (10 * cutoutProgress),
        0,
        x - currentR + (6 * cutoutProgress),
        currentD,
        x,
        currentD,
      );
      path.cubicTo(
        x + currentR - (6 * cutoutProgress),
        currentD,
        x + currentR - (10 * cutoutProgress),
        0,
        x + currentR,
        0,
      );
    }

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

    if (cutoutProgress > 0.005) {
      borderPath.lineTo(x - currentR, 0);
      borderPath.cubicTo(
        x - currentR + (10 * cutoutProgress),
        0,
        x - currentR + (6 * cutoutProgress),
        currentD,
        x,
        currentD,
      );
      borderPath.cubicTo(
        x + currentR - (6 * cutoutProgress),
        currentD,
        x + currentR - (10 * cutoutProgress),
        0,
        x + currentR,
        0,
      );
    }

    borderPath.lineTo(width - cornerRadius, 0);
    borderPath.quadraticBezierTo(width, 0, width, cornerRadius);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CurvedNavigationBarPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.cutoutProgress != cutoutProgress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.textDirection != textDirection;
  }
}

// ── Premium Curved Bottom Navigation Bar ──────────────────────
class CurvedBottomNavigationBar extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onTap;
  final List<CurvedNavigationBarItem> items;

  const CurvedBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<CurvedBottomNavigationBar> createState() =>
      _CurvedBottomNavigationBarState();
}

class _CurvedBottomNavigationBarState extends State<CurvedBottomNavigationBar>
    with TickerProviderStateMixin {
  late AnimationController _posController;
  late Animation<double> _posAnimation;

  late AnimationController _cutoutController;
  late Animation<double> _cutoutAnimation;

  late int _lastValidIndex;

  @override
  void initState() {
    super.initState();
    final hasSelection = widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < widget.items.length;
    _lastValidIndex = hasSelection ? widget.selectedIndex! : 0;

    _posController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _posAnimation = Tween<double>(
      begin: _lastValidIndex.toDouble(),
      end: _lastValidIndex.toDouble(),
    ).animate(
      CurvedAnimation(parent: _posController, curve: Curves.easeOutCubic),
    );

    _cutoutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: hasSelection ? 1.0 : 0.0,
    );
    _cutoutAnimation = CurvedAnimation(
      parent: _cutoutController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant CurvedBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewSelection = widget.selectedIndex != null &&
        widget.selectedIndex! >= 0 &&
        widget.selectedIndex! < widget.items.length;
    final hadOldSelection = oldWidget.selectedIndex != null &&
        oldWidget.selectedIndex! >= 0 &&
        oldWidget.selectedIndex! < oldWidget.items.length;

    if (hasNewSelection) {
      final newIndex = widget.selectedIndex!;
      _lastValidIndex = newIndex;

      if (!hadOldSelection) {
        // Was inactive, now active at newIndex
        _posAnimation = Tween<double>(
          begin: newIndex.toDouble(),
          end: newIndex.toDouble(),
        ).animate(
          CurvedAnimation(parent: _posController, curve: Curves.easeOutCubic),
        );
        _posController.value = 1.0;
        _cutoutController.forward();
      } else if (oldWidget.selectedIndex != newIndex) {
        // Animated between two active tabs
        _posAnimation = Tween<double>(
          begin: _posAnimation.value,
          end: newIndex.toDouble(),
        ).animate(
          CurvedAnimation(parent: _posController, curve: Curves.easeOutCubic),
        );
        _posController.forward(from: 0.0);
        if (_cutoutController.value < 1.0) {
          _cutoutController.forward();
        }
      }
    } else {
      // Now inactive
      if (hadOldSelection) {
        _cutoutController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _posController.dispose();
    _cutoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final width = MediaQuery.of(context).size.width;
    final singleWidth = width / widget.items.length;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnimatedBuilder(
      animation: Listenable.merge([_posAnimation, _cutoutAnimation]),
      builder: (context, child) {
        final effectiveIndex = isRtl
            ? (widget.items.length - 1 - _posAnimation.value)
            : _posAnimation.value;

        final cutoutVal = _cutoutAnimation.value;

        return Container(
          height: 85.0 + bottomPadding,
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom Bezier Paint Background Bar
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CurvedNavigationBarPainter(
                      activeIndex: _posAnimation.value,
                      cutoutProgress: cutoutVal,
                      itemCount: widget.items.length,
                      backgroundColor: context.surfaceColor,
                      borderColor: context.onSurfaceColor.withValues(
                        alpha: 0.08,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),

              // Floating Active Icon Circle with glow shadow
              if (cutoutVal > 0.005)
                Positioned(
                  left:
                      (effectiveIndex + 0.5) * singleWidth -
                      30, // center 60px wide circle
                  top: -15 * cutoutVal, // float elevated
                  child: Opacity(
                    opacity: cutoutVal.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: cutoutVal.clamp(0.0, 1.0),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: 0.35 * cutoutVal.clamp(0.0, 1.0),
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.items[_lastValidIndex].selectedIcon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Inactive Icons & Text Labels Row
              Positioned.fill(
                child: Row(
                  children: List.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final isSelected = widget.selectedIndex != null &&
                        index == widget.selectedIndex;

                    // Calculate distance to active index to fade out standard icon
                    final distance = (index - _posAnimation.value).abs();
                    final baseDistanceOpacity = (distance * 1.5).clamp(0.0, 1.0);
                    final opacity =
                        (1.0 - (1.0 - baseDistanceOpacity) * cutoutVal).clamp(
                          0.0,
                          1.0,
                        );

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
                                color: context.onSurfaceColor.withValues(
                                  alpha: 0.6,
                                ),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Text Label
                            Text(
                              item.label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isSelected
                                    ? (context.isDarkMode
                                          ? AppColors.primaryLight
                                          : context.primaryColor)
                                    : context.onSurfaceColor.withValues(
                                        alpha: 0.4,
                                      ),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            SizedBox(height: 12.0 + bottomPadding),
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
