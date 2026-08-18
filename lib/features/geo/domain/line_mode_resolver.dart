/// Derives one line's home/travel state from the country the user is actually
/// standing in.
///
/// `is_home_mode` is a **location fact about the line**: the user is inside
/// *this SIM's* country. It is not the account's `profiles.home_country_code`,
/// and it is not a preference. Confusing the two is what labelled a Saudi
/// (+966) line "Home Mode" for an owner sitting in Oman whose profile home is
/// Egypt — and, through the B5 derivation below, paused the protection that
/// line had been paid for. Three different countries were in play and the code
/// compared the wrong pair.
///
/// The intent that follows from the fact is `protection_paused`, unless the
/// line opted out with `requires_protection_at_home` (a resident's dormant
/// second SIM, which dies if its refills stop).
library;

/// What a line's two mode columns should become. Only ever produced when at
/// least one of them differs from what is stored.
class LineModeDecision {
  const LineModeDecision({
    required this.isHomeMode,
    required this.protectionPaused,
  });

  final bool isHomeMode;
  final bool protectionPaused;

  @override
  bool operator ==(Object other) =>
      other is LineModeDecision &&
      other.isHomeMode == isHomeMode &&
      other.protectionPaused == protectionPaused;

  @override
  int get hashCode => Object.hash(isHomeMode, protectionPaused);

  @override
  String toString() =>
      'LineModeDecision(isHomeMode: $isHomeMode, protectionPaused: $protectionPaused)';
}

/// Returns the state to write, or `null` when nothing should be written.
///
/// `null` covers three cases that must all stay writes-free:
///  * the location did not resolve — a guess would flip a paying line's
///    protection on a failed IP lookup;
///  * the line has no country on file — there is nothing to compare against;
///  * the stored row already agrees.
LineModeDecision? resolveLineMode({
  required String? detectedIso,
  required String? lineCountryIso,
  required bool isHomeMode,
  required bool protectionPaused,
  required bool requiresProtectionAtHome,
}) {
  final detected = detectedIso?.trim().toUpperCase();
  final lineCountry = lineCountryIso?.trim().toUpperCase();
  // 'XX' is the edge header's own "unknown" marker; refused here too so it
  // cannot become a country that nothing matches and therefore reads as
  // "everything is Travel Mode".
  if (detected == null || detected.length != 2 || detected == 'XX') return null;
  if (lineCountry == null || lineCountry.length != 2) return null;

  final nextHome = detected == lineCountry;
  final nextPaused = nextHome && !requiresProtectionAtHome;

  if (nextHome == isHomeMode && nextPaused == protectionPaused) return null;
  return LineModeDecision(isHomeMode: nextHome, protectionPaused: nextPaused);
}
