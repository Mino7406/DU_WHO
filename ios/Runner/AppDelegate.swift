import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "du_who/call_overlay",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "saveDbPath":
        if let args = call.arguments as? [String: Any],
           let path = args["path"] as? String {
          UserDefaults.standard.set(path, forKey: CallKitHandler.userDefaultsDbPathKey)
          NSLog("[DU-WHO] saveDbPath: \(path)")
        }
        result(nil)

      case "saveUserRole":
        if let args = call.arguments as? [String: Any],
           let isStaff = args["isStaff"] as? Bool {
          UserDefaults.standard.set(isStaff, forKey: CallKitHandler.userDefaultsIsStaffKey)
          NSLog("[DU-WHO] saveUserRole: isStaff=\(isStaff)")
        }
        result(nil)

      case "lookupNumber":
        if let args = call.arguments as? [String: Any],
           let number = args["number"] as? String {
          CallKitHandler.shared.lookupAndNotify(rawNumber: number)
        }
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationManager.requestUserNotificationAuthorization()
    CallKitHandler.shared.setup()
  }
}
