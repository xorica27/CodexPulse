import Foundation

public enum EmptyState: Equatable, Sendable {
    case codexNotInstalled
    case noRateLimitData
    case helperUnavailable
    case cachedOnly
    case available

    public var menuMessage: String {
        switch self {
        case .codexNotInstalled:
            "Codex app was not found in /Applications."
        case .noRateLimitData:
            "Open and use Codex once to generate rate-limit data."
        case .helperUnavailable:
            "Codex helper is unavailable right now."
        case .cachedOnly:
            "Showing cached rate-limit data."
        case .available:
            "Codex rate limits are available."
        }
    }
}

public enum EmptyStateClassifier {
    public static func classify(data: RateLimitData?, lastError: Error?) -> EmptyState {
        if let clientError = lastError as? RateLimitClientError,
           case .codexBinaryMissing = clientError {
            return .codexNotInstalled
        }

        guard let data else {
            return lastError == nil ? .noRateLimitData : .helperUnavailable
        }

        let hasWindow = data.snapshot.primary != nil || data.snapshot.secondary != nil
        if data.source == .cache && hasWindow {
            return .cachedOnly
        }

        if !hasWindow {
            return .noRateLimitData
        }

        return .available
    }
}
