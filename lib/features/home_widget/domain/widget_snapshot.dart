/// SIM Shield — Home-screen widget snapshot (G4)
///
/// The single payload the native home-screen widgets render from. It is a
/// plain JSON string in shared storage, which is what makes the widget work
/// with no network and with the app not running: Android reads
/// `HomeWidgetPreferences`, iOS reads the App Group `UserDefaults`, and
/// neither needs a Flutter engine, a session, or a socket.
///
/// Everything in this file is pure Dart on purpose — no plugin, no Riverpod,
/// no Supabase — so the selection and formatting rules are unit-testable
/// without a device.
///
/// **Nothing sensitive goes in here.** The payload lands in a world-readable-
/// to-the-launcher store and is rendered on a screen anyone standing nearby
/// can see, so it carries no phone numbers (only a masked tail), no ICCIDs, no
/// wallet balance and no account identifiers beyond the row ids needed for the
/// tap deep-link.
library;

import 'dart:convert';

import 'package:keep_sims/features/esim/domain/entities/user_esim.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

/// Schema version stamped into every payload.
///
/// The native renderers draw the "open the app" placeholder instead of a
/// payload whose schema they do not recognise. An old widget showing a stale
/// number confidently is worse than one that admits it needs the app.
const int kWidgetSnapshotSchema = 1;

/// How many subjects the payload carries. The small widget uses the first, the
/// medium one uses the first three; the spare rows cost a few bytes and save a
/// republish when a layout grows.
const int kWidgetMaxSubjects = 5;

/// What the widget is counting down for a given row.
enum WidgetSubjectKind {
  /// A purchased eSIM — has a real data-remaining number.
  esim,

  /// A physical SIM line — has no data metric anywhere in this product, so it
  /// counts down validity instead (that is the thing KeepSIMs protects).
  line,
}

/// Drives the accent colour and the ordering. Not a health score — the
/// dashboard's [SimLineHealth] answers a different question (is protection
/// configured), this one answers "is this about to die".
enum WidgetSeverity { critical, warning, ok, paused }

/// One row of the widget.
class WidgetSubject {
  /// Row id of the underlying `sim_lines` / `user_esims` record. Present only
  /// so a tap can deep-link to the right screen.
  final String id;
  final WidgetSubjectKind kind;

  /// Nickname, bundle name, or a masked number — never a full phone number.
  final String title;
  final String subtitle;

  /// The big number, already formatted ("3.2 GB", "17").
  final String metric;

  /// What the big number means ("data left", "days left").
  final String metricLabel;

  /// True when [metric] *is* the day countdown, i.e. the native renderer may
  /// recompute it from [depletesAt] instead of trusting the published text.
  /// False for eSIM megabytes, which cannot move without a sync.
  final bool metricIsCountdown;

  /// The fixed part of a composed subtitle ("eSIM"), to which the native side
  /// appends a freshly-computed day phrase. Empty means "render [subtitle] as
  /// published".
  final String subtitlePrefix;

  /// 0–100, or -1 when there is no meaningful fraction to draw.
  final int percent;

  /// Null when nothing in the data supports a countdown.
  final int? daysRemaining;

  /// Absolute instant the subject is predicted to run out, so the native side
  /// can re-derive the countdown hours later without the app running.
  final DateTime? depletesAt;

  final WidgetSeverity severity;

  /// `keepsims://widget/...` — resolved by [widgetDeepLinkToRoute].
  final String deepLink;

  const WidgetSubject({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.metricIsCountdown,
    required this.subtitlePrefix,
    required this.percent,
    required this.daysRemaining,
    required this.depletesAt,
    required this.severity,
    required this.deepLink,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'subtitle': subtitle,
    'metric': metric,
    'metric_label': metricLabel,
    'metric_is_countdown': metricIsCountdown,
    'subtitle_prefix': subtitlePrefix,
    'percent': percent,
    'days_remaining': daysRemaining,
    'depletes_at_ms': depletesAt?.toUtc().millisecondsSinceEpoch,
    'severity': severity.name,
    'deep_link': deepLink,
  };
}

/// The whole payload.
class WidgetSnapshot {
  final bool signedIn;
  final DateTime generatedAt;
  final List<WidgetSubject> subjects;

  /// Shown when [subjects] is empty — says *why* it is empty rather than
  /// leaving a blank tile.
  final String emptyMessage;

  const WidgetSnapshot({
    required this.signedIn,
    required this.generatedAt,
    required this.subjects,
    required this.emptyMessage,
  });

