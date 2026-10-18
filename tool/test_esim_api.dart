import 'package:http/http.dart' as http;

import 'dart:io';

void main() async {
  // Manually parse the .env file since testLoad was removed in flutter_dotenv 6.0.0
  final envContent = File('.env').readAsStringSync();
  String? apiKey;
  for (final line in envContent.split('\n')) {
    if (line.startsWith('ESIM_GO_API_KEY=')) {
      apiKey = line.substring('ESIM_GO_API_KEY='.length).trim();
      break;
    }
  }
  final uri = Uri.parse('https://api.esim-go.com/v2.4/catalogue');
  final response = await http.get(
    uri,
    headers: {'X-API-Key': apiKey ?? '', 'Accept': 'application/json'},
  );

  stdout.writeln('Status: ${response.statusCode}');
  stdout.writeln('Response body preview:');
  stdout.writeln(response.body.substring(0, 500));
}
