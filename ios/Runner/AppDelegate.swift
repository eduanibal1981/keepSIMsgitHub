import Flutter
import UIKit
import CoreTelephony

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register eSIM platform channel on the root FlutterViewController
    if let controller = window?.rootViewController as? FlutterViewController {
      setupEsimChannel(controller: controller)
      let timeZoneChannel = FlutterMethodChannel(
        name: "com.keep_sims/timezone",
        binaryMessenger: controller.binaryMessenger
      )
      timeZoneChannel.setMethodCallHandler { call, result in
        if call.method == "getTimeZoneId" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      // G4: Lock Screen / Dynamic Island live activity for data remaining.
      LiveActivityBridge.register(controller: controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Registers the `com.keep_sims/esim` MethodChannel and handles
  /// the `isEsimSupported` call using CoreTelephony.
  private func setupEsimChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.keep_sims/esim",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard call.method == "isEsimSupported" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.checkEsimSupport() ?? false)
    }
  }

  /// Checks whether the device supports eSIM provisioning.
  ///
  /// Uses `CTCellularPlanSupportsEsim()` available on iOS 12+.
  /// Returns `false` on older iOS versions.
  private func checkEsimSupport() -> Bool {
    if #available(iOS 12.0, *) {
        return CTCellularPlanProvisioning().supportsCellularPlan()
    }
    return false
  }
}