  Map<String, dynamic> toJson() => {
    'schema': kWidgetSnapshotSchema,
    'signed_in': signedIn,
    'generated_at_ms': generatedAt.toUtc().millisecondsSinceEpoch,
    'empty_message': emptyMessage,
    'subjects': subjects.map((s) => s.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  /// The signed-out payload. Deliberately carries no leftover rows: signing
  /// out has to clear the home screen too, or the previous user's lines stay
  /// visible on the device forever.
  factory WidgetSnapshot.signedOut(DateTime now) => WidgetSnapshot(
    signedIn: false,
    generatedAt: now,
    subjects: const [],
    emptyMessage: 'Sign in to see your SIMs',
  );
}

/// Formats megabytes the way the rest of the app does: GB above 1024, one
/// decimal, no trailing `.0`.
String formatDataRemaining(int megabytes) {
  if (megabytes <= 0) return '0 MB';
  if (megabytes < 1024) return '$megabytes MB';
  final double gb = megabytes / 1024;
  final String text = gb >= 100 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} GB';
}

/// Last four digits only, e.g. `+968 9123 4567` → `•••• 4567`.
///
/// A home-screen widget is read by whoever is looking at the phone; a full
/// number on it is a leak the user never opted into.
String maskPhoneNumber(String phoneNumber) {
  final String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return '••••';
  return '•••• ${digits.substring(digits.length - 4)}';
}

/// Whole days from [now] to [when], rounded up so "in 6 hours" reads as 1 day
/// rather than 0. Negative when already past.
int daysBetween(DateTime now, DateTime when) {
  final int ms = when.toUtc().difference(now.toUtc()).inMilliseconds;
  if (ms <= 0) return (ms / Duration.millisecondsPerDay).floor();
  return (ms / Duration.millisecondsPerDay).ceil();
}

/// The unit line under a day count: "days left" / "day left" / "expired".
///
/// Mirrored verbatim in `KeepSimsWidgetProvider.kt` and `KeepSimsWidget.swift`,
/// which re-derive the countdown at render time so a widget on a phone that
/// has not opened the app for a week still shows the right number. Change one,
/// change all three.
String countdownLabel(int days) {
  if (days <= 0) return 'expired';
  return days == 1 ? 'day left' : 'days left';
}

/// The inline form: "17 days left", "1 day left", "expired".
String countdownPhrase(int days) {
  if (days <= 0) return 'expired';
  return '$days ${days == 1 ? 'day' : 'days'} left';
}

/// Builds the payload from whatever the app last managed to load.
///
/// Every input is nullable/empty-tolerant because this runs against the
/// offline cache as often as against the network: a snapshot built from three
/// stale lines and no eSIMs is a valid snapshot, and it is the one that has to
/// render on a plane.
WidgetSnapshot buildWidgetSnapshot({
  required bool signedIn,
  required DateTime now,
  List<SimLine> lines = const [],
  List<UserEsim> esims = const [],
  List<UsageForecast> forecasts = const [],
}) {
  if (!signedIn) return WidgetSnapshot.signedOut(now);

  final Map<String, UsageForecast> forecastByLine = {
    for (final f in forecasts)
      if (f.simLineId != null) f.simLineId!: f,
  };
  final Map<String, UsageForecast> forecastByEsim = {
    for (final f in forecasts)
      if (f.esimId != null) f.esimId!: f,
  };

  final subjects = <WidgetSubject>[
    for (final e in esims)
      if (_isRenderableEsim(e)) _esimSubject(e, forecastByEsim[e.id], now),
    for (final l in lines)
      if (l.status != 'deleted') _lineSubject(l, forecastByLine[l.id], now),
  ];

  subjects.sort(_byUrgency);

  return WidgetSnapshot(
    signedIn: true,
    generatedAt: now,
    subjects: subjects.take(kWidgetMaxSubjects).toList(),
    emptyMessage: 'Add a SIM line to start protecting it',
  );
}

/// An eSIM that was ordered but never delivered has no numbers worth showing.
///
/// Deliberately keyed on `status` alone: `UserEsim.lpaActivationCode` and
/// `qrCodeUrl` read empty for every row in this database (the repository maps
/// column names the `user_esims` table does not have — see the G4 write-up),
/// so anything gated on them would silently hide every eSIM.
bool _isRenderableEsim(UserEsim e) {
  const dead = {'pending', 'failed', 'cancelled', 'refunded', 'revoked'};
  return !dead.contains(e.status);
}

WidgetSubject _esimSubject(UserEsim e, UsageForecast? forecast, DateTime now) {
  final int remaining = e.dataRemainingMb < 0 ? 0 : e.dataRemainingMb;
  final int percent = e.dataTotalMb > 0
      ? (remaining / e.dataTotalMb * 100).round().clamp(0, 100)
      : -1;
  // The bundle's own expiry wins; G1's fitted burn-rate prediction fills in for
  // a bundle whose expiry the supplier never returned.
  final DateTime? runsOutAt = e.expiresAt ?? forecast?.predictedDepletionAt;
  final int? days = runsOutAt == null ? null : daysBetween(now, runsOutAt);

  return WidgetSubject(
    id: e.id,
    kind: WidgetSubjectKind.esim,
    title: e.bundleName,
    subtitle: days == null ? 'eSIM' : 'eSIM · ${countdownPhrase(days)}',
    metric: formatDataRemaining(remaining),
    metricLabel: 'data left',
    metricIsCountdown: false,
    subtitlePrefix: 'eSIM',
    percent: percent,
    daysRemaining: days,
    // Only the *expiry* half of an eSIM ticks on a clock; the megabytes do not
    // move without a sync, so the native side may recompute the day count but
    // must render `metric` verbatim. `generated_at` is what says how stale it is.
    depletesAt: runsOutAt,
    severity: _esimSeverity(e, percent, days),
    deepLink: 'keepsims://widget/esim',
  );
}

WidgetSeverity _esimSeverity(UserEsim e, int percent, int? days) {
  if (e.status == 'expired' || e.status == 'depleted') {
    return WidgetSeverity.critical;
  }
  if (days != null && days <= 0) return WidgetSeverity.critical;
  if (percent >= 0 && percent <= 10) return WidgetSeverity.critical;
  if (days != null && days <= 3) return WidgetSeverity.critical;
  if (percent >= 0 && percent <= 25) return WidgetSeverity.warning;
  if (days != null && days <= 7) return WidgetSeverity.warning;
  return WidgetSeverity.ok;
}

WidgetSubject _lineSubject(SimLine line, UsageForecast? forecast, DateTime now) {
  // Priority: G1's fitted depletion date, then the carrier validity window,
  // then the next scheduled refill. The first is a prediction of when the line
  // *dies*; the last is only when we plan to touch it, so it is the weakest.
  final DateTime? depletesAt =
      forecast?.predictedDepletionAt ??
      line.validityExpiresAt ??
      line.nextTopupDue;
  final int? days = depletesAt == null ? null : daysBetween(now, depletesAt);

  final bool paused = line.protectionPaused || line.status == 'paused';
  final int leadDays = forecast?.alertLeadDays ?? 7;

  final WidgetSeverity severity = paused
      ? WidgetSeverity.paused
      : days == null
      ? WidgetSeverity.ok
      : days <= leadDays
      ? WidgetSeverity.critical
      : days <= 21
      ? WidgetSeverity.warning
      : WidgetSeverity.ok;

  final String title = (line.nickname?.trim().isNotEmpty ?? false)
      ? line.nickname!.trim()
      : maskPhoneNumber(line.phoneNumber);

  final String subtitle = paused
      ? 'Protection paused'
      : forecast == null
      ? 'SIM line'
      : forecast.isMeasured
      ? 'Measured from your refills'
      : 'Estimated';

  return WidgetSubject(
    id: line.id,
    kind: WidgetSubjectKind.line,
    title: title,
    subtitle: subtitle,
    metric: days == null ? '—' : (days <= 0 ? '0' : '$days'),
    metricLabel: days == null ? 'no expiry known' : countdownLabel(days),
    metricIsCountdown: days != null,
    subtitlePrefix: '',
    percent: -1,
    daysRemaining: days,
    depletesAt: depletesAt,
    severity: severity,
    deepLink: 'keepsims://widget/line/${line.id}',
  );
}

/// Most urgent first, paused always last. Within a severity band the smaller
/// countdown wins, then the emptier eSIM, then the title so the order does not
/// shuffle between republishes of identical data.
int _byUrgency(WidgetSubject a, WidgetSubject b) {
  final int bySeverity = a.severity.index.compareTo(b.severity.index);
  if (bySeverity != 0) return bySeverity;

  final int aDays = a.daysRemaining ?? 1 << 30;
  final int bDays = b.daysRemaining ?? 1 << 30;
  if (aDays != bDays) return aDays.compareTo(bDays);

  final int aPct = a.percent < 0 ? 101 : a.percent;
  final int bPct = b.percent < 0 ? 101 : b.percent;
  if (aPct != bPct) return aPct.compareTo(bPct);

  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Maps a widget tap back to a GoRouter location. Returns null for anything
/// unrecognised — a widget from an older install must never be able to steer
/// the app somewhere arbitrary.
String? widgetDeepLinkToRoute(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != 'keepsims' || uri.host != 'widget') return null;

  final segments = uri.pathSegments;
  if (segments.isEmpty) return '/home';

  switch (segments.first) {
    case 'line':
      if (segments.length < 2 || segments[1].isEmpty) return '/sim-lines';
      return '/sim-lines/detail/${segments[1]}';
    case 'esim':
      return '/esim';
    case 'home':
      return '/home';
    default:
      return null;
  }
}
