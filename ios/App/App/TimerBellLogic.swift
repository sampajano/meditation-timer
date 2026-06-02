import Foundation

enum TimerBellLogic {
    struct RunningSessionTransition {
        let remaining: TimeInterval
        let overtimeElapsed: TimeInterval?
    }

    static func formatBellCountdownText(_ seconds: TimeInterval) -> String {
        let remaining = max(0, seconds)
        if remaining <= 30 {
            return "\(max(1, Int(ceil(remaining))))s"
        }

        return "\(Int(ceil(remaining / 60)))m"
    }

    static func formatBellCadenceText(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(1, Int(round(max(0, seconds))))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        if remainingSeconds == 0 {
            return "\(minutes)m"
        }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    static func formatCountdownClockText(_ seconds: TimeInterval) -> String {
        let totalSeconds = seconds <= 0 ? 0 : Int(ceil(seconds))
        return formatClockText(totalSeconds)
    }

    static func formatElapsedClockText(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(floor(max(0, seconds)))
        return formatClockText(totalSeconds)
    }

    static func runningSessionTransition(totalDuration: TimeInterval, elapsed: TimeInterval) -> RunningSessionTransition {
        let duration = max(0, totalDuration)
        let elapsedTime = max(0, elapsed)

        guard elapsedTime < duration else {
            return RunningSessionTransition(remaining: 0, overtimeElapsed: elapsedTime - duration)
        }

        return RunningSessionTransition(remaining: duration - elapsedTime, overtimeElapsed: nil)
    }

    static func nextOvertimeBellRemaining(overtimeElapsed: TimeInterval, spacing: Int) -> TimeInterval {
        let bellSpacing = max(1, spacing)
        let elapsed = max(0, overtimeElapsed)
        let nextBell = (floor(elapsed / Double(bellSpacing)) + 1) * Double(bellSpacing)
        return max(0, nextBell - elapsed)
    }

    static func elapsedSecondForBellProcessing(_ elapsed: TimeInterval) -> Int {
        Int(floor(max(0, elapsed) + 0.02))
    }

    private static func formatClockText(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
