import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';

class GlassToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const GlassToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.secondary;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () {
        if (onChanged != null) {
          onChanged!(!value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? color.withOpacity(isLight ? 0.15 : 0.2)
              : (isLight ? const Color(0xFFEAEEF1) : AppColors.darkCard),
          border: Border.all(
            color: value
                ? color.withOpacity(isLight ? 0.3 : 0.5)
                : (isLight ? AppColors.lightBorder : AppColors.darkBorder),
            width: 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: color.withOpacity(isLight ? 0.12 : 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? color
                  : (isLight
                        ? AppColors.textTertiaryLight
                        : AppColors.textTertiaryDark),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
