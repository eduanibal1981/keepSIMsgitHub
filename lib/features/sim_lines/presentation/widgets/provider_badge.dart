import 'package:flutter/material.dart';

/// Provider metadata representing top-up suppliers and their display abbreviations.
class ProviderInfo {
  final String code;
  final String name;
  final String abbreviation;
  final Color accentColor;

  const ProviderInfo({
    required this.code,
    required this.name,
    required this.abbreviation,
    required this.accentColor,
  });

  /// Full display name with abbreviation in parentheses, e.g. "DTone (DT)".
  String get displayNameWithAbbr => '$name ($abbreviation)';

  /// Abbreviation wrapped in parentheses, e.g. "(DT)".
  String get abbreviationWithParens => '($abbreviation)';

  /// Resolves [ProviderInfo] from a provider identifier string.
  static ProviderInfo? fromCode(String? providerCode) {
    if (providerCode == null || providerCode.trim().isEmpty) return null;
    final p = providerCode.toLowerCase().trim();

    if (p.contains('dtone') || p == 'dt' || p.contains('dt_')) {
      return const ProviderInfo(
        code: 'dtone',
        name: 'DTone',
        abbreviation: 'DT',
        accentColor: Color(0xFFA78BFA), // Lavender / Purple
      );
    }
    if (p.contains('ding') || p == 'dc' || p.contains('dingconnect')) {
      return const ProviderInfo(
        code: 'ding',
        name: 'dingConnect',
        abbreviation: 'DC',
        accentColor: Color(0xFF38BDF8), // Cyan / Sky Blue
      );
    }
    if (p.contains('zendit') || p == 'z' || p.contains('zen_')) {
      return const ProviderInfo(
        code: 'zendit',
        name: 'Zendit',
        abbreviation: 'Z',
        accentColor: Color(0xFF34D399), // Emerald / Mint Green
      );
    }
    if (p.contains('reloadly') || p == 'r') {
      return const ProviderInfo(
        code: 'reloadly',
        name: 'Reloadly',
        abbreviation: 'R',
        accentColor: Color(0xFFFB923C), // Coral / Orange
      );
    }

    // Generic fallback for any other or custom supplier
    final clean = providerCode.trim();
    final abbr = clean.length > 2
        ? clean.substring(0, 2).toUpperCase()
        : clean.toUpperCase();
    return ProviderInfo(
      code: p,
      name: clean,
      abbreviation: abbr,
      accentColor: const Color(0xFF94A3B8), // Slate
    );
  }
}

/// A compact, styled badge to indicate the source provider of an offer.
class ProviderBadge extends StatelessWidget {
  final String? provider;
  final bool showFullName;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ProviderBadge({
    super.key,
    required this.provider,
    this.showFullName = true,
    this.fontSize = 9.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final info = ProviderInfo.fromCode(provider);
    if (info == null) return const SizedBox.shrink();

    final label = showFullName ? info.displayNameWithAbbr : '(${info.abbreviation})';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: info.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: info.accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: info.accentColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
