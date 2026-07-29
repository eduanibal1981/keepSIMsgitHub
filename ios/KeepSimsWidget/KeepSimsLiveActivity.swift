//
//  KeepSimsLiveActivity.swift
//  SIM Shield — Lock Screen / Dynamic Island live activity (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//
//  Shows one SIM's remaining data or validity on the Lock Screen while it
//  matters. The user starts it explicitly from the line detail screen; nothing
//  auto-pins itself to somebody's Lock Screen.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct KeepSimsLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KeepSimsActivityAttributes.self) { context in
            lockScreenView(context)
                .padding(14)
                .background(Color.keepSimsSurface)
        } dynamicIsland: { context in
            let days = KeepSimsCountdown.days(until: context.state.depletesAtMs)
            let severity = liveSeverity(context.state.severity, days: days)
            let accent = Color.keepSimsAccent(severity)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.title)
                        .font(.system(size: 13))
                        .foregroundColor(.keepSimsPrimaryText)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(liveMetric(context.state, days: days))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.percent >= 0 {
                        KeepSimsProgressBar(percent: context.state.percent)
                    } else {
                        Text(context.state.subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.keepSimsTertiaryText)
                    }
                }
            } compactLeading: {
                Circle().fill(accent).frame(width: 8, height: 8)
            } compactTrailing: {
                Text(liveMetric(context.state, days: days))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
            } minimal: {
                Circle().fill(accent).frame(width: 8, height: 8)
            }
            .widgetURL(URL(string: deepLink(for: context.attributes)))
        }
    }

    @ViewBuilder
    private func lockScreenView(
        _ context: ActivityViewContext<KeepSimsActivityAttributes>
    ) -> some View {
        let days = KeepSimsCountdown.days(until: context.state.depletesAtMs)
        let severity = liveSeverity(context.state.severity, days: days)
        let accent = Color.keepSimsAccent(severity)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(context.attributes.title)
                    .font(.system(size: 13))
                    .foregroundColor(.keepSimsPrimaryText)
                    .lineLimit(1)
                Spacer()
                Text("KEEPSIMS")
                    .font(.system(size: 10))
                    .tracking(1.2)
                    .foregroundColor(.keepSimsTertiaryText)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(liveMetric(context.state, days: days))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(accent)
                Text(liveMetricLabel(context.state, days: days))
                    .font(.system(size: 12))
                    .foregroundColor(.keepSimsSecondaryText)
            }

            if context.state.percent >= 0 {
                KeepSimsProgressBar(percent: context.state.percent)
            }

            Text(context.state.subtitle)
                .font(.system(size: 11))
                .foregroundColor(.keepSimsTertiaryText)
                .lineLimit(1)
        }
    }

    // The same three rules as the home-screen widget: re-derive the day count,
    // never re-derive megabytes, and let an expired countdown force critical.

    private func liveMetric(
        _ state: KeepSimsActivityAttributes.ContentState,
        days: Int?
    ) -> String {
        guard state.metricLabel.contains("day"), let days else { return state.metric }
        return days <= 0 ? "0" : "\(days)"
    }

    private func liveMetricLabel(
        _ state: KeepSimsActivityAttributes.ContentState,
        days: Int?
    ) -> String {
        guard state.metricLabel.contains("day"), let days else { return state.metricLabel }
        return KeepSimsCountdown.label(days)
    }

    private func liveSeverity(_ severity: String, days: Int?) -> String {
        if severity == "paused" { return severity }
        if let days, days <= 0 { return "critical" }
        return severity.isEmpty ? "ok" : severity
    }

    private func deepLink(for attributes: KeepSimsActivityAttributes) -> String {
        attributes.kind == "esim"
            ? "keepsims://widget/esim"
            : "keepsims://widget/line/\(attributes.subjectId)"
    }
}
