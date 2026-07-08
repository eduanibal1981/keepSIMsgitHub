/// SIM Shield — GoRouter Configuration
///
/// Centralized routing with auth-based redirects.
library;

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/ui/login_screen.dart';
import 'package:keep_sims/features/auth/ui/email_auth_screen.dart';
import 'package:keep_sims/features/profile/presentation/ui/onboarding_screen.dart';
import 'package:keep_sims/core/router/placeholder_screens.dart';
import 'package:keep_sims/features/dashboard/presentation/ui/dashboard_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/screens/sim_lines_list_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/screens/sim_line_form_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/screens/sim_line_detail_screen.dart';
import 'package:keep_sims/features/sim_lines/presentation/screens/sim_line_executions_history_screen.dart';
import 'package:keep_sims/features/wallet/ui/wallet_screen.dart';
import 'package:keep_sims/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:keep_sims/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/settings_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/preferences_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/privacy_screen.dart';
import 'package:keep_sims/features/household/presentation/screens/household_screen.dart';
import 'package:keep_sims/features/referrals/ui/referrals_screen.dart';
import 'package:keep_sims/features/payments/ui/payments_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/subscription_screen.dart';
import 'package:keep_sims/features/geo/ui/geo_screen.dart';
import 'package:keep_sims/features/offline_recharge/ui/offline_refill_screen.dart';
import 'package:keep_sims/features/offline_recharge/ui/offline_refill_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/alert_simulator_screen.dart';
import 'package:keep_sims/features/support/presentation/ui/support_screen.dart';
import 'package:keep_sims/features/support/presentation/ui/create_ticket_screen.dart';
import 'package:keep_sims/features/support/presentation/ui/faq_screen.dart';
import 'package:keep_sims/features/support/presentation/ui/ticket_details_screen.dart';
import 'package:keep_sims/features/support/data/models/support_ticket.dart';
import 'package:keep_sims/features/support/data/models/support_ticket.dart';

part 'app_router.g.dart';

/// Route path constants to avoid magic strings.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String emailAuth = '/email-auth';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String simLines = '/sim-lines';
  static const String simLineDetail = '/sim-lines/detail/:id';
  static const String simLineExecutions = '/sim-lines/detail/:id/executions';
  static const String wallet = '/wallet';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String household = '/household';
  static const String profile = '/profile';
  static const String referrals = '/settings/referrals';
  static const String geo = '/settings/geo';
  static const String preferences = '/settings/preferences';
  static const String privacy = '/settings/privacy';
  static const String offlineRefill = '/settings/offline-recharge';
  static const String simulators = '/settings/simulators';
  static const String tests = '/settings/tests';
  static const String support = '/support';
}

@riverpod
class SplashCompleted extends _$SplashCompleted {
  @override
  bool build() => false;

  void complete() => state = true;

  void reset() => state = false;
}

/// A notifier that triggers router re-evaluation when auth or splash states change.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
    _ref.listen(splashCompletedProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

/// Provides the app's GoRouter instance with auth-based redirects.
@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,

    // ── Auth Redirect Logic ──────────────────────────────────
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isSplashCompleted = ref.read(splashCompletedProvider);

      final currentPath = state.uri.path;

      // 1. Force the splash screen to play fully first
      if (!isSplashCompleted) {
        return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final profile = authState.value;
      final isLoggedIn = profile != null;

      // Not logged in → go to login (unless already on a public route)
      if (!isLoggedIn) {
        if (currentPath == AppRoutes.login ||
            currentPath == AppRoutes.emailAuth) {
          return null; // allow access
        }
        return AppRoutes.login;
      }

      // Logged in check onboarding
      final onboardingCompleted = profile.onboardingCompleted;

      if (!onboardingCompleted) {
        return currentPath == AppRoutes.onboarding
            ? null
            : AppRoutes.onboarding;
      }

      // Logged in & onboarding complete but on splash, login, email auth, or onboarding → go to home
      if (currentPath == AppRoutes.splash ||
          currentPath == AppRoutes.login ||
          currentPath == AppRoutes.emailAuth ||
          currentPath == AppRoutes.onboarding) {
        return AppRoutes.home;
      }



      // Otherwise, stay on current page
      return null;
    },

    routes: [
      // ── Splash / Auth Check ─────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Login ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Email Auth ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.emailAuth,
        name: 'emailAuth',
        builder: (context, state) => const EmailAuthScreen(),
      ),

      // ── Onboarding ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Main App Shell ─────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.simLines,
            name: 'simLines',
            builder: (context, state) => const SimLinesListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'simLineAdd',
                builder: (context, state) => const SimLineFormScreen(),
              ),

              GoRoute(
                path: 'detail/:id',
                name: 'simLineDetail',
                builder: (context, state) =>
                    SimLineDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'executions',
                    name: 'simLineExecutions',
                    builder: (context, state) => SimLineExecutionsHistoryScreen(
                      simLineId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.wallet,
            name: 'wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                name: 'notificationSettings',
                builder: (context, state) => const NotificationSettingsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'household',
                name: 'settingsHousehold',
                builder: (context, state) => const HouseholdScreen(),
              ),
              GoRoute(
                path: 'referrals',
                name: 'settingsReferrals',
                builder: (context, state) => const ReferralsScreen(),
              ),
              GoRoute(
                path: 'payments',
                name: 'settingsPayments',
                builder: (context, state) => const PaymentsScreen(),
              ),
              GoRoute(
                path: 'geo',
                name: 'settingsGeo',
                builder: (context, state) => const GeoScreen(),
              ),
              GoRoute(
                path: 'preferences',
                name: 'settingsPreferences',
                builder: (context, state) => const PreferencesScreen(),
              ),
              GoRoute(
                path: 'privacy',
                name: 'settingsPrivacy',
                builder: (context, state) => const PrivacyScreen(),
              ),

              GoRoute(
                path: 'offline-recharge',
                name: 'settingsOfflineRecharge',
                builder: (context, state) {
                  final simLineId = state.uri.queryParameters['simLineId'];
                  return OfflineRefillScreen(simLineId: simLineId);
                },
              ),
              GoRoute(
                path: 'simulators',
                name: 'settingsSimulators',
                builder: (context, state) => const AlertSimulatorScreen(),
              // ),
              // GoRoute(
              //   path: 'tests',
              //   name: 'settingsTests',
              //   builder: (context, state) => const TestListScreen(),
              // ),
          )],
          ),
          GoRoute(
            path: AppRoutes.household,
            name: 'household',
            builder: (context, state) => const HouseholdScreen(),
          ),
          GoRoute(
            path: AppRoutes.support,
            name: 'support',
            builder: (context, state) => const SupportScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'supportCreate',
                builder: (context, state) {
                  final initialCategory = state.uri.queryParameters['category'];
                  return CreateTicketScreen(initialCategory: initialCategory);
                },
              ),
              GoRoute(
                path: 'faq',
                name: 'supportFaq',
                builder: (context, state) => const FaqScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'supportDetail',
                builder: (context, state) {
                  final ticket = state.extra as SupportTicket;
                  return TicketDetailsScreen(ticket: ticket);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
