/// SIM Shield — Supabase Client Initialization
///
/// This is the ONLY file allowed to import and initialize Supabase.
/// Exposes a single [supabase] global getter.
library;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keep_sims/core/services/auth_session_manager.dart';

/// Global getter for the Supabase client instance.
///
/// Must call [initSupabase] before accessing this.
SupabaseClient get supabase => Supabase.instance.client;

const supabaseProjectUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://zwxswagokhgbuzrrbnhr.supabase.co',
);

const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3eHN3YWdva2hnYnV6cnJibmhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDg3MDIsImV4cCI6MjA5NDU4NDcwMn0.JzzxxqQiKEka-VLbmPH1hdBXH4aML0AMhrqXloIZXt0',
);

/// Initialize Supabase with project credentials.
///
/// Call this once in `main()` before `runApp()`.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseProjectUrl,
    anonKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Register lifecycle observer to refresh stale sessions when returning from background
  WidgetsBinding.instance.addObserver(
    AuthSessionLifecycleObserver(Supabase.instance.client),
  );

  // Proactively check and refresh stale session on cold startup
  await AuthSessionManager.ensureFreshSession(Supabase.instance.client);
}
