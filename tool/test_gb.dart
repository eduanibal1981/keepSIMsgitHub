import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final envContent = File('.env').readAsStringSync();
  String? apiKey;
  for (final line in envContent.split('\n')) {
    if (line.startsWith('ESIM_GO_API_KEY=')) {
      apiKey = line.substring('ESIM_GO_API_KEY='.length).trim();
      break;
    }
  }

  final uri = Uri.parse('https://api.esim-go.com/v2.4/catalogue?countries=GB');
  final response = await http.get(
    uri,
    headers: {'X-API-Key': apiKey ?? '', 'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonMap = jsonDecode(response.body);
    stdout.writeln('Keys in response: ${jsonMap.keys.toList()}');
    final List<dynamic> bundles = jsonMap['bundles'] ?? [];
    stdout.writeln('Total plans overall for GB query: ${bundles.length}');
    if (bundles.isNotEmpty)
      stdout.writeln('First plan: ${bundles.first['name']}');
  } else {
    stdout.writeln('Error: ${response.statusCode} - ${response.body}');
  }
}
