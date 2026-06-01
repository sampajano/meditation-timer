import Foundation

enum MeditationLiveActivityLogic {
    static func endDate(startingAt start: Date = Date(), remaining: TimeInterval) -> Date {
        start.addingTimeInterval(max(0, remaining))
    }

    static func remainingText(_ seconds: TimeInterval) -> String {
        TimerBellLogic.formatCountdownClockText(seconds)
    }

    static func nextBellText(_ seconds: TimeInterval?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        return "Next bell in \(TimerBellLogic.formatBellCountdownText(seconds))"
    }

    static func nextBellDate(startingAt start: Date = Date(), remaining: TimeInterval?) -> Date? {
        guard let remaining, remaining > 0 else { return nil }
        return start.addingTimeInterval(remaining)
    }

    static func primaryCountdownText(_ seconds: TimeInterval) -> String {
        let remaining = max(0, seconds)
        if remaining < 60 {
            return "\(Int(ceil(remaining))) sec left"
        }

        return "\(max(1, Int(floor(remaining / 60)))) min left"
    }

    static func compactCountdownText(_ seconds: TimeInterval) -> String {
        let remaining = max(0, seconds)
        if remaining < 60 {
            return "\(Int(ceil(remaining)))s"
        }

        return "\(max(1, Int(floor(remaining / 60))))m"
    }

    static func primaryOvertimeText(_ seconds: TimeInterval) -> String {
        let elapsed = max(0, seconds)
        if elapsed < 60 {
            return "+\(Int(floor(elapsed))) sec"
        }

        return "+\(Int(floor(elapsed / 60))) min"
    }

    static func compactOvertimeText(_ seconds: TimeInterval) -> String {
        let elapsed = max(0, seconds)
        if elapsed < 60 {
            return "+\(Int(floor(elapsed)))s"
        }

        return "+\(Int(floor(elapsed / 60)))m"
    }

    static func overtimeStartDate(now: Date = Date(), elapsed: TimeInterval) -> Date {
        now.addingTimeInterval(-max(0, elapsed))
    }

    static func overtimeRangeEnd(startingAt start: Date) -> Date {
        start.addingTimeInterval(24 * 60 * 60)
    }

    static func shouldSyncOnForeground(isSessionActive: Bool, countdownActive: Bool) -> Bool {
        isSessionActive && !countdownActive
    }
}
