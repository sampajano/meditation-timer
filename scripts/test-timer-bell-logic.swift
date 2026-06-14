import Foundation

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    if actual != expected {
        fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }
}

private func expectApproximatelyEqual(_ actual: TimeInterval, _ expected: TimeInterval, _ message: String) {
    if abs(actual - expected) > 0.0001 {
        fputs("FAIL: \(message). Expected \(expected), got \(actual)\n", stderr)
        exit(1)
    }
}

@main
private enum TimerBellLogicTests {
    static func main() {
        expectEqual(TimerBellLogic.formatBellCountdownText(60), "1m", "60 seconds rounds to one minute")
        expectEqual(TimerBellLogic.formatBellCountdownText(31), "1m", "more than 30 seconds rounds to one minute")
        expectEqual(TimerBellLogic.formatBellCountdownText(30), "30s", "30 seconds switches to seconds")
        expectEqual(TimerBellLogic.formatBellCountdownText(29.4), "30s", "less than 30 seconds stays unified with visible countdown seconds")
        expectEqual(TimerBellLogic.formatBellCountdownText(29.0), "29s", "whole-second boundaries display the current second")
        expectEqual(TimerBellLogic.formatBellCountdownText(0.4), "1s", "sub-second remaining time still shows one second")
        expectEqual(TimerBellLogic.formatBellCadenceText(90), "1:30", "bell cadence uses clock-style text for non-minute intervals")
        expectEqual(TimerBellLogic.formatBellCadenceText(120), "2m", "bell cadence keeps pure minute intervals compact")
        expectEqual(TimerBellLogic.formatBellCadenceText(45), "0:45", "bell cadence uses clock-style text for sub-minute intervals")
        expectEqual(TimerBellLogic.formatCountdownClockText(29.4), "0:30", "main countdown uses the same visible-second boundary as bell countdown")
        expectEqual(TimerBellLogic.formatCountdownClockText(29.0), "0:29", "main countdown changes on whole-second boundaries")
        expectEqual(TimerBellLogic.formatElapsedClockText(29.4), "0:29", "elapsed overtime display does not count ahead")
        expectApproximatelyEqual(TimerBellLogic.runningSessionTransition(totalDuration: 120, elapsed: 119.4).remaining, 0.6, "running transition keeps near-end sessions in countdown")
        expectEqual(TimerBellLogic.runningSessionTransition(totalDuration: 120, elapsed: 119.4).overtimeElapsed, nil, "running transition does not enter overtime before the session ends")
        expectApproximatelyEqual(TimerBellLogic.runningSessionTransition(totalDuration: 120, elapsed: 120).remaining, 0, "running transition has no remaining time at the end boundary")
        expectApproximatelyEqual(TimerBellLogic.runningSessionTransition(totalDuration: 120, elapsed: 120).overtimeElapsed ?? -1, 0, "running transition enters overtime exactly at the end boundary")
        expectApproximatelyEqual(TimerBellLogic.runningSessionTransition(totalDuration: 120, elapsed: 126.5).overtimeElapsed ?? -1, 6.5, "running transition preserves delayed overtime elapsed time")

        let start = Date(timeIntervalSince1970: 100)
        expectEqual(MeditationLiveActivityLogic.endDate(startingAt: start, remaining: 90), Date(timeIntervalSince1970: 190), "live activity end date is derived from remaining time")
        expectEqual(MeditationLiveActivityLogic.endDate(startingAt: start, remaining: -10), start, "live activity end date does not move backward for negative remaining time")
        expectEqual(MeditationLiveActivityLogic.endDate(startingAt: Date(timeIntervalSince1970: 100.491), remaining: 89.51), Date(timeIntervalSince1970: 190), "live activity end date ignores sub-second timer jitter")
        expectEqual(MeditationLiveActivityLogic.remainingText(61.2), "1:02", "paused live activity remaining text uses visible countdown rounding")
        expectEqual(MeditationLiveActivityLogic.nextBellText(61.2), "Next bell in 2m", "live activity next bell text matches the main app minute style")
        expectEqual(MeditationLiveActivityLogic.nextBellText(29.4), "Next bell in 30s", "live activity next bell text switches to seconds near the bell")
        expectEqual(MeditationLiveActivityLogic.nextBellText(nil), nil, "live activity hides next bell text when there are no intermediate bells")
        expectEqual(MeditationLiveActivityLogic.nextBellText(-1), nil, "live activity hides next bell text when the next bell has passed")
        expectEqual(MeditationLiveActivityLogic.nextBellDate(startingAt: start, remaining: 90), Date(timeIntervalSince1970: 190), "live activity next bell date is derived from remaining time")
        expectEqual(MeditationLiveActivityLogic.nextBellDate(startingAt: Date(timeIntervalSince1970: 100.491), remaining: 29.51), Date(timeIntervalSince1970: 130), "live activity next bell date ignores sub-second timer jitter")
        expectEqual(MeditationLiveActivityLogic.nextBellDate(startingAt: start, remaining: nil), nil, "live activity next bell date is absent without an interval bell")
        expectEqual(MeditationLiveActivityLogic.overtimeStartDate(now: start, elapsed: 12), Date(timeIntervalSince1970: 88), "live activity overtime range starts from elapsed extra time")
        expectEqual(MeditationLiveActivityLogic.overtimeRangeEnd(startingAt: start), Date(timeIntervalSince1970: 86500), "live activity overtime range has a long stable count-up end")
        expectEqual(MeditationLiveActivityLogic.primaryCountdownText(29 * 60 + 34), "29 min left", "live activity lock screen countdown uses stable minute text instead of a timer interval")
        expectEqual(MeditationLiveActivityLogic.primaryCountdownText(60), "1 min left", "live activity lock screen countdown uses concise minute text")
        expectEqual(MeditationLiveActivityLogic.primaryCountdownText(42.2), "43 sec left", "live activity lock screen countdown uses seconds only near the end")
        expectEqual(MeditationLiveActivityLogic.primaryCountdownText(1), "1 sec left", "live activity lock screen countdown uses concise second text")
        expectEqual(MeditationLiveActivityLogic.compactCountdownText(29 * 60 + 34), "29m", "dynamic island compact countdown uses a short stable label")
        expectEqual(MeditationLiveActivityLogic.primaryOvertimeText(3 * 60 + 12), "+3 min", "live activity lock screen overtime uses stable elapsed minute text")
        expectEqual(MeditationLiveActivityLogic.primaryOvertimeText(60), "+1 min", "live activity lock screen overtime uses concise minute text")
        expectEqual(MeditationLiveActivityLogic.primaryOvertimeText(12.4), "+12 sec", "live activity lock screen overtime uses seconds during the first minute")
        expectEqual(MeditationLiveActivityLogic.primaryOvertimeText(1), "+1 sec", "live activity lock screen overtime uses concise second text")
        expectEqual(MeditationLiveActivityLogic.compactOvertimeText(3 * 60 + 12), "+3m", "dynamic island compact overtime uses a short stable label")
        expectEqual(MeditationLiveActivityLogic.shouldSyncOnForeground(isSessionActive: true, countdownActive: false), true, "foreground sync recreates a live activity for an active meditation session")
        expectEqual(MeditationLiveActivityLogic.shouldSyncOnForeground(isSessionActive: true, countdownActive: true), false, "foreground sync waits until preparation countdown has started the meditation")
        expectEqual(MeditationLiveActivityLogic.shouldSyncOnForeground(isSessionActive: false, countdownActive: false), false, "foreground sync does not create a live activity when no session is active")
        expectEqual(MeditationLiveActivityTimerMode.countdown.rawValue, "countdown", "live activity timer mode uses stable codable values")

        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 0, spacing: 30), 30, "first overtime bell is thirty seconds after the session ends")
        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 0.2, spacing: 30), 29.8, "overtime bell countdown starts from the next spacing boundary")
        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 30, spacing: 30), 30, "after a bell boundary, the next overtime bell is one full interval later")
        expectApproximatelyEqual(TimerBellLogic.overtimeBellSpacing(hasIntermediateBells: true, intermediateSpacing: 90, fallbackSpacing: 600), 90, "overtime keeps the configured interval when intermediate bells exist")
        expectApproximatelyEqual(TimerBellLogic.overtimeBellSpacing(hasIntermediateBells: false, intermediateSpacing: 1200, fallbackSpacing: 600), 600, "overtime falls back to ten-minute bells when no intermediate bells exist")

        expectEqual(TimerBellLogic.elapsedSecondForBellProcessing(29.99), 30, "tiny timer jitter before a whole second should not delay the overtime bell")
        expectEqual(TimerBellLogic.elapsedSecondForBellProcessing(29.90), 29, "meaningfully early ticks should not fire the overtime bell early")

        print("TimerBellLogic tests passed")
    }
}
