import Foundation
import UserNotifications

/// 利用者への通知。クリップボードの内容は含めない（docs/specs/ui-and-paste.md）。
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, error in
            if let error {
                log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func post(_ body: String) {
        log.notice("notify: \(body, privacy: .public)")
        let content = UNMutableNotificationContent()
        content.title = "ClipboardHistory"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
