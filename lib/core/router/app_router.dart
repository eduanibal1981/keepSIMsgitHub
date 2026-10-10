/// SIM Shield — GoRouter Configuration
///
/// Centralized routing with auth-based redirects.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/ui/login_screen.dart';
import 'package:keep_sims/features/auth/ui/email_auth_screen.dart';
import 'package:keep_sims/features/auth/ui/forgot_password_screen.dart';
import 'package:keep_sims/features/profile/presentation/ui/onboarding_screen.dart';
import 'package:keep_sims/features/profile/presentation/ui/profile_screen.dart';
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
import 'package:keep_sims/features/settings/presentation/screens/devices_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/privacy_screen.dart';
import 'package:keep_sims/features/household/presentation/screens/household_screen.dart';
import 'package:keep_sims/features/referrals/ui/referrals_screen.dart';
import 'package:keep_sims/features/payments/ui/payments_screen.dart';
import 'package:keep_sims/features/geo/ui/geo_screen.dart';
import 'package:keep_sims/features/offline_recharge/ui/offline_refill_screen.dart';
import 'package:keep_sims/features/offline_recharge/ui/recovery_guidance_screen.dart';
import 'package:keep_sims/features/settings/presentation/screens/alert_simulator_screen.dart';
import 'package:keep_sims/features/support/presentation/screens/support_tickets_list_screen.dart';
import 'package:keep_sims/features/support/presentation/screens/create_ticket_screen.dart';
import 'package:keep_sims/features/support/presentation/screens/ticket_detail_screen.dart';
import 'package:keep_sims/features/support/presentation/ui/faq_screen.dart';
import 'package:keep_sims/features/support/presentation/screens/submit_feedback_screen.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_screen.dart';
import 'package:keep_sims/features/esim/presentation/screens/esim_plans_screen.dart';
import 'package:keep_sims/features/price_watch/presentation/screens/price_watch_screen.dart';
import 'package:keep_sims/features/roam_calculator/presentation/screens/roam_calculator_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/calling_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/smart_call_dashboard_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/active_call_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/sip_diagnostics_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/my_numbers_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/voicemail_inbox_screen.dart';
import 'package:keep_sims/features/calling/presentation/screens/smart_call_savings_screen.dart';
import 'package:keep_sims/features/return_trip/presentation/screens/return_trip_wizard_screen.dart';
import 'package:keep_sims/features/voip_calling/presentation/screens/whatsapp_call_screen.dart';
import 'package:keep_sims/features/voip_calling/presentation/screens/internet_calling_screen.dart';

part 'app_router.g.dart';

/// Route path constants to avoid magic strings.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String emailAuth = '/email-auth';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String calling = '/calling';
  static const String callingDialer = '/calling/dialer';
  static const String myNumbers = '/calling/my-numbers';
  static const String voicemail = '/calling/voicemail';
  static const String voicemailDetail = '/calling/voicemail/:voicemailId';
  static const String callingSavings = '/calling/savings';
  static const String sipDiagnostics = '/calling/sip-test';
  static const String internetCalling = '/calling/internet';
  static const String callingActive = '/calling/active';
  static const String voipCall = '/voip-call';
  static const String simLines = '/sim-lines';
  static const String simLineDetail = '/sim-lines/detail/:id';
  static const String simLineExecutions = '/sim-lines/detail/:id/executions';
  static const String returnTrip = '/sim-lines/:id/return-trip';
  static const String wallet = '/wallet';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String household = '/household';
  static const String profile = '/profile';
  static const String referrals = '/settings/referrals';
  static const String geo = '/settings/geo';
  static const String preferences = '/settings/preferences';
  static const String privacy = '/settings/privacy';
  static const String devices = '/settings/devices';
  static const String offlineRefill = '/settings/offline-recharge';
  static const String simulators = '/settings/simulators';
  static const String tests = '/settings/tests';
  static const String support = '/support';
  static const String supportFaq = '/support/faq';
  static const String supportFeedback = '/support/feedback';
  static const String esim = '/esim';
  static const String esimPlans = '/esim/plans';
  static const String esimPriceWatch = '/esim/price-watch';
  static const String esimRoamCalculator = '/esim/roam-calculator';
  static const String emergencyRecovery = '/emergency-recovery';
}

@riverpod
class SplashCompleted extends _$SplashCompleted {
  @override
  bool build() => false;

  void complete() => state = true;

  void reset() => state = false;
}

