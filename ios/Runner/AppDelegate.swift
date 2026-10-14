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

      case "getCallerIdStatus":
        // iOS 는 발신 번호를 읽지 못해 자동 식별은 안 되고, 수신 안내 알림과 수동 조회만 된다
        result([
          "supported": false,
          "enabled": CallKitHandler.isEnabled,
          "notifications": true,
        ])

      case "setCallerIdEnabled":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          UserDefaults.standard.set(enabled, forKey: CallKitHandler.userDefaultsEnabledKey)
        }
        result(nil)

      case "previewCallerId":
        // 실제 교직원 대신 예시 정보와 가상번호로 보여준다
        let number = (call.arguments as? [String: Any])?["number"] as? String ?? "053-850-0000"
        let sample = StaffInfo(
          name: "홍길동 (예시)",
          department: "학생지원팀",
          title: "팀장",
          location: "본관 101호"
        )
        NotificationManager.showCallerNotification(
          staffInfo: sample,
          rawNumber: number,
          isStaffUser: true,
          preview: true
        )
        result(true)

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
