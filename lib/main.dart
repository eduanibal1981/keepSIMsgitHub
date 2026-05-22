/// SIM Shield — App Entry Point
///
/// Initializes Supabase and wraps the app in ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on mobile
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Supabase
  await initSupabase();

  runApp(const ProviderScope(child: SimShieldApp()));
}

/// Root application widget.
class SimShieldApp extends ConsumerWidget {
  const SimShieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefsState = ref.watch(userPreferencesControllerProvider);

    ThemeMode currentThemeMode = ThemeMode.dark;
    final prefs = prefsState.valueOrNull;
    if (prefs != null) {
      if (prefs.theme == 'light') {
        currentThemeMode = ThemeMode.light;
      } else if (prefs.theme == 'system') {
        currentThemeMode = ThemeMode.system;
      } else {
        currentThemeMode = ThemeMode.dark;
      }
    }

    return MaterialApp.router(
      title: 'SIM Shield',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: currentThemeMode, // Dynamic theme mode
      // Router
      routerConfig: router,
    );
  }
}
