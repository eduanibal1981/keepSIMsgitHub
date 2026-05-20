import 'dart:convert';
import 'dart:io';

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const baseUrl = 'https://zwxswagokhgbuzrrbnhr.supabase.co';

void main() async {
  final client = HttpClient();
  print('--- Querying Supabase OpenAPI Schema Endpoint ---');

  try {
    final url = Uri.parse('$baseUrl/rest/v1/');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    print('HTTP ${response.statusCode}');
    if (response.statusCode == 200) {
      final schema = json.decode(body);
      print('Captured OpenAPI Spec successfully!');
      
      final definitions = schema['definitions'];
      if (definitions != null) {
        print('\n--- Available Tables/Definitions ---');
        definitions.keys.forEach((tableName) {
          print('- $tableName');
        });
        
        // Print columns of sim_lines if present
        final simLinesDef = definitions['sim_lines'];
        if (simLinesDef != null) {
          print('\n--- columns in sim_lines ---');
          final properties = simLinesDef['properties'];
          if (properties != null) {
            properties.forEach((colName, colVal) {
              print('  * $colName: ${colVal['type']} (${colVal['format'] ?? ''})');
            });
          }
        } else {
          print('\nWARNING: sim_lines table not found in OpenAPI definitions.');
        }

        // Print columns of carriers if present
        final carriersDef = definitions['carriers'];
        if (carriersDef != null) {
          print('\n--- columns in carriers ---');
          final properties = carriersDef['properties'];
          if (properties != null) {
            properties.forEach((colName, colVal) {
              print('  * $colName: ${colVal['type']} (${colVal['format'] ?? ''})');
            });
          }
        }
      } else {
        print('No definitions object found in the OpenAPI schema.');
      }
    } else {
      print('Failed: $body');
    }
  } catch (e) {
    print('Error: $e');
  }

  client.close();
}
