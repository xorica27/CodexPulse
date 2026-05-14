import CodexPulseCore
import Combine
import Foundation

@MainActor
final class RateLimitStore: ObservableObject {
    private enum Keys {
        static let cachedData = "cachedRateLimitData"
    }

    private let appServerClient = AppServerRateLimitClient()
    private let logFallbackClient = LogFallbackRateLimitClient()
    private let userDefaults: UserDefaults
    private var isRefreshing = false

    @Published var data: RateLimitData? {
        didSet {
            onChange?()
        }
    }

    @Published var lastErrorMessage: String?

    @Published var emptyState: EmptyState = .noRateLimitData

    var onChange: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.data = Self.loadCachedData(from: userDefaults)
    }

    func refresh() {
        if isRefreshing {
            return
        }
        isRefreshing = true
        let cachedData = data

        Task.detached(priority: .utility) { [appServerClient, logFallbackClient, cachedData] in
            let result: RateLimitData
            let lastErrorMessage: String?
            let emptyState: EmptyState
            do {
                result = try appServerClient.fetch()
                lastErrorMessage = nil
                emptyState = EmptyStateClassifier.classify(data: result, lastError: nil)
            } catch {
                let appServerError = error
                do {
                    result = try logFallbackClient.fetch().replacingSource(.log, errorMessage: appServerError.localizedDescription)
                    lastErrorMessage = appServerError.localizedDescription
                    emptyState = EmptyStateClassifier.classify(data: result, lastError: nil)
                } catch {
                    let fallbackError = error
                    let surfacedError: Error
                    if let clientError = appServerError as? RateLimitClientError,
                       case .codexBinaryMissing = clientError {
                        surfacedError = appServerError
                    } else {
                        surfacedError = fallbackError
                    }

                    if let cached = cachedData {
                        result = cached.replacingSource(.cache, errorMessage: surfacedError.localizedDescription)
                    } else {
                        let empty = RateLimitSnapshot(planType: nil, primary: nil, secondary: nil, rateLimitReachedType: nil)
                        result = RateLimitData(
                            snapshot: empty,
                            additionalLimits: [:],
                            source: .cache,
                            fetchedAt: Date(),
                            errorMessage: surfacedError.localizedDescription
                        )
                    }
                    lastErrorMessage = surfacedError.localizedDescription
                    emptyState = EmptyStateClassifier.classify(data: result, lastError: surfacedError)
                }
            }

            await MainActor.run {
                self.lastErrorMessage = lastErrorMessage
                self.emptyState = emptyState
                self.data = result
                if result.source != .cache {
                    Self.save(result, to: self.userDefaults)
                }
                self.isRefreshing = false
            }
        }
    }

    private static func loadCachedData(from userDefaults: UserDefaults) -> RateLimitData? {
        guard let data = userDefaults.data(forKey: Keys.cachedData) else {
            return nil
        }
        return try? JSONDecoder().decode(RateLimitData.self, from: data)
    }

    private static func save(_ value: RateLimitData, to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        userDefaults.set(data, forKey: Keys.cachedData)
    }
}
