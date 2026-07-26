/// SIM Shield — App Entry Point
///
/// Initializes Supabase and wraps the app in ProviderScope.
library;

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/widgets/biometric_lock_overlay.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Force semantics for TestSprite AI
    RendererBinding.instance.ensureSemantics();

    // Sentry error reporting & PII scrubbing initialization
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue: 'https://placeholder_key@o0.ingest.sentry.io/0',
        );
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.beforeSend = (SentryEvent event, Hint hint) {
          // PII scrubbing: strip sensitive data (wallet amounts, phone numbers, ICCIDs)
          final extra = event.extra;
          if (extra != null) {
            final scrubbed = Map<String, dynamic>.from(extra);
            scrubbed.removeWhere((key, value) {
              final k = key.toLowerCase();
              return k.contains('phone') ||
                     k.contains('wallet') ||
                     k.contains('iccid') ||
                     k.contains('amount') ||
                     k.contains('token') ||
                     k.contains('secret');
            });
            return event.copyWith(extra: scrubbed);
          }
          return event;
        };
      },
      appRunner: () async {
        // Global error handling hooks for app resilience
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          debugPrint('Uncaught Flutter Error: ${details.exceptionAsString()}\n${details.stack}');
          Sentry.captureException(details.exception, stackTrace: details.stack);
        };

        WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
          debugPrint('Uncaught Platform Error: $error\n$stack');
          Sentry.captureException(error, stackTrace: stack);
          return true; // Error handled
        };

        // Lock to portrait on mobile
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

        // Initialize OneSignal (for push notifications)
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize('434b9552-8005-4d08-b3b1-a7a35f0b15dc');
        OneSignal.Notifications.requestPermission(false);

        // Firebase initialization for FCM fallback
        try {
          await Firebase.initializeApp();
        } catch (e) {
          debugPrint('Firebase init skipped; FCM fallback inactive: $e');
        }

        // Initialize Supabase
        await initSupabase();

        final sharedPrefs = await SharedPreferences.getInstance();

        runApp(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWith((ref) => sharedPrefs)],
            child: const KeepSIMsApp(),
          ),
        );
      },
    );
  }, (error, stackTrace) {
    Sentry.captureException(error, stackTrace: stackTrace);
  });
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
      builder: (context, child) {
        return BiometricLockOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
