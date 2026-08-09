import AbigentRuntime
import Foundation
import UserNotifications

actor NotificationCoordinator {
    func deliver(_ intent: NotificationIntent) async {
        let authorizationStatus = await authorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        let title = intent.decision == .attention ? "Codex 需要你操作" : "Codex 任务已完成"
        let identifier = "\(intent.task.id.rawValue):\(intent.task.state.rawValue):\(intent.task.updatedAt.timeIntervalSince1970)"
        await addNotification(title: title, body: intent.task.title, identifier: identifier)
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func addNotification(title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        await withCheckedContinuation { continuation in
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume()
            }
        }
    }
}
