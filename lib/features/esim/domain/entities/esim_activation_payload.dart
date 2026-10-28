/// A validated owner-held activation payload. Never log or track its value/URI.
class EsimActivationPayload {
  const EsimActivationPayload._(this.value, this.smdpAddress, this.matchingId);
  final String value, smdpAddress, matchingId;

  static EsimActivationPayload? tryParse(String value) {
    if (value.length > 1024 || RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value)) {
      return null;
    }
    final parts = value.split(r'$');
    if (parts.length < 3 ||
        parts.length > 4 ||
        parts[0] != 'LPA:1' ||
        parts[2].isEmpty ||
        (parts.length == 4 && parts[3].isEmpty)) {
      return null;
    }
    final host = parts[1];
    final labels = host.split('.');
    final label = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$');
    if (host.length > 253 ||
        labels.length < 2 ||
        labels.any((part) => !label.hasMatch(part)) ||
        RegExp(r'^[0-9.]+$').hasMatch(host)) {
      return null;
    }
    return EsimActivationPayload._(value, host, parts[2]);
  }

  /// Construct a fixed-host Apple Universal Link, encoding the entire LPA once.
  Uri get appleInstallUri => Uri.https(
    'esimsetup.apple.com',
    '/esim_qrcode_provisioning',
    {'carddata': value},
  );

  @override
  String toString() => 'EsimActivationPayload(redacted)';
}
