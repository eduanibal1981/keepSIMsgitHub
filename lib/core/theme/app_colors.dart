/// SIM Shield — App Color Palette
///
/// Premium dark-mode-first color scheme with vibrant accent colors.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand Colors ──────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF); // Vivid indigo
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42DB);

  static const Color secondary = Color(0xFF00D9A6); // Teal/mint accent
  static const Color secondaryLight = Color(0xFF5EFFD4);
  static const Color secondaryDark = Color(0xFF00A67D);

  // ── Status / Health Score Colors ──────────────────────────
  static const Color healthGreen = Color(0xFF4ADE80); // Safe (>60)
  static const Color healthAmber = Color(0xFFFBBF24); // Caution (30-60)
  static const Color healthRed = Color(0xFFEF4444); // Critical (<30)

  // ── Semantic Colors ───────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Dark Theme Surfaces ───────────────────────────────────
  /// Dark background color
  static const Color darkBg = Color(0xFF1A1A2E);
  static const Color darkSurface = Color.fromARGB(255, 56, 8, 88);
  static const Color darkCard = Color(0xFF222240);
  static const Color darkCardHover = Color(0xFF2A2A4A);
  static const Color darkBorder = Color(0xFF2D2D4D);

  // ── Light Theme Surfaces ──────────────────────────────────
  static const Color lightBg = Color.fromARGB(255, 151, 193, 230);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ── Text Colors ───────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF6B7280);

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondary, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkCard, Color(0xFF1E1E38)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
