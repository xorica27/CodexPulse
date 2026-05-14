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

    private func sampleData() -> RateLimitData {
        RateLimitData(
            snapshot: RateLimitSnapshot(
                planType: "prolite",
                primary: RateLimitWindow(usedPercent: 9, windowDurationMins: 300, resetsAt: nil),
                secondary: RateLimitWindow(usedPercent: 10, windowDurationMins: 10080, resetsAt: nil),
                rateLimitReachedType: nil
            ),
            additionalLimits: [:],
            source: .appServer,
            fetchedAt: Date()
        )
    }
}
