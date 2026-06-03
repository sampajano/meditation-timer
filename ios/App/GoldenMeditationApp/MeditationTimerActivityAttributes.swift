import Foundation

enum MeditationLiveActivityTimerMode: String, Codable, Hashable {
    case countdown
    case elapsed
    case paused
}

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct MeditationTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: String
        var endsAt: Date
        var timerMode: MeditationLiveActivityTimerMode
        var startedAt: Date?
        var isPaused: Bool
        var pausedRemainingText: String?
        var primaryTimeText: String
        var compactTimeText: String
        var nextBellText: String?
        var nextBellAt: Date?
    }

    var title: String
    var totalDuration: TimeInterval
}
#endif
