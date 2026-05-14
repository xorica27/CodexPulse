import Foundation
import Testing
@testable import CodexPulseCore

struct CodexPulseTests {
    @Test
    func testRemainingPercentClampsFromUsedPercent() {
        #expect(RateLimitWindow(usedPercent: 9, windowDurationMins: 300, resetsAt: nil).remainingPercent == 91)
        #expect(RateLimitWindow(usedPercent: -10, windowDurationMins: 300, resetsAt: nil).remainingPercent == 100)
        #expect(RateLimitWindow(usedPercent: 120, windowDurationMins: 300, resetsAt: nil).remainingPercent == 0)
    }

    @Test
    func testDisplayModes() {
        let data = sampleData()

        #expect(DisplayFormatter.statusTitle(for: data, mode: .both) == "5h 91% W 90%")
        #expect(DisplayFormatter.statusTitle(for: data, mode: .fiveHour) == "5h 91%")
        #expect(DisplayFormatter.statusTitle(for: data, mode: .weekly) == "W 90%")
    }

    @Test
    func testPercentDisplayModes() {
        let data = sampleData()

        #expect(DisplayFormatter.statusTitle(for: data, mode: .both, percentDisplay: .remaining) == "5h 91% W 90%")
        #expect(DisplayFormatter.statusTitle(for: data, mode: .both, percentDisplay: .used) == "5h 9% used W 10% used")
        #expect(DisplayFormatter.statusTitle(for: data, mode: .both, percentDisplay: .both) == "5h 91% rem/9% used W 90% rem/10% used")
    }

    @Test
    func testStatusMarkersUseExpectedPrecedence() {
        let now = Date(timeIntervalSince1970: 2_000)
        let staleData = sampleData(source: .cache, fetchedAt: Date(timeIntervalSince1970: 1_000))
        let lowData = sampleData(
            primary: RateLimitWindow(usedPercent: 95, windowDurationMins: 300, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 10, windowDurationMins: 10080, resetsAt: nil)
        )
        let limitedData = sampleData(rateLimitReachedType: "primary")

        #expect(DisplayFormatter.statusTitle(for: lowData, mode: .both, percentDisplay: .remaining, staleAfterMinutes: 30, now: now) == "low 5h 5% W 90%")
        #expect(DisplayFormatter.statusTitle(for: staleData, mode: .both, percentDisplay: .remaining, staleAfterMinutes: 30, now: now) == "stale 5h 91% W 90%")
        #expect(DisplayFormatter.statusTitle(for: limitedData, mode: .both, percentDisplay: .remaining, staleAfterMinutes: 30, now: now) == "limited")
    }

    @Test
    func testSettingsPersistenceDefaultsAndRoundTrip() throws {
        let suiteName = "CodexPulseTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(CodexPulseSettings.load(from: defaults) == .defaults)

        let settings = CodexPulseSettings(
            displayMode: .weekly,
            percentDisplay: .both,
            refreshInterval: .fiveMinutes,
            notificationsEnabled: true,
            notifyFiveHourThresholds: [10, 5],
            notifyWeeklyThresholds: [20],
            staleAfterMinutes: 45
        )
        settings.save(to: defaults)

        #expect(CodexPulseSettings.load(from: defaults) == settings)
    }

    @Test
    func testSettingsMigrateLegacyDisplayMode() throws {
        let suiteName = "CodexPulseTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(DisplayMode.weekly.rawValue, forKey: "displayMode")

        #expect(CodexPulseSettings.load(from: defaults).displayMode == .weekly)
    }

