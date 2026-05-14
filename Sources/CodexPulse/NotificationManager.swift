import CodexPulseCore
import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private enum Keys {
        static let sentNotificationKeys = "sentNotificationKeys"
    }

    private let userDefaults: UserDefaults
    private let center: UNUserNotificationCenter

    init(
        userDefaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        self.userDefaults = userDefaults
        self.center = center
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .notDetermined else {
                return
            }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func process(data: RateLimitData?, settings: CodexPulseSettings) {
        guard settings.notificationsEnabled else {
            return
        }

        requestAuthorizationIfNeeded()
        var sentKeys = Set(userDefaults.stringArray(forKey: Keys.sentNotificationKeys) ?? [])
        let decisions = NotificationPlanner.decisions(for: data, settings: settings, sentKeys: sentKeys)

        for decision in decisions {
            let content = UNMutableNotificationContent()
            content.title = L10n.notificationTitle(for: decision.kind)
            content.body = L10n.notificationBody(for: decision, settings: settings)
            let request = UNNotificationRequest(
                identifier: "codexpulse-\(decision.deduplicationKey)",
                content: content,
                trigger: nil
            )
            center.add(request)
            sentKeys.insert(decision.deduplicationKey)
        }

        userDefaults.set(Array(sentKeys).sorted(), forKey: Keys.sentNotificationKeys)
    }
}
