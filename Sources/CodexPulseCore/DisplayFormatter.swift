import Foundation

public enum DisplayFormatter {
    public static func statusTitle(for data: RateLimitData?, mode: DisplayMode) -> String {
        guard let data else {
            return "Codex ?"
        }

        if data.snapshot.isLimited {
            return "Codex limited"
        }

        let fiveHour = percentText(data.snapshot.primary)
        let weekly = percentText(data.snapshot.secondary)

        switch mode {
        case .both:
            return "Codex 5h \(fiveHour) W \(weekly)"
        case .fiveHour:
            return "Codex 5h \(fiveHour)"
        case .weekly:
            return "Codex W \(weekly)"
        }
    }

    public static func percentText(_ window: RateLimitWindow?) -> String {
        guard let window else {
            return "?%"
        }
        return "\(window.remainingPercent)%"
    }

    public static func resetText(_ epochSeconds: Int?, now: Date = Date()) -> String {
        guard let epochSeconds else {
            return "unknown"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    public static func detailLine(label: String, window: RateLimitWindow?) -> String {
        guard let window else {
            return "\(label): unavailable"
        }
        let reset = resetText(window.resetsAt)
        return "\(label): \(window.remainingPercent)% remaining, resets \(reset) (\(window.usedPercent)% used)"
    }

    public static func relativeAge(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h ago"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m ago"
        }
        return "\(minutes)m ago"
    }
}
