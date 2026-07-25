import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    Platform.environment['SUPABASE_URL'] ??
        'https://nmdtstokvlysslyxajgq.supabase.co',
    Platform.environment['SUPABASE_ANON_KEY'] ?? 'your-anon-key',
  );

  try {
    final response = await supabase
        .from('carrier_pricing')
        .select()
        .eq('country_code', '+20')
        .ilike('carrier_name', 'Vodafone Egypt')
        .maybeSingle();

    print('Response: $response');
    if (response != null) {
      print(
        'min_auto_refill_amount type: ${response['min_auto_refill_amount'].runtimeType}',
      );
    }
  } catch (e) {
    print('Error: $e');
  }
}
