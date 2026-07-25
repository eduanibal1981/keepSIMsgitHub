import 'dart:io';

const denyList = [
  'sandbox.paypal.com',
  'braintreegateway',
  'AcNsq1nLW',
  'EL1hsovnMcto49sP6ldoptaga6W6jcDOpM6qPku_zK992df5GpNX2EzytQBiCcFviG6_lxqNajOxT2g3',
  'PaypalSimulatorScreen',
  '4111111111111111',
  'sandbox-buyer@keepsims.com',
];

const targetDirectories = [
  'lib',
  'android',
  'ios',
  'supabase/functions',
];

void main() {
  print('=== KeepSIMs Release Bundle & Secret Scanner ===');
  int violations = 0;

  for (final dirPath in targetDirectories) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;

    final files = dir.listSync(recursive: true).whereType<File>();
    for (final file in files) {
      // Skip binary build files or git directory
      if (file.path.contains('.git') || file.path.contains('build/')) continue;
      try {
        final content = file.readAsStringSync();
        for (final pattern in denyList) {
          if (content.contains(pattern)) {
            print('[VIOLATION] Found "$pattern" in ${file.path}');
            violations++;
          }
        }
      } catch (_) {
        // Skip unreadable binary files
      }
    }
  }

  if (violations > 0) {
    print('FAILED: $violations deny-list/secret violations found in source tree!');
    exit(1);
  } else {
    print('SUCCESS: 0 deny-list violations found. Bundle sources are clean!');
    exit(0);
  }
}
