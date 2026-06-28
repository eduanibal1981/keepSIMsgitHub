/// SIM Shield — Login Screen (Welcome)
///
/// Premium auth screen based on the Stitch "SIM Shield - Welcome (Light)" design.
/// Features branded hero, social sign-in, feature grid, and system status footer.
/// Uses ConsumerStatefulWidget for auth state + animation control.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/theme/app_text_styles.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/core/router/app_router.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Fade-in animation for the whole page
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Slide-up animation for the action section
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Pulse animation for the encrypted badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDark = context.isDarkMode;
    final size = MediaQuery.of(context).size;

    // Listen for errors and show snackbar
    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────
              _buildTopBar(isDark),

              // ── Main Content ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // ── Hero Headline ──────────────────────────
                        _buildHeroHeadline(isDark),
                        const SizedBox(height: 12),

                        // ── Subtitle ───────────────────────────────
                        _buildSubtitle(isDark),
                        const SizedBox(height: 32),

                        // ── Auth Buttons ───────────────────────────
                        _buildAuthButtons(authState, isDark),
                        const SizedBox(height: 28),

                        // ── Feature Grid ───────────────────────────
                        _buildFeatureGrid(isDark),
                        const SizedBox(height: 28),

                        // ── Hero Image ─────────────────────────────
                        _buildHeroImage(isDark, size),
                        const SizedBox(height: 24),

                        // ── System Status ──────────────────────────
                        _buildSystemStatus(isDark),
                        const SizedBox(height: 16),

                        // ── Footer Links ───────────────────────────
                        _buildFooterLinks(isDark),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────

  Widget _buildTopBar(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Shield icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primary : AppColors.lightPrimary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shield,
              size: 20,
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SIM Shield',
            style: AppTextStyles.headlineSmall.copyWith(
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Help icon
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              size: 22,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── Hero Headline ──────────────────────────────────────────────

  Widget _buildHeroHeadline(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Secure Your',
          style: AppTextStyles.displayLarge.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            height: 1.15,
          ),
        ),
        Text(
          'Digital Boundary',
          style: AppTextStyles.displayLarge.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.primary : AppColors.lightPrimary,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  // ── Subtitle ───────────────────────────────────────────────────

  Widget _buildSubtitle(bool isDark) {
    return Text(
      'Professional-grade protection for your digital identity and hardware. '
      'Prevent SIM swapping and secure your core communications.',
      style: AppTextStyles.bodyLarge.copyWith(
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        height: 1.6,
      ),
    );
  }

  // ── Auth Buttons ───────────────────────────────────────────────

  Widget _buildAuthButtons(AsyncValue authState, bool isDark) {
    return Column(
      children: [
        // ── Google Sign-In ─────────────────────────────────────
        _SocialButton(
          onPressed: authState.isLoading
              ? null
              : () => ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle(),
          icon: const _GoogleLogo(),
          label: 'Continue with Google',
          isDark: isDark,
          isLoading: authState.isLoading,
        ),
        const SizedBox(height: 12),

        // ── Apple Sign-In ──────────────────────────────────────
        _SocialButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Apple Sign-In will be available soon!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: Icon(
            Icons.apple,
            size: 22,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          label: 'Continue with Apple',
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ── OR Divider ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Email Sign-In Link ─────────────────────────────────
        TextButton(
          onPressed: () => context.go(AppRoutes.emailAuth),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            'Sign in/up through email instead',
            style: AppTextStyles.labelLarge.copyWith(
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Feature Grid ───────────────────────────────────────────────

  Widget _buildFeatureGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _FeatureTile(
            icon: Icons.security_rounded,
            title: 'End-to-End',
            subtitle: 'Zero-knowledge identity vaults.',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _FeatureTile(
            icon: Icons.sensors_rounded,
            title: 'Live Monitoring',
            subtitle: '24/7 hardware integrity checks.',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── Hero Image ─────────────────────────────────────────────────

  Widget _buildHeroImage(bool isDark, Size screenSize) {
    return Container(
      width: double.infinity,
      height: screenSize.height * 0.28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image asset
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/images/Logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.darkSurface,
                              AppColors.primary.withValues(alpha: 0.15),
                            ]
                          : [
                              AppColors.lightSurface,
                              AppColors.lightPrimary.withValues(alpha: 0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shield_rounded,
                      size: 80,
                      color: (isDark
                              ? AppColors.primary
                              : AppColors.lightPrimary)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                );
              },
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    (isDark ? AppColors.darkBg : AppColors.lightBg)
                        .withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Floating "Hardware-level Encrypted" badge
          Positioned(
            bottom: 12,
            left: 12,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.85 + (_pulseController.value * 0.15),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.primary
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hardware-level Encrypted',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.primary
                            : AppColors.lightPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── System Status ──────────────────────────────────────────────

  Widget _buildSystemStatus(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard
              : AppColors.lightBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing green dot
            _PulsingDot(
              color: isDark ? AppColors.primary : AppColors.lightPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              'System Operational: ',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 11,
              ),
            ),
            Text(
              'All Nodes Secure',
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.primary : AppColors.lightPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer Links ───────────────────────────────────────────────

  Widget _buildFooterLinks(bool isDark) {
    final linkStyle = AppTextStyles.caption.copyWith(
      color: isDark
          ? AppColors.textTertiaryDark
          : AppColors.textTertiaryLight,
      fontSize: 11,
      decoration: TextDecoration.underline,
      decorationColor: isDark
          ? AppColors.darkBorder
          : AppColors.lightBorder,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Privacy Policy', style: linkStyle),
            ),
            Text(
              '  ·  ',
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 11,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Terms of Service', style: linkStyle),
            ),
            Text(
              '  ·  ',
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 11,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Help Center', style: linkStyle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© 2024 SIM Shield. All rights reserved.',
          style: AppTextStyles.caption.copyWith(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ── Reusable Sub-Widgets ────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════

/// Social sign-in button matching the Stitch design.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isDark,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool isDark;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          foregroundColor: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark ? AppColors.primary : AppColors.lightPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: icon),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Feature tile for the grid section.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: isDark ? AppColors.primary : AppColors.lightPrimary,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

/// Pulsing dot for the system status badge.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: (1.0 - _controller.value) * 0.4,
                  ),
                ),
              );
            },
          ),
          // Solid center dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google "G" Logo (pure Flutter paint) ──────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Blue arc (top-right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), -0.6, 1.8, true, bluePaint);

    // Green arc (bottom-right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 1.2, 1.2, true, greenPaint);

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 2.4, 1.0, true, yellowPaint);

    // Red arc (top-left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h), 3.4, 1.2, true, redPaint);

    // White center
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.32, centerPaint);

    // Blue "bar" extending right
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, h * 0.38, w * 0.45, h * 0.24),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Feature Chip Widget (kept for backward compatibility) ─────
class FeatureChip extends StatelessWidget {
  const FeatureChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}
