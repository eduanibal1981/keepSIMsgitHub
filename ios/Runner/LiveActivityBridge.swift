//
//  LiveActivityBridge.swift
//  SIM Shield — ActivityKit bridge (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//
//  Backs the `com.keep_sims/live_activity` MethodChannel used by
//  `live_activity_service.dart`. Deliberately a plain channel rather than a
//  pub package: `home_widget` does not do Live Activities, and every published
//  alternative would be a dependency this project cannot build or test today.
//
//  Every method is safe to call when Live Activities are unavailable — the
//  Dart side is allowed to fire `update` and `end` blindly.
//

import Flutter
import Foundation

#if canImport(ActivityKit)
    import ActivityKit
#endif

enum LiveActivityBridge {

    static let channelName = "com.keep_sims/live_activity"

    static func register(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            handle(call: call, result: result)
        }
    }

    private static func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(ActivityKit)
            guard #available(iOS 16.1, *) else {
                result(defaultValue(for: call.method))
                return
            }

            let args = call.arguments as? [String: Any] ?? [:]

            switch call.method {
            case "isSupported":
                result(ActivityAuthorizationInfo().areActivitiesEnabled)

            case "start":
                result(start(args))

            case "update":
                update(args)
                result(true)

            case "end":
                end(subjectId: args["subjectId"] as? String)
                result(true)

            case "endAll":
                end(subjectId: nil)
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        #else
            result(defaultValue(for: call.method))
        #endif
    }

    private static func defaultValue(for method: String) -> Any {
        method == "isSupported" ? false : true
    }

    #if canImport(ActivityKit)
        @available(iOS 16.1, *)
        private static func contentState(
            _ args: [String: Any]
        ) -> KeepSimsActivityAttributes.ContentState {
            KeepSimsActivityAttributes.ContentState(
                metric: args["metric"] as? String ?? "",
                metricLabel: args["metricLabel"] as? String ?? "",
                subtitle: args["subtitle"] as? String ?? "",
                percent: args["percent"] as? Int ?? -1,
                severity: args["severity"] as? String ?? "ok",
                depletesAtMs: args["depletesAtMs"] as? Double
            )
        }

        @available(iOS 16.1, *)
        private static func start(_ args: [String: Any]) -> Bool {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
            let subjectId = args["subjectId"] as? String ?? ""

            // One activity per subject. Starting again on a subject that is
            // already pinned updates it rather than stacking a duplicate on the
            // user's Lock Screen.
            if let existing = activity(for: subjectId) {
                Task { await existing.update(using: contentState(args)) }
                return true
            }

            let attributes = KeepSimsActivityAttributes(
                title: args["title"] as? String ?? "",
                kind: args["kind"] as? String ?? "line",
                subjectId: subjectId
            )

            do {
                _ = try Activity.request(
                    attributes: attributes,
                    contentState: contentState(args),
                    pushType: nil
                )
                return true
            } catch {
                NSLog("[live_activity] start failed: \(error.localizedDescription)")
                return false
            }
        }

        @available(iOS 16.1, *)
        private static func update(_ args: [String: Any]) {
            guard let target = activity(for: args["subjectId"] as? String ?? "") else { return }
            let state = contentState(args)
            Task { await target.update(using: state) }
        }

        @available(iOS 16.1, *)
        private static func end(subjectId: String?) {
            for target in Activity<KeepSimsActivityAttributes>.activities
            where subjectId == nil || target.attributes.subjectId == subjectId {
                Task { await target.end(dismissalPolicy: .immediate) }
            }
        }

        @available(iOS 16.1, *)
        private static func activity(for subjectId: String) -> Activity<KeepSimsActivityAttributes>? {
            Activity<KeepSimsActivityAttributes>.activities.first {
                $0.attributes.subjectId == subjectId
            }
        }
    #endif
}
