//
//  KeepSimsWidget.swift
//  SIM Shield — home-screen widget (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//
//  `kind` must stay "KeepSimsWidget": it is what `HomeWidget.updateWidget`
//  passes as `iOSName` from `home_widget_publisher.dart`.
//

import SwiftUI
import WidgetKit

struct KeepSimsEntry: TimelineEntry {
    let date: Date
    let payload: KeepSimsPayload?
}

struct KeepSimsProvider: TimelineProvider {

    func placeholder(in context: Context) -> KeepSimsEntry {
        KeepSimsEntry(date: Date(), payload: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (KeepSimsEntry) -> Void) {
        completion(KeepSimsEntry(date: Date(), payload: KeepSimsPayload.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeepSimsEntry>) -> Void) {
        let payload = KeepSimsPayload.load()
        let now = Date()

        // One entry per instant the day count actually changes, rather than a
        // fixed cadence: the number ticks over at `depletesAt - k days`, and
        // refreshing at any other time redraws identical pixels on somebody's
        // battery. WidgetKit budgets reloads, so spending them precisely is the
        // difference between a countdown that is right for a week with the app
        // closed and one that quietly goes stale.
        var dates: Set<Date> = []
        for subject in payload?.subjects ?? [] {
            guard let ms = subject.depletesAtMs, ms > 0 else { continue }
            let depletesAt = Date(timeIntervalSince1970: ms / 1000)
            for k in 0..<14 {
                let tick = depletesAt.addingTimeInterval(-Double(k) * 86_400)
                if tick > now { dates.insert(tick) }
            }
        }

        var refreshes = dates.sorted().prefix(12).map { $0 }
        if refreshes.isEmpty {
            // Nothing to count down; still refresh so "updated Xh ago" is honest.
            refreshes = (1...6).map { now.addingTimeInterval(Double($0) * 3_600) }
        }

        let entries =
            [KeepSimsEntry(date: now, payload: payload)]
            + refreshes.map { KeepSimsEntry(date: $0, payload: payload) }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct KeepSimsWidget: Widget {
    let kind = "KeepSimsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeepSimsProvider()) { entry in
            KeepSimsWidgetView(entry: entry)
                .widgetBackgroundCompat(Color.keepSimsSurface)
        }
        .configurationDisplayName("KeepSIMs")
        .description("Data and validity left on your SIMs, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension View {
    /// iOS 17 requires the background to be declared with `containerBackground`
    /// or the widget is rejected at render time; earlier versions have no such
    /// modifier.
    @ViewBuilder
    func widgetBackgroundCompat(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self.background(color)
        }
    }
}
