/// SIM Shield — App Color Palette
///
/// Premium dark-mode-first color scheme with glassmorphism support.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand Colors ──────────────────────────────────────────
  static const Color primary = Color(0xFF4CD7F6); // Neon Cyan
  static const Color primaryLight = Color(0xFFACEDFF);
  static const Color primaryDark = Color(0xFF00687A);

  static const Color secondary = Color(0xFF4EDEA3); // Neon Green
  static const Color secondaryLight = Color(0xFF6FFBBE);
  static const Color secondaryDark = Color(0xFF00A572);

  static const Color tertiary = Color(0xFFFFB95F); // Neon Amber

  // ── Status / Health Score Colors ──────────────────────────
  static const Color healthGreen = Color(0xFF4EDEA3); // Safe
  static const Color healthAmber = Color(0xFFFFB95F); // Caution
  static const Color healthRed = Color(0xFFFFB4AB); // Critical

  // ── Semantic Colors ───────────────────────────────────────
  static const Color success = Color(0xFF4EDEA3);
  static const Color warning = Color(0xFFFFB95F);
  static const Color error = Color(0xFFFFB4AB);
  static const Color info = Color(0xFF4CD7F6);

  // ── Dark Theme Surfaces (Glassmorphism) ───────────────────
  /// Dark background color
  static const Color darkBg = Color(0xFF0D141D);
  static const Color darkSurface = Color(0xFF192029);

  // Glass card uses #15181E at 60% opacity with 16px blur
  static const Color darkCard = Color(0x9915181E);
  static const Color darkCardHover = Color(0xFF232A34);
  static const Color darkBorder = Color(0x1AFFFFFF); // 10% white opacity

  // ── Light Theme Brand & Surface Colors (Stitch Light Theme) ────
  static const Color lightPrimary = Color(0xFF00647C); // Deep Teal/Cyan
  static const Color lightPrimaryMid = Color(0xFF007F9D); // Mid Teal/Cyan
  static const Color lightPrimaryDark = Color(0xFF004E61); // Dark Teal/Cyan
  static const Color lightSecondary = Color(0xFF006C4A); // Deep Green
  static const Color lightSuccess = Color(0xFF006C4A);
  static const Color lightWarning = Color(0xFF894E00); // Amber

  static const Color lightBg = Color(0xFFF6FAFD); // Soft light blue-gray
  static const Color lightSurface = Color(0xFFF6FAFD);
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white card
  static const Color lightBorder = Color(0xFFBDC8CE); // Outline variant
  static const Color lightBorderSoft = Color(
    0x3300647C,
  ); // 20% opacity primary border

  // ── Text Colors ───────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFDCE3F0);
  static const Color textTertiaryDark = Color(0xFFBCC9CD);

  static const Color textPrimaryLight = Color(0xFF171C1E); // on-surface
  static const Color textSecondaryLight = Color(
    0xFF3E484D,
  ); // on-surface-variant
  static const Color textTertiaryLight = Color(0xFF6E797E); // outline

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondary, Color(0xFF00A572)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4CD7F6), Color(0xFF06B6D4), Color(0xFF4EDEA3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0x9915181E), Color(0x990D141D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
