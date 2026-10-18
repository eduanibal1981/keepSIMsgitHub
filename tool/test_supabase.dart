import 'package:supabase_flutter/supabase_flutter.dart';
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

    stdout.writeln('Response: $response');
    if (response != null) {
      stdout.writeln(
        'min_auto_refill_amount type: ${response['min_auto_refill_amount'].runtimeType}',
      );
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  }
}
