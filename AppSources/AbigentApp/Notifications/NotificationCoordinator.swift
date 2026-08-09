import AbigentRuntime
import Foundation
import UserNotifications

actor NotificationCoordinator {
    func deliver(_ intent: NotificationIntent) async {
        let center = UNUserNotificationCenter.current()
        let authorizationStatus = await authorizationStatus(for: center)
        if authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let content = UNMutableNotificationContent()
        content.title = intent.decision == .attention ? "Codex 需要你操作" : "Codex 任务已完成"
        content.body = intent.task.title
        content.sound = .default
        let identifier = "\(intent.task.id.rawValue):\(intent.task.state.rawValue):\(intent.task.updatedAt.timeIntervalSince1970)"
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    private func authorizationStatus(
        for center: UNUserNotificationCenter
    ) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}
