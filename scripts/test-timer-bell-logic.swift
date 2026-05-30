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
        expectEqual(TimerBellLogic.formatCountdownClockText(29.4), "0:30", "main countdown uses the same visible-second boundary as bell countdown")
        expectEqual(TimerBellLogic.formatCountdownClockText(29.0), "0:29", "main countdown changes on whole-second boundaries")
        expectEqual(TimerBellLogic.formatElapsedClockText(29.4), "0:29", "elapsed overtime display does not count ahead")

        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 0, spacing: 30), 30, "first overtime bell is thirty seconds after the session ends")
        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 0.2, spacing: 30), 29.8, "overtime bell countdown starts from the next spacing boundary")
        expectApproximatelyEqual(TimerBellLogic.nextOvertimeBellRemaining(overtimeElapsed: 30, spacing: 30), 30, "after a bell boundary, the next overtime bell is one full interval later")

        expectEqual(TimerBellLogic.elapsedSecondForBellProcessing(29.99), 30, "tiny timer jitter before a whole second should not delay the overtime bell")
        expectEqual(TimerBellLogic.elapsedSecondForBellProcessing(29.90), 29, "meaningfully early ticks should not fire the overtime bell early")

        print("TimerBellLogic tests passed")
    }
}
