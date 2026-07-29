//
//  KeepSimsWidgetBundle.swift
//  SIM Shield — widget extension entry point (G4)
//
//  ⚠️ NOT COMPILED — see the header of KeepSimsWidgetPayload.swift.
//

import SwiftUI
import WidgetKit

@main
struct KeepSimsWidgetBundle: WidgetBundle {
    var body: some Widget {
        KeepSimsWidget()

        // Live Activities are iOS 16.1+. The extension itself targets 14.0 so
        // the home-screen widget still ships to older devices.
        if #available(iOS 16.1, *) {
            KeepSimsLiveActivity()
        }
    }
}
