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
import 'package:keep_sims/features/notifications/presentation/services/notification_navigation_service.dart';
import 'package:keep_sims/core/services/sync_queue_service.dart';
import 'package:keep_sims/features/home_widget/presentation/home_widget_sync.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';
import 'package:keep_sims/core/widgets/biometric_lock_overlay.dart';
import 'package:keep_sims/features/alert_alarm/ui/device_alarm_sync.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:keep_sims/features/voip_calling/data/services/voip_callkit_service.dart';
import 'package:keep_sims/features/voip_calling/presentation/services/incoming_call_manager.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/floating_minimized_call_bar.dart';

Future<Map<String, String>?> _checkPendingAcceptedCall() async {
  try {
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    for (final call in activeCalls) {
      final isOutgoing = call.extra?['isOutgoing'] == true;
      if (isOutgoing) {
        await FlutterCallkitIncoming.endCall(call.id);
        continue;
      }
      if (call.isAccepted) {
        final id = call.id;
        if (id.isNotEmpty) {
          return {
            'callId': id,
            'callerName': call.nameCaller?.isNotEmpty == true
                ? call.nameCaller!
                : 'KeepSIMs Caller',
            'callerAvatar': call.avatar ?? '',
            'callerPhone': call.handle ?? '',
          };
        }
      }
    }
  } catch (e) {
    debugPrint('[Startup] activeCalls error: $e');
  }
  return null;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] == 'INCOMING_VOIP_CALL') {
    final callId = data['call_id'] as String?;
    final callerName = data['caller_name'] as String? ?? 'KeepSIMs Caller';
    final callerAvatar = data['caller_avatar'] as String?;
    final callerPhone = data['caller_phone'] as String?;

    if (callId != null) {
      final callkit = VoipCallkitService();
      await callkit.showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callerPhone: callerPhone,
      );
    }
  }
}

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Force semantics for TestSprite AI
      RendererBinding.instance.ensureSemantics();

      const sentryDsn = String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue:
            'https://f28e8212c19fe8c11273864b68642156@o4511843465494528.ingest.de.sentry.io/4511843492560976',
      );

      Future<void> runAppMain() async {
        // Global error handling hooks for app resilience
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          debugPrint(
            'Uncaught Flutter Error: ${details.exceptionAsString()}\n${details.stack}',
          );
          if (sentryDsn.isNotEmpty) {
            Sentry.captureException(
              details.exception,
              stackTrace: details.stack,
            );
          }
        };

        WidgetsBinding.instance.platformDispatcher.onError =
            (Object error, StackTrace stack) {
              debugPrint('Uncaught Platform Error: $error\n$stack');
              if (sentryDsn.isNotEmpty) {
                Sentry.captureException(error, stackTrace: stack);
              }
              return true; // Error handled
            };

        // Lock to portrait on mobile
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);

        // Fast check: did the user launch the app by accepting an incoming VoIP call?
        final initialAcceptedCall = await _checkPendingAcceptedCall();
        final isCallFastLaunch = initialAcceptedCall != null;

        if (isCallFastLaunch) {
          debugPrint(
            '[Startup] Fast-launching directly into calling screen for call: ${initialAcceptedCall['callId']}',
          );
        }

        // Initialize OneSignal (for push notifications)
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize('434b9552-8005-4d08-b3b1-a7a35f0b15dc');
        if (isCallFastLaunch) {
          unawaited(OneSignal.Notifications.requestPermission(false));
        } else {
          await OneSignal.Notifications.requestPermission(false);
        }

        // Firebase initialization for FCM fallback
        try {
          await Firebase.initializeApp();
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );

          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            Future<void> activateAppCheck() async {
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

            if (isCallFastLaunch) {
              unawaited(activateAppCheck());
            } else {
              await activateAppCheck();
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
            overrides: [
              sharedPreferencesProvider.overrideWith((ref) => sharedPrefs),
              if (isCallFastLaunch)
                initialAcceptedCallProvider.overrideWithValue(
                  initialAcceptedCall,
                ),
            ],
            child: const KeepSIMsApp(),
          ),
        );
      }

      if (sentryDsn.isEmpty) {
        debugPrint(
          'WARNING: SENTRY_DSN is not configured. Skipping SentryFlutter.init to avoid silent event drops.',
        );
        await runAppMain();
      } else {
        await SentryFlutter.init((options) {
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
        }, appRunner: runAppMain);
      }
    },
    (error, stackTrace) {
      Sentry.captureException(error, stackTrace: stackTrace);
    },
  );
}

/// Root application widget.
class KeepSIMsApp extends ConsumerWidget {
  const KeepSIMsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialCall = ref.watch(initialAcceptedCallProvider);
    final callManager = ref.watch(incomingCallManagerProvider);
    final router = ref.watch(appRouterProvider);

    if (initialCall == null) {
      // Warm up offline sync queue & connectivity monitoring at normal app launch
      ref.watch(syncQueueProvider);

      // Keep the home-screen widgets fed, and route taps on them (G4).
      ref.watch(homeWidgetSyncProvider);

      // Initialize notification click & foreground listener service (N3)
      ref.watch(notificationNavigationServiceProvider);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        callManager.setRouter(router);
        callManager.initialize();
      });
    } else {
      // Fast VoIP launch: immediately wire router and initialize/answer call
      callManager.setRouter(router);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callManager.initializeWithAcceptedCall(initialCall);
      });
    }

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
          child: Stack(
            children: [
              DeviceAlarmSync(child: child ?? const SizedBox.shrink()),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FloatingMinimizedCallBar(),
              ),
            ],
          ),
        );
      },
    );
  }
}