    @Test
    func testNotificationDecisionsCrossThresholdOncePerResetWindow() {
        let settings = CodexPulseSettings.defaults.withNotificationsEnabled()
        let data = sampleData(
            primary: RateLimitWindow(usedPercent: 91, windowDurationMins: 300, resetsAt: 3_000),
            secondary: RateLimitWindow(usedPercent: 10, windowDurationMins: 10080, resetsAt: 4_000)
        )
        var sent: Set<String> = []

        let first = NotificationPlanner.decisions(for: data, settings: settings, sentKeys: sent, now: Date(timeIntervalSince1970: 2_000))
        #expect(first.map(\.kind) == [
            .threshold(window: .fiveHour, threshold: 20),
            .threshold(window: .fiveHour, threshold: 10)
        ])
        sent.formUnion(first.map(\.deduplicationKey))

        let repeated = NotificationPlanner.decisions(for: data, settings: settings, sentKeys: sent, now: Date(timeIntervalSince1970: 2_100))
        #expect(repeated.isEmpty)
    }

    @Test
    func testNotificationThresholdsNormalizeDuplicatesAndInvalidValues() {
        let settings = CodexPulseSettings(
            displayMode: .both,
            percentDisplay: .remaining,
            refreshInterval: .oneMinute,
            notificationsEnabled: true,
            notifyFiveHourThresholds: [10, 20, 20, 200, 0, 5],
            notifyWeeklyThresholds: [],
            staleAfterMinutes: 30
        )
        let data = sampleData(
            primary: RateLimitWindow(usedPercent: 91, windowDurationMins: 300, resetsAt: 3_000),
            secondary: RateLimitWindow(usedPercent: 10, windowDurationMins: 10080, resetsAt: 4_000)
        )

        let decisions = NotificationPlanner.decisions(for: data, settings: settings, sentKeys: [], now: Date(timeIntervalSince1970: 2_000))

        #expect(decisions.map(\.kind) == [
            .threshold(window: .fiveHour, threshold: 20),
            .threshold(window: .fiveHour, threshold: 10)
        ])
    }

    @Test
    func testNotificationDecisionsIncludeStaleDataWhenEnabled() {
        let settings = CodexPulseSettings.defaults.withNotificationsEnabled()
        let data = sampleData(source: .cache, fetchedAt: Date(timeIntervalSince1970: 0))

        let decisions = NotificationPlanner.decisions(for: data, settings: settings, sentKeys: [], now: Date(timeIntervalSince1970: 1_900))

        #expect(decisions.map(\.kind) == [.staleData])
    }

    @Test
    func testEmptyStateClassification() {
        #expect(EmptyStateClassifier.classify(data: nil, lastError: RateLimitClientError.codexBinaryMissing("/Applications/Codex.app/Contents/Resources/codex")) == .codexNotInstalled)

        let empty = RateLimitData(
            snapshot: RateLimitSnapshot(planType: nil, primary: nil, secondary: nil, rateLimitReachedType: nil),
            additionalLimits: [:],
            source: .cache,
            fetchedAt: Date(),
            errorMessage: RateLimitClientError.malformedResponse.localizedDescription
        )
        #expect(EmptyStateClassifier.classify(data: empty, lastError: RateLimitClientError.malformedResponse) == .noRateLimitData)

        let cached = sampleData(source: .cache)
        #expect(EmptyStateClassifier.classify(data: cached, lastError: RateLimitClientError.responseTimeout) == .cachedOnly)
    }

    @Test
    func testResetTextUsesTimeForSameDayAndDateForFutureDay() {
        let now = Date(timeIntervalSince1970: 1_778_719_500)
        let sameDay = 1_778_736_433
        let futureDay = 1_779_152_172

        #expect(DisplayFormatter.resetText(sameDay, now: now) == "13:27")
        #expect(DisplayFormatter.resetText(futureDay, now: now) == "19 May")
    }

    @Test
    func testParsesAppServerPayload() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {"usedPercent": 9, "windowDurationMins": 300, "resetsAt": 1778736433},
            "secondary": {"usedPercent": 10, "windowDurationMins": 10080, "resetsAt": 1779152172},
            "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
            "planType": "prolite",
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "primary": {"usedPercent": 9, "windowDurationMins": 300, "resetsAt": 1778736433},
              "secondary": {"usedPercent": 10, "windowDurationMins": 10080, "resetsAt": 1779152172},
              "planType": "prolite",
              "rateLimitReachedType": null
            },
            "codex_bengalfox": {
              "limitId": "codex_bengalfox",
              "limitName": "GPT-5.3-Codex-Spark",
              "primary": {"usedPercent": 0, "windowDurationMins": 300, "resetsAt": 1778738702},
              "secondary": {"usedPercent": 0, "windowDurationMins": 10080, "resetsAt": 1779325502},
              "planType": "prolite",
              "rateLimitReachedType": null
            }
          }
        }
        """
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let data = try RateLimitPayloadParser.parse(result: object, source: .appServer)

        #expect(data.snapshot.planType == "prolite")
        #expect(data.snapshot.primary?.remainingPercent == 91)
        #expect(data.snapshot.secondary?.remainingPercent == 90)
        #expect(data.additionalLimits["GPT-5.3-Codex-Spark"]?.primary?.remainingPercent == 100)
    }

    private func sampleData(
        primary: RateLimitWindow = RateLimitWindow(usedPercent: 9, windowDurationMins: 300, resetsAt: nil),
        secondary: RateLimitWindow = RateLimitWindow(usedPercent: 10, windowDurationMins: 10080, resetsAt: nil),
        source: SnapshotSource = .appServer,
        fetchedAt: Date = Date(),
        rateLimitReachedType: String? = nil
    ) -> RateLimitData {
        RateLimitData(
            snapshot: RateLimitSnapshot(
                planType: "prolite",
                primary: primary,
                secondary: secondary,
                rateLimitReachedType: rateLimitReachedType
            ),
            additionalLimits: [:],
            source: source,
            fetchedAt: fetchedAt
        )
    }

}

private extension CodexPulseSettings {
    func withNotificationsEnabled() -> CodexPulseSettings {
        CodexPulseSettings(
            displayMode: displayMode,
            percentDisplay: percentDisplay,
            refreshInterval: refreshInterval,
            notificationsEnabled: true,
            notifyFiveHourThresholds: notifyFiveHourThresholds,
            notifyWeeklyThresholds: notifyWeeklyThresholds,
            staleAfterMinutes: staleAfterMinutes
        )
    }
}
