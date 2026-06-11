import Foundation
import UserNotifications

/// 발신자 정보 Local Notification (Android showCallerNotification 이식)
class NotificationManager {

    private static let callerNotificationId = "du_who_caller"

    /// Notification 권한 요청 (앱 시작 시 1회)
    static func requestUserNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 발신자 교직원 정보 알림 표시.
    /// 본문 구성은 Android와 동일: 부서 · 직위(교직원만) · 위치(학생은 건물명만)
    static func showCallerNotification(staffInfo: StaffInfo, rawNumber: String, isStaffUser: Bool) {
        var parts: [String] = []
        if !staffInfo.department.isEmpty {
            parts.append(staffInfo.department)
        }
        if isStaffUser && !staffInfo.title.isEmpty {
            parts.append(staffInfo.title)
        }
        var body = parts.joined(separator: " · ")
        if !staffInfo.location.isEmpty {
            let location = isStaffUser ? staffInfo.location : summarizeLocation(staffInfo.location)
            body += body.isEmpty ? location : "  \(location)"
        }
        if body.isEmpty { body = rawNumber }

        let content = UNMutableNotificationContent()
        content.title = "📞 \(staffInfo.name)"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: callerNotificationId,
            content: content,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.add(request)

        // 30초 후 자동 제거 (Android setTimeoutAfter 대응)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            center.removeDeliveredNotifications(withIdentifiers: [callerNotificationId])
        }
    }

    /// 학생용: 건물명만 추출 ("공학관 301호" → "공학관")
    private static func summarizeLocation(_ location: String) -> String {
        let parts = location.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let summary = parts.prefix { part in
            !part.contains(where: { $0.isNumber })
        }.joined(separator: " ")
        if !summary.isEmpty { return summary }
        return parts.first ?? location
    }
}
