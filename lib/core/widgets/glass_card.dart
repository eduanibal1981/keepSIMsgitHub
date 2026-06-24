import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final Color? activeColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? width;
  final double? height;
  final Gradient? customGradient;
  final BoxBorder? customBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.isActive = false,
    this.activeColor,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.borderRadius = 24.0,
    this.width,
    this.height,
    this.customGradient,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = activeColor ?? AppColors.primary;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(isLight ? 0.08 : 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: customGradient ?? (isLight
                  ? const LinearGradient(
                      colors: [Color(0xCCFFFFFF), Color(0xB3FFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppColors.darkCardGradient),
              borderRadius: BorderRadius.circular(borderRadius),
              border: customBorder ?? Border.all(
                color: isActive
                    ? glowColor.withValues(alpha: isLight ? 0.3 : 0.5)
                    : (isLight
                          ? AppColors.lightBorderSoft
                          : AppColors.darkBorder),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
