import 'dart:io';

void main() {
  final file = File(
    'lib/features/sim_lines/presentation/screens/sim_line_detail_screen.dart',
  );
  var content = file.readAsStringSync();

  content = content.replaceAll(
    RegExp(
      r'\|\|\s*\(\s*user\s*!=\s*null\s*&&\s*user\.subscriptionTier\.toLowerCase\(\)\s*==\s*\'
      "'"
      r'premium'
      "'"
      r'\s*\)',
    ),
    '',
  );

  content = content.replaceAll(
    RegExp(
      r'\|\|\s*\(\s*userProfile\s*!=\s*null\s*&&\s*userProfile\.subscriptionTier\.toLowerCase\(\)\s*==\s*\'
      "'"
      r'premium'
      "'"
      r'\s*\)',
    ),
    '',
  );

  content = content.replaceAll(
    RegExp(
      r'&&\s*\(\s*userProfile\.subscriptionTier\.toLowerCase\(\)\s*!=\s*\'
      "'"
      r'premium'
      "'"
      r'\s*&&\s*userProfile\.subscriptionTier\.toLowerCase\(\)\s*!=\s*\'
      "'"
      r'standard'
      "'"
      r'\s*\)',
    ),
    '',
  );

  file.writeAsStringSync(content);
  stdout.writeln('Done modifying sim_line_detail_screen.dart');
}
