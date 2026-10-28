import Flutter
import UIKit
import CoreTelephony
import ContactsUI
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {
  private var contactPickerResult: FlutterResult?
  private var smsComposerResult: FlutterResult?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register eSIM platform channel on the root FlutterViewController
    if let controller = window?.rootViewController as? FlutterViewController {
      setupEsimChannel(controller: controller)
      setupContactsChannel(messenger: controller.binaryMessenger)
      setupInvitationChannel(messenger: controller.binaryMessenger)
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceContactPicker") {
      setupContactsChannel(messenger: registrar.messenger())
      setupInvitationChannel(messenger: registrar.messenger())
    }
  }

  private func setupInvitationChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.keep_sims/invitations", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "composeSms" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self, MFMessageComposeViewController.canSendText(),
            let args = call.arguments as? [String: Any],
            let phone = args["phone"] as? String, let body = args["body"] as? String,
            phone.range(of: "^\\+[1-9][0-9]{6,14}$", options: .regularExpression) != nil,
            body.count <= 2000, self.smsComposerResult == nil,
            var presenter = self.window?.rootViewController else {
        result(false)
        return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      self.smsComposerResult = result
      let composer = MFMessageComposeViewController()
      composer.messageComposeDelegate = self
      composer.recipients = [phone]
      composer.body = body
      presenter.present(composer, animated: true)
    }
  }

  func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                   didFinishWith result: MessageComposeResult) {
    let callback = smsComposerResult
    smsComposerResult = nil
    controller.dismiss(animated: true) { callback?(true) }
    // Returning means the composer was opened; it does not prove delivery.
  }

  private func setupContactsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.keep_sims/contacts", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickPhoneNumber" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self, var presenter = self.window?.rootViewController else {
        result(FlutterError(code: "unavailable", message: "Contacts unavailable", details: nil))
        return
      }
      guard self.contactPickerResult == nil else {
        result(FlutterError(code: "busy", message: "Contacts already open", details: nil))
        return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      self.contactPickerResult = result
      let picker = CNContactPickerViewController()
      picker.delegate = self
      picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
      picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
      picker.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")
      picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
      presenter.present(picker, animated: true)
    }
  }

  private func finishContactPicker(_ number: String?) {
    let result = contactPickerResult
    contactPickerResult = nil
    result?(number)
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    finishContactPicker(nil)
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    finishContactPicker(contact.phoneNumbers.first?.value.stringValue)
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
    finishContactPicker((contactProperty.value as? CNPhoneNumber)?.stringValue)
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
