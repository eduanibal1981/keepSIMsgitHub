import 'package:flutter/material.dart';

/// Illustrated entry points to the existing paid and app-to-app call flows.
class CallingOptionsSection extends StatelessWidget {
  const CallingOptionsSection({
    super.key,
    required this.onDialerTap,
    required this.onFreeCallTap,
  });

  final VoidCallback onDialerTap;
  final VoidCallback onFreeCallTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How would you like to call?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF080D36),
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            // Give larger accessibility text the full width of each card.
            final stacked =
                constraints.maxWidth < 300 ||
                (MediaQuery.textScalerOf(context).scale(14) > 20 &&
                    constraints.maxWidth < 500);
            final dialer = _CallingOptionCard(
              fillHeight: !stacked,
              iconAsset: 'assets/icons/call_dialer.png',
              title: 'International\nCalls',
              description:
                  'Call international mobiles and landlines at low rates.',
              buttonLabel: 'Call with Dialer',
              accent: const Color(0xFF1685FF),
              gradient: const [Color(0xFF34B7FF), Color(0xFF0754FF)],
              onTap: onDialerTap,
            );
            final freeCall = _CallingOptionCard(
              fillHeight: !stacked,
              iconAsset: 'assets/icons/free_app_call.png',
              title: 'Free Call',
              description: 'KeepSIMs to KeepSIMs over Wi-Fi or mobile data.',
              buttonLabel: 'Call free',
              accent: const Color(0xFF00C78A),
              gradient: const [Color(0xFF0DDC91), Color(0xFF00A879)],
              onTap: onFreeCallTap,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [dialer, const SizedBox(height: 16), freeCall],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: dialer),
                  const SizedBox(width: 14),
                  Expanded(child: freeCall),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CallingOptionCard extends StatelessWidget {
  const _CallingOptionCard({
    required this.fillHeight,
    required this.iconAsset,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.accent,
    required this.gradient,
    required this.onTap,
  });

  final bool fillHeight;
  final String iconAsset;
  final String title;
  final String description;
  final String buttonLabel;
  final Color accent;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF121F34), const Color(0xFF0F1A2E)]
              : [Colors.white, Color.lerp(Colors.white, accent, 0.025)!],
        ),
        border: Border.all(
          color: isDark ? accent.withValues(alpha: 0.18) : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.09),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipOval(
                child: Image.asset(
                  iconAsset,
                  fit: BoxFit.contain,
                  cacheWidth: 690,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: textScale.scale(20) * 2.3),
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF080D36),
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFB6C3D6) : const Color(0xFF606570),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (fillHeight) const Spacer(),
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.2)),
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF16253A) : Colors.white,
                border: Border.all(color: accent.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                child: IconButton(
                  onPressed: onTap,
                  tooltip: buttonLabel,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(
                    Icons.call_rounded,
                    size: 30,
                    semanticLabel: buttonLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
