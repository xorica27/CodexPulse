import Foundation

public enum RateLimitWindowKind: String, Codable, Equatable, Sendable {
    case fiveHour
    case weekly

    public var menuTitle: String {
        switch self {
        case .fiveHour:
            "5-hour"
        case .weekly:
            "weekly"
        }
    }
}

public enum RateLimitNotificationKind: Equatable, Sendable {
    case threshold(window: RateLimitWindowKind, threshold: Int)
    case staleData
}

public struct RateLimitNotificationDecision: Equatable, Sendable {
    public let kind: RateLimitNotificationKind
    public let title: String
    public let body: String
    public let deduplicationKey: String

    public init(kind: RateLimitNotificationKind, title: String, body: String, deduplicationKey: String) {
        self.kind = kind
        self.title = title
        self.body = body
        self.deduplicationKey = deduplicationKey
    }
}

public enum NotificationPlanner {
    public static func decisions(
        for data: RateLimitData?,
        settings: CodexPulseSettings,
        sentKeys: Set<String>,
        now: Date = Date()
    ) -> [RateLimitNotificationDecision] {
        guard settings.notificationsEnabled, let data else {
            return []
        }

        var decisions: [RateLimitNotificationDecision] = []
        decisions.append(contentsOf: thresholdDecisions(
            window: data.snapshot.primary,
            kind: .fiveHour,
            thresholds: settings.notifyFiveHourThresholds,
            sentKeys: sentKeys
        ))
        decisions.append(contentsOf: thresholdDecisions(
            window: data.snapshot.secondary,
            kind: .weekly,
            thresholds: settings.notifyWeeklyThresholds,
            sentKeys: sentKeys
        ))

        if DisplayFormatter.isStale(data, staleAfterMinutes: settings.staleAfterMinutes, now: now) {
            let key = "stale-\(Int(data.fetchedAt.timeIntervalSince1970))-\(settings.staleAfterMinutes)"
            if !sentKeys.contains(key) {
                decisions.append(RateLimitNotificationDecision(
                    kind: .staleData,
                    title: "CodexPulse data is stale",
                    body: "CodexPulse has not refreshed successfully for \(settings.staleAfterMinutes) minutes.",
                    deduplicationKey: key
                ))
            }
        }

        return decisions
    }

    private static func thresholdDecisions(
        window: RateLimitWindow?,
        kind: RateLimitWindowKind,
        thresholds: [Int],
        sentKeys: Set<String>
    ) -> [RateLimitNotificationDecision] {
        guard let window else {
            return []
        }

        let crossedThresholds = CodexPulseSettings.defaults
            .normalizedThresholdsForPlanner(thresholds)
            .filter { window.remainingPercent <= $0 }

        let resetKey = window.resetsAt.map(String.init) ?? "unknown"

        return crossedThresholds.compactMap { threshold in
            let key = "threshold-\(kind.rawValue)-\(threshold)-\(resetKey)"
            guard !sentKeys.contains(key) else {
                return nil
            }

            return RateLimitNotificationDecision(
                kind: .threshold(window: kind, threshold: threshold),
                title: "Codex \(kind.menuTitle) limit is low",
                body: "\(window.remainingPercent)% remaining in the \(kind.menuTitle) window.",
                deduplicationKey: key
            )
        }
    }
}

private extension CodexPulseSettings {
    func normalizedThresholdsForPlanner(_ thresholds: [Int]) -> [Int] {
        var normalized: [Int] = []
        for threshold in thresholds.sorted(by: >) where (1...100).contains(threshold) {
            if normalized.last != threshold {
                normalized.append(threshold)
            }
        }
        return normalized
    }
}