/// Pending accepted VoIP call detected at app launch to allow direct routing
/// to the call screen, bypassing splash and dashboard loading.
final initialAcceptedCallProvider = Provider<Map<String, String>?>(
  (ref) => null,
);

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
RouterConfig<Object> appRouter(Ref ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  final initialAcceptedCall = ref.watch(initialAcceptedCallProvider);
  final hasInitialAcceptedCall =
      initialAcceptedCall != null &&
      initialAcceptedCall['callId'] != null &&
      initialAcceptedCall['callId']!.isNotEmpty;

  final initialLocation = hasInitialAcceptedCall
      ? '${AppRoutes.voipCall}/${initialAcceptedCall['callId']}'
      : AppRoutes.splash;

  if (hasInitialAcceptedCall) {
    Future.microtask(() {
      ref.read(splashCompletedProvider.notifier).complete();
    });
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: true,
    refreshListenable: notifier,

    // ── Auth Redirect Logic ──────────────────────────────────
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isSplashCompleted = ref.read(splashCompletedProvider);

      final currentPath = state.uri.path;

      // 0. Unconditional bypass: active VoIP or cellular calls must never be
      // redirected away to Splash, Login, or Onboarding.
      if (currentPath.startsWith(AppRoutes.voipCall) ||
          currentPath == AppRoutes.callingActive) {
        return null;
      }

      // 1. Force the splash screen to play fully first
      if (!isSplashCompleted) {
        return currentPath == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final profile = authState.value;
      final isLoggedIn = profile != null;

      // Not logged in → go to login (unless already on a public route)
      if (!isLoggedIn) {
        if (currentPath == AppRoutes.login ||
            currentPath == AppRoutes.emailAuth ||
            currentPath == AppRoutes.forgotPassword) {
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
          currentPath == AppRoutes.forgotPassword ||
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
        builder: (context, state) => EmailAuthScreen(
          initialEmail: state.extra is String ? state.extra as String : '',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.extra is String ? state.extra as String : '',
        ),
      ),

      // ── Onboarding ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Active International Call (Full-Screen Overlay) ─────
      GoRoute(
        path: AppRoutes.callingActive,
        name: 'callingActive',
        builder: (context, state) => const ActiveCallScreen(),
      ),

      // ── Active WhatsApp-Style VoIP Internet Call ────────────
      GoRoute(
        path: AppRoutes.voipCall,
        name: 'voipCall',
        builder: (context, state) => const WhatsAppCallScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.voipCall}/:callId',
        name: 'voipCallWithId',
        builder: (context, state) => const WhatsAppCallScreen(),
      ),

      // ── Return Trip Wizard (Full-Screen Flow) ────────────────
      GoRoute(
        path: '/sim-lines/:id/return-trip',
        name: 'returnTripDirect',
        builder: (context, state) =>
            ReturnTripWizardScreen(simLineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sim-lines/detail/:id/return-trip',
        name: 'returnTripDetail',
        builder: (context, state) =>
            ReturnTripWizardScreen(simLineId: state.pathParameters['id']!),
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
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.calling,
            name: 'calling',
            builder: (context, state) => const SmartCallDashboardScreen(),
            routes: [
              GoRoute(
                path: 'dialer',
                name: 'callingDialer',
                builder: (context, state) => CallingScreen(
                  initialNumber: state.uri.queryParameters['number'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.sipDiagnostics,
            name: 'sipDiagnostics',
            builder: (context, state) => const SipDiagnosticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.internetCalling,
            name: 'internetCalling',
            builder: (context, state) => const InternetCallingScreen(),
          ),
          GoRoute(
            path: AppRoutes.myNumbers,
            name: 'myNumbers',
            builder: (context, state) => const MyNumbersScreen(),
          ),
          GoRoute(
            path: AppRoutes.callingSavings,
            name: 'callingSavings',
            builder: (context, state) => const SmartCallSavingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.voicemail,
            name: 'voicemail',
            builder: (context, state) => const VoicemailInboxScreen(),
            routes: [
              GoRoute(
                path: ':voicemailId',
                name: 'voicemailDetail',
                builder: (context, state) => VoicemailInboxScreen(
                  initialVoicemailId: state.pathParameters['voicemailId'],
                ),
              ),
            ],
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
                path: 'devices',
                name: 'settingsDevices',
                builder: (context, state) => const DevicesScreen(),
              ),

              GoRoute(
                path: 'offline-recharge',
                name: 'settingsOfflineRecharge',
                builder: (context, state) {
                  final simLineId = state.uri.queryParameters['simLineId'];
                  final showSelector =
                      state.uri.queryParameters['showSelector'] == 'true';
                  return OfflineRefillScreen(
                    simLineId: simLineId,
                    autoShowSelector: showSelector,
                  );
                },
              ),
              GoRoute(
                path: 'emergency-recovery',
                name: 'settingsEmergencyRecovery',
                builder: (context, state) => const RecoveryGuidanceScreen(),
              ),
              // Dev-only tools: compiled out of release builds (kDebugMode
              // is a compile-time constant, so tree shaking removes the
              // simulator screens from the release bundle).
              if (kDebugMode)
                GoRoute(
                  path: 'simulators',
                  name: 'settingsSimulators',
                  builder: (context, state) => const AlertSimulatorScreen(),
                ),
            ],
          ),
          GoRoute(
            path: AppRoutes.household,
            name: 'household',
            builder: (context, state) => const HouseholdScreen(),
          ),
          GoRoute(
            path: AppRoutes.emergencyRecovery,
            name: 'emergencyRecovery',
            builder: (context, state) => const RecoveryGuidanceScreen(),
          ),
          GoRoute(
            path: AppRoutes.esim,
            name: 'esim',
            builder: (context, state) => const EsimScreen(),
            routes: [
              GoRoute(
                path: 'plans',
                name: 'esimPlans',
                builder: (context, state) => const EsimPlansScreen(),
              ),
              GoRoute(
                path: 'price-watch',
                name: 'esimPriceWatch',
                builder: (context, state) => const PriceWatchScreen(),
              ),
              // G5. `country` is optional: the screen falls back to whatever
              // C8 last detected, which is the case the geo trigger produces.
              GoRoute(
                path: 'roam-calculator',
                name: 'esimRoamCalculator',
                builder: (context, state) => RoamCalculatorScreen(
                  initialCountryCode: state.uri.queryParameters['country'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.support,
            name: 'support',
            builder: (context, state) => const SupportTicketsListScreen(),
            routes: [
              GoRoute(
                path: 'faq',
                name: 'supportFaq',
                builder: (context, state) => const FaqScreen(),
              ),
              GoRoute(
                path: 'feedback',
                name: 'supportFeedback',
                builder: (context, state) => const SubmitFeedbackScreen(),
              ),
              GoRoute(
                path: 'new',
                name: 'supportNewTicket',
                builder: (context, state) => const CreateTicketScreen(),
              ),
              GoRoute(
                path: 'create',
                name: 'supportCreate',
                builder: (context, state) => const CreateTicketScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'supportDetail',
                builder: (context, state) {
                  final ticketId = state.pathParameters['id']!;
                  return TicketDetailScreen(ticketId: ticketId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  final filteringProvider = FilteringRouteInformationProvider(
    router.routeInformationProvider,
  );
  return FilteringRouterConfig(router, filteringProvider);
}

/// A custom RouteInformationProvider that ignores deep links to payment-success page,
/// so GoRouter does not rebuild the Navigator stack and dismiss the active payment screen.
class FilteringRouteInformationProvider extends RouteInformationProvider
    with ChangeNotifier {
  final GoRouteInformationProvider _delegate;
  late RouteInformation _currentValue;

  FilteringRouteInformationProvider(this._delegate) {
    final initial = _delegate.value;
    final uriString = initial.uri.toString();
    if (uriString.contains('payment-success') ||
        uriString.contains('success.html')) {
      _currentValue = RouteInformation(uri: Uri.parse(AppRoutes.home));
    } else {
      _currentValue = initial;
    }
    _delegate.addListener(_onDelegateChanged);
  }

  void _onDelegateChanged() {
    final routeInfo = _delegate.value;
    final uriString = routeInfo.uri.toString();
    if (uriString.contains('payment-success') ||
        uriString.contains('success.html')) {
      debugPrint(
        '[Router] Intercepted and ignored payment-success deep link: ${routeInfo.uri}',
      );
      return;
    }
    _currentValue = routeInfo;
    notifyListeners();
  }

  @override
  RouteInformation get value => _currentValue;

  @override
  void dispose() {
    _delegate.removeListener(_onDelegateChanged);
    super.dispose();
  }
}

/// A custom RouterConfig that uses a filtering RouteInformationProvider.
class FilteringRouterConfig implements RouterConfig<RouteMatchList> {
  final GoRouter _router;

  @override
  final RouteInformationProvider routeInformationProvider;

  FilteringRouterConfig(this._router, this.routeInformationProvider);

  GoRouter get rawRouter => _router;

  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    return _router.push<T>(location, extra: extra);
  }

  void go(String location, {Object? extra}) {
    _router.go(location, extra: extra);
  }

  void pop<T extends Object?>([T? result]) {
    _router.pop<T>(result);
  }

  @override
  RouteInformationParser<RouteMatchList> get routeInformationParser =>
      _router.routeInformationParser;

  @override
  RouterDelegate<RouteMatchList> get routerDelegate => _router.routerDelegate;

  @override
  BackButtonDispatcher get backButtonDispatcher => _router.backButtonDispatcher;
}

/// Helper provider to access the underlying GoRouter if needed
final appGoRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appRouterProvider);
  if (config is FilteringRouterConfig) {
    return config.rawRouter;
  }
  if (config is GoRouter) {
    return config;
  }
  throw StateError('appRouter is neither FilteringRouterConfig nor GoRouter');
});
