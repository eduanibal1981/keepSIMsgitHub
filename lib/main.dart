/// SIM Shield — App Entry Point
///
/// Initializes Supabase and wraps the app in ProviderScope.
library;

import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'package:keep_sims/features/home_widget/presentation/home_widget_sync.dart';
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

    const sentryDsn = String.fromEnvironment('SENTRY_DSN');

    Future<void> runAppMain() async {
      // Global error handling hooks for app resilience
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Uncaught Flutter Error: ${details.exceptionAsString()}\n${details.stack}');
        if (sentryDsn.isNotEmpty) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        }
      };

      WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
        debugPrint('Uncaught Platform Error: $error\n$stack');
        if (sentryDsn.isNotEmpty) {
          Sentry.captureException(error, stackTrace: stack);
        }
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

        // G10: Firebase App Check. Android/Play Integrity only — iOS has no
        // GoogleService-Info.plist in this repo (§ 7 owner item 2), so
        // DeviceCheck cannot be configured and activating it there would only
        // produce errors. Debug provider in debug builds so an emulator can
        // still exercise the path; a debug token is NOT attestation and the
        // server knows it, because it verifies every token against Google's
        // JWKS rather than trusting the header's presence.
        //
        // Until the owner registers this app in the Firebase App Check console
        // (§ 7), activation throws or yields no token, the header is simply
        // absent, and the Edge Functions record `missing` and carry on —
        // APP_CHECK_ENFORCE ships false precisely so that is harmless.
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          try {
            await FirebaseAppCheck.instance.activate(
              providerAndroid: kDebugMode
                  ? const AndroidDebugProvider()
                  : const AndroidPlayIntegrityProvider(),
            );
          } catch (e) {
            debugPrint('App Check not active (not registered yet?): $e');
          }
        }
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
    }

    if (sentryDsn.isEmpty) {
      debugPrint('WARNING: SENTRY_DSN is not configured. Skipping SentryFlutter.init to avoid silent event drops.');
      await runAppMain();
    } else {
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.sendDefaultPii = false;
          options.tracesSampleRate = kReleaseMode ? 0.05 : 1.0;
          options.beforeSend = (SentryEvent event, Hint hint) {
            // PII scrubbing: strip sensitive data (wallet amounts, phone numbers, ICCIDs) from extra, breadcrumbs, and exceptions
            var scrubbedEvent = event;
            final extra = scrubbedEvent.extra;
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
              scrubbedEvent = scrubbedEvent.copyWith(extra: scrubbed);
            }
            return scrubbedEvent;
          };
        },
        appRunner: runAppMain,
      );
    }
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

    // Keep the home-screen widgets fed, and route taps on them (G4).
    ref.watch(homeWidgetSyncProvider);

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
