import Foundation

public enum DisplayMode: String, CaseIterable, Codable, Sendable {
    case both
    case fiveHour
    case weekly

    public var menuTitle: String {
        switch self {
        case .both:
            "Both windows"
        case .fiveHour:
            "5h window"
        case .weekly:
            "Weekly window"
        }
    }
}

public enum SnapshotSource: String, Codable, Sendable {
    case appServer = "app-server"
    case log = "log"
    case cache = "cache"
}

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercent: Int
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(usedPercent: Int, windowDurationMins: Int?, resetsAt: Int?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let planType: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let rateLimitReachedType: String?

    public init(planType: String?, primary: RateLimitWindow?, secondary: RateLimitWindow?, rateLimitReachedType: String?) {
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.rateLimitReachedType = rateLimitReachedType
    }

    public var isLimited: Bool {
        rateLimitReachedType != nil
    }
}

public struct RateLimitData: Codable, Equatable, Sendable {
    public let snapshot: RateLimitSnapshot
    public let additionalLimits: [String: RateLimitSnapshot]
    public let source: SnapshotSource
    public let fetchedAt: Date
    public let errorMessage: String?

    public init(
        snapshot: RateLimitSnapshot,
        additionalLimits: [String: RateLimitSnapshot],
        source: SnapshotSource,
        fetchedAt: Date,
        errorMessage: String? = nil
    ) {
        self.snapshot = snapshot
        self.additionalLimits = additionalLimits
        self.source = source
        self.fetchedAt = fetchedAt
        self.errorMessage = errorMessage
    }

    public func replacingSource(_ source: SnapshotSource, errorMessage: String? = nil) -> RateLimitData {
        RateLimitData(
            snapshot: snapshot,
            additionalLimits: additionalLimits,
            source: source,
            fetchedAt: fetchedAt,
            errorMessage: errorMessage
        )
    }
}
