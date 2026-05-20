import 'dart:convert';
import 'dart:io';

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const baseUrl = 'https://zwxswagokhgbuzrrbnhr.supabase.co';

void main() async {
  final client = HttpClient();
  print('--- Authenticating with Supabase to inspect sim_lines schema ---');

  final email = 'temp.inspect.discoverer.${DateTime.now().millisecondsSinceEpoch}@gmail.com';
  const password = 'TempPassword123!';

  String? jwt;
  String? userId;

  // Step 1: Sign up a temporary user
  try {
    final signupUrl = Uri.parse('$baseUrl/auth/v1/signup');
    final request = await client.postUrl(signupUrl);
    request.headers.add('apikey', anonKey);
    request.headers.add('Content-Type', 'application/json');
    
    final bodyData = json.encode({
      'email': email,
      'password': password,
    });
    request.add(utf8.encode(bodyData));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      print('Signup Response: $body');
      final data = json.decode(body);
      jwt = data['access_token'];
      userId = data['user']?['id'];
      print('SUCCESS: Signed up temporary user. ID: $userId');
    } else {
      print('Signup failed: HTTP ${response.statusCode} - $body');
    }
  } catch (e) {
    print('Signup error: $e');
  }

  // Step 2: If we have the JWT, let's probe sim_lines schema!
  if (jwt != null && userId != null) {
    await _probeSimLines(client, jwt, userId);
  }

  client.close();
}

Future<void> _probeSimLines(HttpClient client, String jwt, String userId) async {
  print('\n--- Probing Columns on sim_lines with Authenticated JWT ---');
  final url = Uri.parse('$baseUrl/rest/v1/sim_lines');
  
  // We'll perform an insert with fields we expect, and we'll check the database error
  // If we specify a wrong column name, it will fail with "column does not exist"
  // Let's test a list of fields we want to check
  final testBodies = [
    // 1. Simple probe with just user_id and phone_number
    {
      'user_id': userId,
      'phone_number': '+1234567890',
    },
    // 2. Add potential other standard columns
    {
      'user_id': userId,
      'phone_number': '+12345678901',
      'carrier': 'Vodafone',
      'nickname': 'My Test Line',
    },
    // 3. Try another set
    {
      'user_id': userId,
      'phone_number': '+12345678902',
      'carrier_id': 'Vodafone',
      'status': 'active',
    }
  ];

  for (var i = 0; i < testBodies.length; i++) {
    final body = testBodies[i];
    print('\n[Test Insert Case ${i + 1}] Body: $body');
    
    try {
      final request = await client.postUrl(url);
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $jwt');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');

      request.add(utf8.encode(json.encode(body)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      print('HTTP ${response.statusCode} - $responseBody');
      
      // If it succeeds with 201, it returns the inserted row including ALL column names!
      if (response.statusCode == 201) {
        print('🎉 SUCCESS! Captured entire table row keys:');
        final insertedRow = json.decode(responseBody);
        if (insertedRow is List && insertedRow.isNotEmpty) {
          print(insertedRow.first.keys.toList());
        } else if (insertedRow is Map) {
          print(insertedRow.keys.toList());
        }
        break; // Captured columns successfully!
      }
    } catch (e) {
      print('Error during insert case: $e');
    }
  }
}
