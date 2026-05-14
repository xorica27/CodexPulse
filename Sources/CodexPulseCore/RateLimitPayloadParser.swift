import Foundation

public enum RateLimitPayloadParser {
    public static func parse(result: [String: Any], source: SnapshotSource, fetchedAt: Date = Date()) throws -> RateLimitData {
        let buckets = result["rateLimitsByLimitId"] as? [String: Any]
        let primaryBucket = (buckets?["codex"] as? [String: Any]) ?? (result["rateLimits"] as? [String: Any])
        guard let primaryBucket else {
            throw RateLimitClientError.malformedResponse
        }

        var additional: [String: RateLimitSnapshot] = [:]
        for (limitID, value) in buckets ?? [:] {
            if limitID == "codex" {
                continue
            }
            guard let bucket = value as? [String: Any] else {
                continue
            }
            let name = bucket["limitName"] as? String ?? limitID
            additional[name] = parseSnapshot(bucket)
        }

        return RateLimitData(
            snapshot: parseSnapshot(primaryBucket),
            additionalLimits: additional,
            source: source,
            fetchedAt: fetchedAt
        )
    }

    private static func parseSnapshot(_ bucket: [String: Any]) -> RateLimitSnapshot {
        RateLimitSnapshot(
            planType: bucket["planType"] as? String,
            primary: parseWindow(bucket["primary"] as? [String: Any]),
            secondary: parseWindow(bucket["secondary"] as? [String: Any]),
            rateLimitReachedType: bucket["rateLimitReachedType"] as? String
        )
    }

    private static func parseWindow(_ value: [String: Any]?) -> RateLimitWindow? {
        guard let value, let usedPercent = value["usedPercent"] as? Int else {
            return nil
        }
        return RateLimitWindow(
            usedPercent: usedPercent,
            windowDurationMins: value["windowDurationMins"] as? Int,
            resetsAt: value["resetsAt"] as? Int
        )
    }
}
