import CodexPulseCore
import Foundation

@MainActor
final class RateLimitStore {
    private enum Keys {
        static let cachedData = "cachedRateLimitData"
    }

    private let appServerClient = AppServerRateLimitClient()
    private let logFallbackClient = LogFallbackRateLimitClient()
    private let userDefaults: UserDefaults
    private var isRefreshing = false

    var data: RateLimitData? {
        didSet {
            onChange?()
        }
    }

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
            do {
                result = try appServerClient.fetch()
            } catch {
                do {
                    result = try logFallbackClient.fetch()
                } catch {
                    if let cached = cachedData {
                        result = cached.replacingSource(.cache, errorMessage: error.localizedDescription)
                    } else {
                        let empty = RateLimitSnapshot(planType: nil, primary: nil, secondary: nil, rateLimitReachedType: nil)
                        result = RateLimitData(
                            snapshot: empty,
                            additionalLimits: [:],
                            source: .cache,
                            fetchedAt: Date(),
                            errorMessage: error.localizedDescription
                        )
                    }
                }
            }

            await MainActor.run {
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
