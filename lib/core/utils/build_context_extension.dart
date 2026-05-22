import 'package:flutter/material.dart';

extension BuildContextThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  bool get isDarkMode => theme.brightness == Brightness.dark;

  Color get surfaceColor => colorScheme.surface;
  Color get onSurfaceColor => colorScheme.onSurface;
  Color get primaryColor => colorScheme.primary;
  Color get scaffoldBackgroundColor => theme.scaffoldBackgroundColor;
  Color get cardColor => theme.cardColor;
  Color get dividerColor => theme.dividerTheme.color ?? theme.dividerColor;
}
