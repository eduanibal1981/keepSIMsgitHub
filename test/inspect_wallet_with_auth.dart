import 'dart:convert';
import 'dart:io';

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const baseUrl = 'https://zwxswagokhgbuzrrbnhr.supabase.co';

void main() async {
  final client = HttpClient();
  print('--- Authenticating with Supabase to inspect wallet schemas ---');

  final email = 'temp.wallet.discoverer.${DateTime.now().millisecondsSinceEpoch}@gmail.com';
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
    
    print('Signup Status: ${response.statusCode}');
    print('Signup Response Body: $body');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
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

  if (jwt != null && userId != null) {
    // Step 2: Fetch wallets
    print('\n--- Fetching wallets for authenticated user ---');
    try {
      final url = Uri.parse('$baseUrl/rest/v1/wallets');
      final request = await client.getUrl(url);
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $jwt');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      print('Wallets GET: HTTP ${response.statusCode} - $body');
    } catch (e) {
      print('Wallets GET error: $e');
    }

    // Step 3: Probing insert on wallets with user_id
    print('\n--- Probing insert on wallets table ---');
    try {
      final url = Uri.parse('$baseUrl/rest/v1/wallets');
      final request = await client.postUrl(url);
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $jwt');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');
      
      final bodyData = json.encode({
        'user_id': userId,
      });
      request.add(utf8.encode(bodyData));
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      print('Wallets Insert: HTTP ${response.statusCode} - $body');
    } catch (e) {
      print('Wallets Insert error: $e');
    }

    // Step 4: Probing insert on wallet_transactions table
    print('\n--- Probing insert on wallet_transactions table ---');
    try {
      final url = Uri.parse('$baseUrl/rest/v1/wallet_transactions');
      final request = await client.postUrl(url);
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $jwt');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');
      
      final bodyData = json.encode({
        'user_id': userId,
        'amount': 10.0,
      });
      request.add(utf8.encode(bodyData));
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      print('Wallet Transactions Insert: HTTP ${response.statusCode} - $body');
    } catch (e) {
      print('Wallet Transactions Insert error: $e');
    }
  }

  client.close();
}
