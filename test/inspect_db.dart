import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  print('--- Probing Columns via POST Insert probe ---');

  final url = Uri.parse('https://zwxswagokhgbuzrrbnhr.supabase.co/rest/v1/sim_lines');
  try {
    final request = await client.postUrl(url);
    request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0');
    request.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0');
    request.headers.add('Content-Type', 'application/json');
    request.headers.add('Prefer', 'return=representation'); // returns inserted row

    // Sending dummy JSON
    final bodyData = json.encode({
      'id': '60a5e5cd-2a69-4726-ae2d-5ec276e9a0bf',
    });
    request.add(utf8.encode(bodyData));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    print('HTTP ${response.statusCode}');
    print(body);
  } catch (e) {
    print('ERROR: $e');
  }

  client.close();
}
