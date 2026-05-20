import 'package:flutter/services.dart';

/// A centralized tactile engine helper that orchestrates native vibrations safely.
abstract final class HapticHelper {
  /// Simple soft tick for slider indices, dial buttons, or navigation tabs.
  static Future<void> lightTick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Medium mechanical thump for opening dialogue menus or editing thresholds.
  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Strong confirmation pulse for Face ID lock pairings or payment complete scans.
  static Future<void> successFeedback() async {
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Double buzzing thud for compiler faults or security dial PIN rejections.
  static Future<void> errorFeedback() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
