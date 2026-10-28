/// Retail facts only. Missing provider values remain unknown, including on old rows.
class EsimCatalogueDetails {
  const EsimCatalogueDetails(this.values);
  final Map<String, dynamic> values;

  String? text(String key) {
    final value = values[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String get planType => text('plan_type') ?? 'unknown';
  bool get isDaily => planType.startsWith('daily_');
  String get typeLabel => switch (planType) {
    'total' => 'Total data bundle',
    'daily_throttled' => 'Daily allowance with slowing',
    'daily_cutoff' => 'Daily allowance with cut-off',
    'daily_unlimited' => 'Daily unlimited',
    _ => 'Not provided',
  };

  static String formatBytes(int bytes) {
    final gib = bytes / 1073741824;
    if (gib >= 1) return '${_number(gib)} GB';
    return '${_number(bytes / 1048576)} MB';
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

  int? get allowanceBytes => int.tryParse('${values['allowance_bytes']}');
  String formattedData({required int legacyMb, required bool unlimited}) {
    if (planType == 'daily_unlimited') return 'Unlimited/day';
    if (unlimited) return 'Unlimited';
    final bytes = allowanceBytes;
    final amount = bytes != null && bytes > 0
        ? formatBytes(bytes)
        : legacyMb > 0
        ? formatBytes(legacyMb * 1048576)
        : 'Not provided';
    return isDaily && amount != 'Not provided' ? '$amount/day' : amount;
  }

  String get activationLabel => switch (text('activation_trigger')) {
    'installation' => 'Validity starts on first installation',
    'first_network_connection' => 'Validity starts on first network connection',
    _ => 'Not provided',
  };

  String get unusedValidityLabel {
    final value = values['unused_validity_value'];
    final unit = text('unused_validity_unit');
    if (value is! num || value <= 0 || unit == null) return 'Not provided';
    return 'Activate within $value ${unit.toLowerCase()}${value == 1 ? '' : 's'} of purchase';
  }

  String durationLabel(int legacyDays) {
    final value = values['duration_value'];
    final unit = text('duration_unit');
    if (value is num && value > 0 && unit != null) {
      return '$value ${unit.toLowerCase()}${value == 1 ? '' : 's'}';
    }
    return legacyDays > 0 ? '$legacyDays days' : 'Not provided';
  }

  String get rechargeLabel => switch (text('topup_support')) {
    'unsupported' => 'This plan does not support recharge',
    'supported' =>
      'Plan supports recharge. In-app recharge is not available yet.',
    'daily_extension' =>
      'Plan supports daily extensions. In-app extensions are not available yet.',
    _ => 'Not provided',
  };

  String get policyLabel => switch (planType) {
    'total' => 'One allowance for the full validity period',
    'daily_throttled' =>
      'Speed slows after the daily allowance. FUP: ${text('fup_text') ?? 'Not provided'}',
    'daily_cutoff' =>
      'Data stops after the daily allowance until the next daily period',
    'daily_unlimited' =>
      'Daily unlimited. FUP: ${text('fup_text') ?? 'Not provided'}',
    _ => 'Not provided',
  };

  String networkTypesForCountry(String code) {
    final networks = values['networks'];
    if (networks is! List) return 'Not provided';
    final types = <String>{};
    for (final location in networks.whereType<Map>()) {
      if (location['country_code'] != code) continue;
      final operators = location['operators'];
      if (operators is! List) continue;
      for (final operator in operators.whereType<Map>()) {
        final type = operator['network_type'];
        if (type is String && type.isNotEmpty) types.add(type);
      }
    }
    return types.isEmpty ? 'Not provided' : types.join(', ');
  }

  String get networksLabel {
    final networks = values['networks'];
    if (networks is! List) return 'Not provided';
    final labels = <String>[];
    for (final location in networks.whereType<Map>()) {
      final country = location['country_code'] ?? location['location_name'];
      final operators = location['operators'];
      if (operators is! List) continue;
      for (final operator in operators.whereType<Map>()) {
        final name = operator['name'];
        if (name is! String || name.isEmpty) continue;
        labels.add(
          '${country == null ? '' : '$country: '}$name${operator['network_type'] == null ? '' : ' (${operator['network_type']})'}',
        );
      }
    }
    return labels.isEmpty ? 'Not provided' : labels.join('\n');
  }
}
