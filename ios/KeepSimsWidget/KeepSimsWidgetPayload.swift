//
//  KeepSimsWidgetPayload.swift
//  SIM Shield — home-screen widget (G4)
//
//  Decodes `ks_widget_payload`, the JSON blob the Flutter side writes into the
//  App Group's UserDefaults every time it loads SIM lines / eSIMs / forecasts.
//  Nothing here touches the network or a Flutter engine: the widget reads a
//  file the app already wrote, which is what lets it render on a plane.
//
//  ⚠️ NOT COMPILED. Written on a Windows workstation with no Xcode and no Apple
//  Developer account (owner checklist #2). Treat as a first draft that has
//  never been through a compiler — see the G4 write-up in
//  doc/PRODUCTION_PLAN_REVIEW.md.
//
//  The shape is defined by `widget_snapshot.dart`, and the two rules below are
//  mirrored from `KeepSimsWidgetProvider.kt`. Change one, change all three.
//

import Foundation
import SwiftUI

enum KeepSimsWidgetConstants {
    /// Must match `kIosAppGroupId` in `home_widget_publisher.dart` and the App
    /// Group capability on *both* the Runner and the widget extension targets.
    static let appGroupId = "group.com.keep_sims.widget"

    /// Must match `kWidgetPayloadKey` in `home_widget_publisher.dart`.
    static let payloadKey = "ks_widget_payload"

    /// Must match `kWidgetSnapshotSchema` in `widget_snapshot.dart`. A payload
    /// with any other schema draws the "open the app" placeholder — a widget
    /// showing a confidently wrong number is worse than one that admits it is
    /// out of date.
    static let supportedSchema = 1

    static let dayMillis: Double = 86_400_000
}

struct KeepSimsSubject: Decodable, Identifiable {
    let id: String
    let kind: String
    let title: String
    let subtitle: String
    let metric: String
    let metricLabel: String

    /// True when `metric` *is* the day countdown, so it may be re-derived from
    /// `depletesAtMs`. False for eSIM megabytes, which cannot move without a
    /// sync and must be rendered exactly as published.
    let metricIsCountdown: Bool

    /// Fixed part of a composed subtitle ("eSIM"); empty means render
    /// `subtitle` as published.
    let subtitlePrefix: String

    /// 0…100, or -1 when there is no meaningful fraction to draw.
    let percent: Int
    let daysRemaining: Int?
    let depletesAtMs: Double?
    let severity: String
    let deepLink: String

    var isEsim: Bool { kind == "esim" }
}

struct KeepSimsPayload: Decodable {
    let schema: Int
    let signedIn: Bool
    let generatedAtMs: Double
    let emptyMessage: String
    let subjects: [KeepSimsSubject]

    var generatedAt: Date {
        Date(timeIntervalSince1970: generatedAtMs / 1000)
    }

    /// Reads and validates the payload. Returns nil for "there is nothing this
    /// build can render", which the views turn into a placeholder.
    static func load(
        userDefaults: UserDefaults? = UserDefaults(
            suiteName: KeepSimsWidgetConstants.appGroupId
        )
    ) -> KeepSimsPayload? {
        guard
            let raw = userDefaults?.string(forKey: KeepSimsWidgetConstants.payloadKey),
            let data = raw.data(using: .utf8)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let payload = try? decoder.decode(KeepSimsPayload.self, from: data),
              payload.schema == KeepSimsWidgetConstants.supportedSchema
        else { return nil }

        return payload
    }
}

// MARK: - Re-derivation
//
// The one thing that changes while the app is not running is the day count, so
// it is computed at render time from an absolute instant rather than trusted
// from the payload.

enum KeepSimsCountdown {

    /// Whole days until `date`, rounded away from zero. Mirrors `daysBetween`
    /// in `widget_snapshot.dart` and `daysUntil` in `KeepSimsWidgetProvider.kt`.
    static func days(until depletesAtMs: Double?, now: Date = Date()) -> Int? {
        guard let ms = depletesAtMs, ms > 0 else { return nil }
        let diff = ms - now.timeIntervalSince1970 * 1000
        let days = diff / KeepSimsWidgetConstants.dayMillis
        return diff <= 0 ? Int(floor(days)) : Int(ceil(days))
    }

    /// "days left" / "day left" / "expired".
    static func label(_ days: Int) -> String {
        if days <= 0 { return "expired" }
        return days == 1 ? "day left" : "days left"
    }

    /// "17 days left" / "1 day left" / "expired".
    static func phrase(_ days: Int) -> String {
        if days <= 0 { return "expired" }
        return "\(days) \(days == 1 ? "day" : "days") left"
    }

    static func metric(for subject: KeepSimsSubject, days: Int?) -> String {
        guard subject.metricIsCountdown, let days else { return subject.metric }
        return days <= 0 ? "0" : "\(days)"
    }

    static func metricLabel(for subject: KeepSimsSubject, days: Int?) -> String {
        guard subject.metricIsCountdown, let days else { return subject.metricLabel }
        return label(days)
    }

    static func subtitle(for subject: KeepSimsSubject, days: Int?) -> String {
        guard !subject.subtitlePrefix.isEmpty, let days else { return subject.subtitle }
        return "\(subject.subtitlePrefix) · \(phrase(days))"
    }

    /// The published severity, downgraded once the recomputed countdown has run
    /// out — "0 days left" printed in calm green makes people distrust the
    /// whole widget.
    static func severity(for subject: KeepSimsSubject, days: Int?) -> String {
        if subject.severity == "paused" { return subject.severity }
        if let days, days <= 0 { return "critical" }
        return subject.severity.isEmpty ? "ok" : subject.severity
    }

    /// "just now" / "14m ago" / "3h ago" / "2d ago".
    static func freshness(since generatedAt: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(generatedAt)
        if elapsed < 60 { return "just now" }
        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

extension Color {
    /// Same palette as `AppColors` in Dart and `accentColor` in the Kotlin
    /// provider.
    static func keepSimsAccent(_ severity: String) -> Color {
        switch severity {
        case "critical": return Color(red: 1.00, green: 0.71, blue: 0.67)  // #FFB4AB
        case "warning":  return Color(red: 1.00, green: 0.73, blue: 0.37)  // #FFB95F
        case "paused":   return Color(red: 0.74, green: 0.79, blue: 0.80)  // #BCC9CD
        default:         return Color(red: 0.30, green: 0.84, blue: 0.96)  // #4CD7F6
        }
    }

    static let keepSimsSurface = Color(red: 0.05, green: 0.08, blue: 0.11)   // #0D141D
    static let keepSimsPrimaryText = Color.white
    static let keepSimsSecondaryText = Color(red: 0.86, green: 0.89, blue: 0.94)
    static let keepSimsTertiaryText = Color(red: 0.74, green: 0.79, blue: 0.80)
}
