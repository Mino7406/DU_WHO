import Foundation
import CallKit
import UserNotifications

/// CXCallObserver로 수신 전화를 감지하고 교직원 정보를 알림으로 표시.
/// Android CallReceiver + CallOverlayService 대응.
/// 제약: 앱 프로세스가 살아있을 때만 동작 (iOS 시스템 제약).
class CallKitHandler: NSObject, CXCallObserverDelegate {

    static let shared = CallKitHandler()

    static let userDefaultsDbPathKey = "db_path"
    static let userDefaultsIsStaffKey = "is_staff"

    private var callObserver: CXCallObserver?
    private var handledCallUUIDs = Set<UUID>()

    private override init() {
        super.init()
    }

    func setup() {
        guard callObserver == nil else { return }
        let observer = CXCallObserver()
        observer.setDelegate(self, queue: nil)
        callObserver = observer
        NSLog("[DU-WHO] CallKitHandler setup complete")
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        // 신규 수신 전화만 처리 (발신/종료/중복 제외)
        guard !call.isOutgoing, !call.hasEnded, !call.hasConnected else {
            if call.hasEnded { handledCallUUIDs.remove(call.uuid) }
            return
        }
        guard !handledCallUUIDs.contains(call.uuid) else { return }
        handledCallUUIDs.insert(call.uuid)

        NSLog("[DU-WHO] Incoming call detected: \(call.uuid)")
        handleIncomingCall()
    }

    /// iOS는 CXCall에서 발신 번호를 제공하지 않으므로,
    /// 최근 통화 기록 접근도 불가 → CallKit만으로는 번호 조회 불가.
    /// 단, CXCallDirectoryProvider 없이 번호를 얻는 공식 경로가 없어
    /// 여기서는 DB 경로/사용자 역할 설정 여부만 확인하고
    /// "교내 전화 확인" 안내 알림을 표시한다.
    private func handleIncomingCall() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.userDefaultsDbPathKey) != nil else {
            NSLog("[DU-WHO] db_path not set; skip notification")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "📞 전화 수신 중"
        content.body = "DU-WHO를 열어 발신 번호를 검색해보세요."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "du_who_incoming",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// MethodChannel로 Dart에서 전달받은 번호를 직접 조회할 때 사용.
    /// (수동 조회 또는 향후 확장용)
    func lookupAndNotify(rawNumber: String) {
        let defaults = UserDefaults.standard
        guard let dbPath = defaults.string(forKey: Self.userDefaultsDbPathKey) else { return }
        let isStaff = defaults.bool(forKey: Self.userDefaultsIsStaffKey)

        DispatchQueue.global(qos: .userInitiated).async {
            guard let staff = StaffDatabase.queryStaff(
                phoneNumber: rawNumber,
                databasePath: dbPath,
                isStaffUser: isStaff
            ) else {
                NSLog("[DU-WHO] No staff match for incoming number")
                return
            }
            DispatchQueue.main.async {
                NotificationManager.showCallerNotification(
                    staffInfo: staff,
                    rawNumber: rawNumber,
                    isStaffUser: isStaff
                )
            }
        }
    }
}
