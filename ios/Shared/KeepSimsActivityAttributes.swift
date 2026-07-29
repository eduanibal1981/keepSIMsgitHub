//
//  KeepSimsActivityAttributes.swift
//  SIM Shield — Live Activity contract (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//
//  ⚠️ This file must be a member of BOTH targets — Runner (which starts and
//  updates the activity) and KeepSimsWidget (which renders it). ActivityKit
//  matches activities by this type, so two copies with the same name in
//  separate modules will not do; it has to be the same file added twice in
//  Xcode's file inspector.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct KeepSimsActivityAttributes: ActivityAttributes {

    /// The parts that change while the activity is live.
    public struct ContentState: Codable, Hashable {
        /// Pre-formatted big number: "3.2 GB" or "17".
        var metric: String
        /// "data left" / "days left".
        var metricLabel: String
        var subtitle: String
        /// 0…100, or -1 for "no meaningful fraction".
        var percent: Int
        /// critical / warning / ok / paused.
        var severity: String
        /// Absolute instant to re-derive the countdown from, in epoch
        /// milliseconds. Same contract as the home-screen widget: the day count
        /// may be recomputed, the megabytes may not.
        var depletesAtMs: Double?
    }

    /// Fixed for the life of the activity.
    var title: String
    /// "line" or "esim".
    var kind: String
    /// The `sim_lines` / `user_esims` row id, so a tap can deep-link.
    var subjectId: String
}
