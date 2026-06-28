/// SIM Shield — App Entry Point
///
/// Initializes Supabase and wraps the app in ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';

import 'package:keep_sims/core/supabase_client.dart';
import 'package:keep_sims/core/theme/app_theme.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force semantics for TestSprite AI
  RendererBinding.instance.ensureSemantics();

  // Lock to portrait on mobile
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Intialize OneSignal (for push notifications)
  // Enable verbose logging for debugging (remove in production)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  // Initialize with your OneSignal App ID
  OneSignal.initialize('434b9552-8005-4d08-b3b1-a7a35f0b15dc');
  // Use this method to prompt for push notifications.
  // We recommend removing this method after testing and instead use In-App Messages to prompt for notification permission.
  OneSignal.Notifications.requestPermission(false);
  // Initialize Supabase
  await initSupabase();

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => sharedPrefs),
      ],
      child: const KeepSIMsApp(),
    ),
  );
}

/// Root application widget.
class KeepSIMsApp extends ConsumerWidget {
  const KeepSIMsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm up offline sync queue & connectivity monitoring at app launch
    ref.watch(syncQueueProvider);

    final router = ref.watch(appRouterProvider);
    final prefsState = ref.watch(userPreferencesControllerProvider);
    final currentLocale = ref.watch(localeControllerProvider);

    ThemeMode currentThemeMode = ThemeMode.dark;
    final prefs = prefsState.value;
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
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: currentThemeMode, // Dynamic theme mode
      
      // Localizations
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: currentLocale,
      
      // Router
      routerConfig: router,
    );
  }
}
