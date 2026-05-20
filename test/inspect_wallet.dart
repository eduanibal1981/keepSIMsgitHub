import 'dart:convert';
import 'dart:io';

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0';
const baseUrl = 'https://zwxswagokhgbuzrrbnhr.supabase.co';

void main() async {
  final client = HttpClient();
  print('--- Probing wallets table ---');
  try {
    final url = Uri.parse('$baseUrl/rest/v1/wallets?limit=1');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('Wallets: HTTP ${response.statusCode} - $body');
  } catch (e) {
    print('Wallets error: $e');
  }

  print('\n--- Probing wallet_transactions table ---');
  try {
    final url = Uri.parse('$baseUrl/rest/v1/wallet_transactions?limit=1');
    final request = await client.getUrl(url);
    request.headers.add('apikey', anonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    print('Wallet Transactions: HTTP ${response.statusCode} - $body');
  } catch (e) {
    print('Wallet Transactions error: $e');
  }

  client.close();
}
