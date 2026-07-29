//
//  KeepSimsWidgetView.swift
//  SIM Shield — home-screen widget (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//
//  Deliberately the same information hierarchy as the Android layout: brand +
//  freshness, then the single subject that is closest to dying, then the
//  runners-up on the medium family only. A traveller glancing at this should
//  get one number, not a table.
//

import SwiftUI
import WidgetKit

struct KeepSimsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KeepSimsEntry

    private var subjects: [KeepSimsSubject] { entry.payload?.subjects ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let payload = entry.payload, payload.signedIn, let primary = subjects.first {
                KeepSimsPrimaryView(subject: primary, now: entry.date)

                if family != .systemSmall, subjects.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(subjects.dropFirst().prefix(2)) { subject in
                            KeepSimsRowView(subject: subject, now: entry.date)
                        }
                    }
                    .padding(.top, 2)
                }
            } else {
                Text(placeholderMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.keepSimsSecondaryText)
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .widgetURLCompat(subjects.first?.deepLink ?? "keepsims://widget/home")
    }

    private var header: some View {
        HStack {
            Text("KEEPSIMS")
                .font(.system(size: 11))
                .tracking(1.2)
                .foregroundColor(.keepSimsTertiaryText)
            Spacer()
            if let payload = entry.payload {
                Text(KeepSimsCountdown.freshness(since: payload.generatedAt, now: entry.date))
                    .font(.system(size: 11))
                    .foregroundColor(.keepSimsTertiaryText.opacity(0.7))
            }
        }
    }

    private var placeholderMessage: String {
        guard let payload = entry.payload else { return "Open KeepSIMs to set this up" }
        if !payload.signedIn { return "Sign in to see your SIMs" }
        return payload.emptyMessage.isEmpty
            ? "Open KeepSIMs to set this up"
            : payload.emptyMessage
    }
}

private struct KeepSimsPrimaryView: View {
    let subject: KeepSimsSubject
    let now: Date

    var body: some View {
        let days = KeepSimsCountdown.days(until: subject.depletesAtMs, now: now)
        let severity = KeepSimsCountdown.severity(for: subject, days: days)
        let accent = Color.keepSimsAccent(severity)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(subject.title)
                    .font(.system(size: 13))
                    .foregroundColor(.keepSimsPrimaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(KeepSimsCountdown.metric(for: subject, days: days))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(KeepSimsCountdown.metricLabel(for: subject, days: days))
                    .font(.system(size: 12))
                    .foregroundColor(.keepSimsSecondaryText)
                    .lineLimit(1)
            }

            if subject.percent >= 0 && subject.percent <= 100 {
                KeepSimsProgressBar(percent: subject.percent)
                    .padding(.top, 2)
            }

            Text(KeepSimsCountdown.subtitle(for: subject, days: days))
                .font(.system(size: 11))
                .foregroundColor(.keepSimsTertiaryText)
                .lineLimit(1)
        }
    }
}

private struct KeepSimsRowView: View {
    let subject: KeepSimsSubject
    let now: Date

    var body: some View {
        let days = KeepSimsCountdown.days(until: subject.depletesAtMs, now: now)
        let severity = KeepSimsCountdown.severity(for: subject, days: days)

        return HStack(spacing: 6) {
            Circle()
                .fill(Color.keepSimsAccent(severity))
                .frame(width: 6, height: 6)
            Text(subject.title)
                .font(.system(size: 12))
                .foregroundColor(.keepSimsSecondaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(
                "\(KeepSimsCountdown.metric(for: subject, days: days)) "
                    + KeepSimsCountdown.metricLabel(for: subject, days: days)
            )
            .font(.system(size: 12))
            .foregroundColor(.keepSimsTertiaryText)
            .lineLimit(1)
        }
    }
}

/// Always brand cyan: the fraction is a fact, and severity is carried by the
/// metric colour and the dot instead.
struct KeepSimsProgressBar: View {
    let percent: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Color.keepSimsAccent("ok"))
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, percent))) / 100)
            }
        }
        .frame(height: 5)
    }
}

extension View {
    /// `widgetURL` takes a URL, and a malformed deep link should leave the
    /// widget tappable-to-app rather than untappable.
    @ViewBuilder
    func widgetURLCompat(_ link: String) -> some View {
        if let url = URL(string: link) {
            self.widgetURL(url)
        } else {
            self
        }
    }
}
