/// SIM Shield — App Constants
library;

abstract final class AppConstants {
  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'SIM Shield';
  static const String appTagline = 'Protect your SIM, wherever you are.';
  static const String appVersion = '0.1.0';

  // ── API / Timeouts ────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 15);
  static const Duration debounceDelay = Duration(milliseconds: 400);

  // ── Pagination ────────────────────────────────────────────
  static const int defaultPageSize = 20;

  // ── Wallet ────────────────────────────────────────────────
  static const double defaultReferralReward = 2.00;
  static const double minTopupAmount = 0.25;

  // ── Health Score Thresholds ────────────────────────────────
  static const int healthGreenThreshold = 60;
  static const int healthAmberThreshold = 30;

  // ── Animation Durations ───────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);

  // ── Supabase Tables ───────────────────────────────────────
  static const String tableProfiles = 'profiles';
  static const String tableSimLines = 'sim_lines';
  static const String tableWallets = 'wallets';
  static const String tableWalletTransactions = 'wallet_transactions';
  static const String tableCountries = 'countries';
  static const String tableCarriers = 'carriers';
  static const String tableCarrierRules = 'carrier_rules';
  static const String tableScheduledTopups = 'scheduled_topups';
  static const String tableTopupExecutions = 'topup_executions';
  static const String tableLineActivityLog = 'line_activity_log';
  static const String tableNotifications = 'notifications';
  static const String tableAlertSettings = 'alert_settings';
  static const String tablePaymentMethods = 'payment_methods';
  static const String tableReferrals = 'referrals';
  static const String tableHouseholdMembers = 'household_members';
  static const String tableUserPreferences = 'user_preferences';
  static const String tableNotificationChannels = 'notification_channels';
}
