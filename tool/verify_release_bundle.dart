import 'dart:io';

// Deny-list regex patterns targeting client-side string/secret leaks
final denyListPatterns = [
  RegExp(r'sandbox\.paypal\.com', caseSensitive: false),
  RegExp(r'braintreegateway', caseSensitive: false),
  RegExp(r'PaypalSimulatorScreen'),
  RegExp(r'4111\s?1111\s?1111\s?1111'),
  RegExp(r'sandbox-buyer@keepsims\.com', caseSensitive: false),
  RegExp(r'EL1hsovnMcto[A-Za-z0-9_-]{50,}'),
  RegExp(r'AcNsq1nLW[A-Za-z0-9_-]{60,}'),
];

const sourceDirectories = [
  'lib',
  'android',
  'ios',
  'assets',
];

const rootFilesToCheck = [
  'pubspec.yaml',
  'pubspec.lock',
];

void main() {
  stdout.writeln('=== KeepSIMs Release Bundle & Secret Scanner ===');
  int violations = 0;

  // 1. Scan Flutter Client Source Directories
  for (final dirPath in sourceDirectories) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;

    final files = dir.listSync(recursive: true).whereType<File>();
    for (final file in files) {
      if (file.path.contains('.git') || file.path.contains('build/')) continue;
      violations += checkFileContent(file);
    }
  }

  // 2. Scan Root Manifest Files & .env Files
  for (final fileName in rootFilesToCheck) {
    final file = File(fileName);
    if (file.existsSync()) {
      violations += checkFileContent(file);
    }
  }

  final rootDir = Directory('.');
  for (final entity in rootDir.listSync()) {
    if (entity is File && entity.path.contains('.env')) {
      violations += checkFileContent(entity);
    }
  }

  // 3. Scan Built Release Artifacts (.aab / .apk) if present
  final aabFile = File('build/app/outputs/bundle/release/app-release.aab');
  if (aabFile.existsSync()) {
    stdout.writeln('Scanning compiled release bundle: ${aabFile.path}');
    violations += checkFileContent(aabFile);
  }

  final apkFile = File('build/app/outputs/apk/release/app-release.apk');
  if (apkFile.existsSync()) {
    stdout.writeln('Scanning compiled release APK: ${apkFile.path}');
    violations += checkFileContent(apkFile);
  }

  if (violations > 0) {
    stdout.writeln('FAILED: $violations deny-list/secret violations found in client sources or artifacts!');
    exit(1);
  } else {
    stdout.writeln('SUCCESS: 0 deny-list violations found. Client sources and artifacts are clean!');
    exit(0);
  }
}

int checkFileContent(File file) {
  int count = 0;
  try {
    final content = file.readAsStringSync();
    for (final pattern in denyListPatterns) {
      if (pattern.hasMatch(content)) {
        stdout.writeln('[VIOLATION] Pattern ${pattern.pattern} matched in ${file.path}');
        count++;
      }
    }
  } catch (_) {
    try {
      final bytes = file.readAsBytesSync();
      final content = String.fromCharCodes(bytes);
      for (final pattern in denyListPatterns) {
        if (pattern.hasMatch(content)) {
          stdout.writeln('[VIOLATION] Pattern ${pattern.pattern} matched in binary file ${file.path}');
          count++;
        }
      }
    } catch (_) {}
  }
  return count;
}
