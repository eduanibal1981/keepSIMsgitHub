import 'dart:convert';
import 'dart:io';

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const baseUrl = 'https://zwxswagokhgbuzrrbnhr.supabase.co';

void main() async {
  final client = HttpClient();
  print('--- Probing countries table ---');
  try {
    final url = Uri.parse('$baseUrl/rest/v1/countries?limit=1');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('Countries: HTTP ${response.statusCode} - $body');
  } catch (e) {
    print('Countries error: $e');
  }

  print('\n--- Probing carriers table ---');
  try {
    final url = Uri.parse('$baseUrl/rest/v1/carriers?limit=1');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('Carriers: HTTP ${response.statusCode} - $body');
  } catch (e) {
    print('Carriers error: $e');
  }

  print('\n--- Probing carrier_rules table ---');
  try {
    final url = Uri.parse('$baseUrl/rest/v1/carrier_rules?limit=1');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('Carrier Rules: HTTP ${response.statusCode} - $body');
  } catch (e) {
    print('Carrier Rules error: $e');
  }

  client.close();
}
