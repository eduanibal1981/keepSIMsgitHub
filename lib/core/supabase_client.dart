/// SIM Shield — Supabase Client Initialization
///
/// This is the ONLY file allowed to import and initialize Supabase.
/// Exposes a single [supabase] global getter.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Global getter for the Supabase client instance.
///
/// Must call [initSupabase] before accessing this.
SupabaseClient get supabase => Supabase.instance.client;

/// Initialize Supabase with project credentials.
///
/// Call this once in `main()` before `runApp()`.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://zwxswagokhgbuzrrbnhr.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0',
    ),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );
}
