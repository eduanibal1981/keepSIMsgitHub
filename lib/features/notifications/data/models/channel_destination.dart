/// Match the sender's canonical recipient keys, with legacy-key fallback.
String channelDestination(
  String type,
  Map<String, dynamic> config, {
  String? accountEmail,
}) {
  final keys = type == 'email'
      ? const ['email_address', 'email']
      : const ['phone_number', 'phone'];
  for (final key in keys) {
    final value = config[key];
    if (value is String && value.isNotEmpty) return value.trim();
  }
  return type == 'email' ? (accountEmail ?? '').trim() : '';
}
