/// Export the generated launcher artwork without changing its illustration.
/// Run before flutter_launcher_icons whenever the foreground asset changes.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// This export tool uses the image library supplied by flutter_launcher_icons.
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;

void main() {
  final foreground = img.decodePng(
    File('assets/images/launcher-foreground.png').readAsBytesSync(),
  )!;
  final config = File('pubspec.yaml').readAsStringSync();
  final inset = int.parse(
    RegExp(
      r'adaptive_icon_foreground_inset:\s*(\d+)',
    ).firstMatch(config)!.group(1)!,
  );

  double maxRadius = 0;
  double maxVisibleRadius = 0;
  for (final pixel in foreground) {
    if (pixel.a == 0) continue;
    final radius = math.sqrt(
      math.pow(pixel.x + 0.5 - foreground.width / 2, 2) +
          math.pow(pixel.y + 0.5 - foreground.height / 2, 2),
    );
    maxRadius = math.max(maxRadius, radius);
    if (pixel.a >= 32) {
      maxVisibleRadius = math.max(maxVisibleRadius, radius);
    }
  }
  // Android's foreground canvas is 108dp, with a 66dp circular safe area.
  final radiusDp = maxRadius / foreground.width * 108 * (1 - inset / 50);
  if (radiusDp > 33) {
    throw StateError(
      'Foreground exceeds Android safe area: radius '
      '${radiusDp.toStringAsFixed(2)}dp. Increase the configured inset.',
    );
  }

  // Standard opaque square export for iOS and older Android launchers.
  final legacy = img.Image(width: 1024, height: 1024, numChannels: 3);
  img.fill(legacy, color: img.ColorRgb8(10, 41, 90));
  final artwork = img.copyResize(
    foreground,
    width: 896,
    height: 896,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(legacy, artwork, dstX: 64, dstY: 64);
  File(
    'assets/images/launcher-icon.png',
  ).writeAsBytesSync(img.encodePng(legacy));

  final output = Directory('output/imagegen/launcher-icon')
    ..createSync(recursive: true);
  File('${output.path}/validation.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'sourceWidth': foreground.width,
      'sourceHeight': foreground.height,
      'adaptiveInsetPercent': inset,
      'maxAlphaRadiusPixels': maxRadius,
      'maxVisibleRadiusPixels': maxVisibleRadius,
      'maxAlphaRadiusDp': radiusDp,
      'safeRadiusDp': 33,
      'passed': true,
    }),
  );
  stdout.writeln(
    'Exported launcher icon. All nontransparent pixels fit within the '
    'Android safe area (${radiusDp.toStringAsFixed(2)}dp / 33dp).',
  );
}
