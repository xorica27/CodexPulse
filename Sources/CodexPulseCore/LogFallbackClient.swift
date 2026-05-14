import Foundation

public final class LogFallbackRateLimitClient: @unchecked Sendable {
    private let logsPath: String

    public init(logsPath: String = "\(NSHomeDirectory())/.codex/logs_2.sqlite") {
        self.logsPath = logsPath
    }

    public func fetch() throws -> RateLimitData {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            logsPath,
            """
            SELECT feedback_log_body
            FROM logs
            WHERE (
              target='codex_api::endpoint::responses_websocket'
              AND feedback_log_body LIKE '%websocket event: {"type":"codex.rate_limits"%'
            )
            OR (
              target='log'
              AND feedback_log_body LIKE 'Received message {"type":"codex.rate_limits"%'
            )
            ORDER BY ts DESC, ts_nanos DESC, id DESC
            LIMIT 1;
            """
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw RateLimitClientError.malformedResponse
        }
        return try parseLogBody(text)
    }

    private func parseLogBody(_ body: String) throws -> RateLimitData {
        let markers = [
            "websocket event: ",
            "Received message "
        ]

        for marker in markers {
            guard let markerRange = body.range(of: marker) else {
                continue
            }
            let jsonText = String(body[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["type"] as? String == "codex.rate_limits" else {
                continue
            }

            let limits = object["rate_limits"] as? [String: Any] ?? [:]
            let additionalObject = object["additional_rate_limits"] as? [String: Any] ?? [:]
            var additional: [String: RateLimitSnapshot] = [:]
            for (name, value) in additionalObject {
                if let bucket = value as? [String: Any] {
                    additional[name] = parseLegacySnapshot(bucket, planType: object["plan_type"] as? String)
                }
            }

            return RateLimitData(
                snapshot: parseLegacySnapshot(limits, planType: object["plan_type"] as? String),
                additionalLimits: additional,
                source: .log,
                fetchedAt: Date()
            )
        }

        throw RateLimitClientError.malformedResponse
    }

    private func parseLegacySnapshot(_ bucket: [String: Any], planType: String?) -> RateLimitSnapshot {
        RateLimitSnapshot(
            planType: planType,
            primary: parseLegacyWindow(bucket["primary"] as? [String: Any]),
            secondary: parseLegacyWindow(bucket["secondary"] as? [String: Any]),
            rateLimitReachedType: (bucket["limit_reached"] as? Bool) == true ? "rate_limit_reached" : nil
        )
    }

    private func parseLegacyWindow(_ value: [String: Any]?) -> RateLimitWindow? {
        guard let value, let usedPercent = value["used_percent"] as? Int else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            windowDurationMins: value["window_minutes"] as? Int,
            resetsAt: value["reset_at"] as? Int
        )
    }
}
