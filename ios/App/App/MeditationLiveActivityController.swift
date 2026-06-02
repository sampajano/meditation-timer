import Foundation
import OSLog

#if canImport(ActivityKit)
import ActivityKit
#if canImport(UIKit)
import UIKit
#endif

private let liveActivityControllerLog = Logger(subsystem: "com.lukex.goldenmeditation", category: "LiveActivity")

@available(iOS 16.1, *)
@MainActor
final class MeditationLiveActivityController {
    static let shared = MeditationLiveActivityController()

    private var activity: Activity<MeditationTimerActivityAttributes>?
    private var currentState: MeditationTimerActivityAttributes.ContentState?
    private var operationChain: Task<Void, Never>?
    private var operationRevision = 0

    private init() {}

    func start(totalDuration: TimeInterval, remaining: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller start countdown remaining=\(remaining, privacy: .public) totalDuration=\(totalDuration, privacy: .public)")
            appendLiveActivityDebugLog("Controller start countdown remaining=\(remaining) totalDuration=\(totalDuration)")
            await self.endExisting(dismissalPolicy: .immediate)

            let state = self.countdownState(remaining: remaining, bellStatusText: bellStatusText)
            self.requestNew(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func syncRunning(totalDuration: TimeInterval, remaining: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller sync countdown remaining=\(remaining, privacy: .public) totalDuration=\(totalDuration, privacy: .public)")
            appendLiveActivityDebugLog("Controller sync countdown remaining=\(remaining) totalDuration=\(totalDuration)")
            let state = self.countdownState(remaining: remaining, bellStatusText: bellStatusText)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func resume(remaining: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller resume countdown remaining=\(remaining, privacy: .public)")
            appendLiveActivityDebugLog("Controller resume countdown remaining=\(remaining)")
            let totalDuration = Activity<MeditationTimerActivityAttributes>.activities.first?.attributes.totalDuration ?? remaining
            let state = self.countdownState(remaining: remaining, bellStatusText: bellStatusText)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func updateRunning(remaining: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            guard let activity = self.activeActivity(), var state = self.currentState, state.timerMode == .countdown else {
                liveActivityControllerLog.info("Controller update running skipped active=\(self.activeActivity() != nil, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
                appendLiveActivityDebugLog("Controller update running skipped active=\(self.activeActivity() != nil) current=\(self.stateSummary(self.currentState))")
                return
            }
            liveActivityControllerLog.info("Controller update running activity=\(activity.id, privacy: .public) remaining=\(remaining, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
            appendLiveActivityDebugLog("Controller update running activity=\(activity.id) remaining=\(remaining) current=\(self.stateSummary(self.currentState))")

            state.phase = "Meditating"
            state.isPaused = false
            state.pausedRemainingText = nil
            state.nextBellText = bellStatusText
            state.nextBellAt = nil

            await self.updateIfChanged(activity, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func startOvertime(totalDuration: TimeInterval, overtimeElapsed: TimeInterval, bellStatusText: String?) {
        enqueueUrgent { [self] in
            liveActivityControllerLog.info("Controller start overtime elapsed=\(overtimeElapsed, privacy: .public) totalDuration=\(totalDuration, privacy: .public) activeCount=\(Activity<MeditationTimerActivityAttributes>.activities.count, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
            appendLiveActivityDebugLog("Controller start overtime elapsed=\(overtimeElapsed) totalDuration=\(totalDuration) activeCount=\(Activity<MeditationTimerActivityAttributes>.activities.count) current=\(self.stateSummary(self.currentState))")
            let state = self.overtimeState(overtimeElapsed: overtimeElapsed, bellStatusText: bellStatusText)
            await self.withBackgroundLiveActivityUpdate(named: "Meditation overtime") {
                await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
            }
        }
    }

    func syncOvertime(totalDuration: TimeInterval, overtimeElapsed: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller sync overtime elapsed=\(overtimeElapsed, privacy: .public) totalDuration=\(totalDuration, privacy: .public)")
            appendLiveActivityDebugLog("Controller sync overtime elapsed=\(overtimeElapsed) totalDuration=\(totalDuration)")
            let state = self.overtimeState(overtimeElapsed: overtimeElapsed, bellStatusText: bellStatusText)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func updateOvertime(overtimeElapsed: TimeInterval, bellStatusText: String?) {
        enqueue { [self] in
            guard let activity = self.activeActivity(), var state = self.currentState, state.timerMode == .elapsed else {
                liveActivityControllerLog.info("Controller update overtime skipped active=\(self.activeActivity() != nil, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
                appendLiveActivityDebugLog("Controller update overtime skipped active=\(self.activeActivity() != nil) current=\(self.stateSummary(self.currentState))")
                return
            }
            liveActivityControllerLog.info("Controller update overtime activity=\(activity.id, privacy: .public) elapsed=\(overtimeElapsed, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
            appendLiveActivityDebugLog("Controller update overtime activity=\(activity.id) elapsed=\(overtimeElapsed) current=\(self.stateSummary(self.currentState))")

            state.phase = "Extra time"
            state.isPaused = false
            state.pausedRemainingText = nil
            state.nextBellText = bellStatusText
            state.nextBellAt = nil

            await self.updateIfChanged(activity, state: state, staleDate: nil)
        }
    }

    func pause(remaining: TimeInterval, overtimeElapsed: TimeInterval?, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller pause remaining=\(remaining, privacy: .public) overtimeElapsed=\(overtimeElapsed ?? -1, privacy: .public)")
            appendLiveActivityDebugLog("Controller pause remaining=\(remaining) overtimeElapsed=\(overtimeElapsed ?? -1)")
            let totalDuration = Activity<MeditationTimerActivityAttributes>.activities.first?.attributes.totalDuration ?? remaining
            let state = self.pausedState(remaining: remaining, overtimeElapsed: overtimeElapsed, bellStatusText: bellStatusText)

            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func syncPaused(totalDuration: TimeInterval, remaining: TimeInterval, overtimeElapsed: TimeInterval?, bellStatusText: String?) {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller sync paused remaining=\(remaining, privacy: .public) overtimeElapsed=\(overtimeElapsed ?? -1, privacy: .public) totalDuration=\(totalDuration, privacy: .public)")
            appendLiveActivityDebugLog("Controller sync paused remaining=\(remaining) overtimeElapsed=\(overtimeElapsed ?? -1) totalDuration=\(totalDuration)")
            let state = self.pausedState(remaining: remaining, overtimeElapsed: overtimeElapsed, bellStatusText: bellStatusText)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func end() {
        enqueue { [self] in
            liveActivityControllerLog.info("Controller end requested activeCount=\(Activity<MeditationTimerActivityAttributes>.activities.count, privacy: .public)")
            appendLiveActivityDebugLog("Controller end requested activeCount=\(Activity<MeditationTimerActivityAttributes>.activities.count)")
            await self.endExisting(dismissalPolicy: .immediate)
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        operationRevision += 1
        let revision = operationRevision
        let previous = operationChain
        operationChain = Task { @MainActor in
            await previous?.value
            guard revision == self.operationRevision else {
                liveActivityControllerLog.info("Controller skipping stale queued operation revision=\(revision, privacy: .public) currentRevision=\(self.operationRevision, privacy: .public)")
                appendLiveActivityDebugLog("Controller skipping stale queued operation revision=\(revision) currentRevision=\(self.operationRevision)")
                return
            }
            await operation()
        }
    }

    private func enqueueUrgent(_ operation: @escaping @MainActor () async -> Void) {
        operationRevision += 1
        let revision = operationRevision
        liveActivityControllerLog.info("Controller urgent operation revision=\(revision, privacy: .public)")
        appendLiveActivityDebugLog("Controller urgent operation revision=\(revision)")
        operationChain = Task(priority: .userInitiated) { @MainActor in
            guard revision == self.operationRevision else {
                liveActivityControllerLog.info("Controller skipping stale urgent operation revision=\(revision, privacy: .public) currentRevision=\(self.operationRevision, privacy: .public)")
                appendLiveActivityDebugLog("Controller skipping stale urgent operation revision=\(revision) currentRevision=\(self.operationRevision)")
                return
            }
            await operation()
        }
    }

    private func countdownState(remaining: TimeInterval, bellStatusText: String?) -> MeditationTimerActivityAttributes.ContentState {
        let endsAt = MeditationLiveActivityLogic.endDate(remaining: remaining)
        return MeditationTimerActivityAttributes.ContentState(
            phase: "Meditating",
            endsAt: endsAt,
            timerMode: .countdown,
            startedAt: nil,
            isPaused: false,
            pausedRemainingText: nil,
            primaryTimeText: MeditationLiveActivityLogic.primaryCountdownText(remaining),
            compactTimeText: MeditationLiveActivityLogic.compactCountdownText(remaining),
            nextBellText: bellStatusText,
            nextBellAt: nil
        )
    }

    private func overtimeState(overtimeElapsed: TimeInterval, bellStatusText: String?) -> MeditationTimerActivityAttributes.ContentState {
        let startedAt = MeditationLiveActivityLogic.overtimeStartDate(elapsed: overtimeElapsed)
        return MeditationTimerActivityAttributes.ContentState(
            phase: "Extra time",
            endsAt: MeditationLiveActivityLogic.overtimeRangeEnd(startingAt: startedAt),
            timerMode: .elapsed,
            startedAt: startedAt,
            isPaused: false,
            pausedRemainingText: nil,
            primaryTimeText: MeditationLiveActivityLogic.primaryOvertimeText(overtimeElapsed),
            compactTimeText: MeditationLiveActivityLogic.compactOvertimeText(overtimeElapsed),
            nextBellText: bellStatusText,
            nextBellAt: nil
        )
    }

    private func pausedState(remaining: TimeInterval, overtimeElapsed: TimeInterval?, bellStatusText: String?) -> MeditationTimerActivityAttributes.ContentState {
        let primaryTimeText = overtimeElapsed.map(MeditationLiveActivityLogic.primaryOvertimeText) ?? MeditationLiveActivityLogic.primaryCountdownText(remaining)
        let compactTimeText = overtimeElapsed.map(MeditationLiveActivityLogic.compactOvertimeText) ?? MeditationLiveActivityLogic.compactCountdownText(remaining)

        return MeditationTimerActivityAttributes.ContentState(
            phase: "Paused",
            endsAt: Date(),
            timerMode: .paused,
            startedAt: nil,
            isPaused: true,
            pausedRemainingText: primaryTimeText,
            primaryTimeText: primaryTimeText,
            compactTimeText: compactTimeText,
            nextBellText: bellStatusText,
            nextBellAt: nil
        )
    }

    private func activeActivity() -> Activity<MeditationTimerActivityAttributes>? {
        let activeActivities = Activity<MeditationTimerActivityAttributes>.activities
        liveActivityControllerLog.info("Controller activeActivity lookup stored=\(self.activity?.id ?? "nil", privacy: .public) activeCount=\(activeActivities.count, privacy: .public)")
        appendLiveActivityDebugLog("Controller activeActivity lookup stored=\(self.activity?.id ?? "nil") activeCount=\(activeActivities.count)")

        if let activity, activeActivities.contains(where: { $0.id == activity.id }) {
            appendLiveActivityDebugLog("Controller activeActivity returning stored id=\(activity.id)")
            return activity
        }

        if let firstActivity = activeActivities.first {
            activity = firstActivity
            liveActivityControllerLog.info("Controller adopted first active activity id=\(firstActivity.id, privacy: .public)")
            appendLiveActivityDebugLog("Controller adopted first active activity id=\(firstActivity.id)")
            return firstActivity
        }

        activity = nil
        currentState = nil
        appendLiveActivityDebugLog("Controller activeActivity none; cleared currentState")
        return nil
    }

    private func updateOrRequest(
        totalDuration: TimeInterval,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        if let activity = self.activeActivity() {
            liveActivityControllerLog.info("Controller updateOrRequest updating activity=\(activity.id, privacy: .public) state=\(self.stateSummary(state), privacy: .public) stale=\(staleDate?.timeIntervalSince1970 ?? -1, privacy: .public)")
            appendLiveActivityDebugLog("Controller updateOrRequest updating activity=\(activity.id) state=\(self.stateSummary(state)) stale=\(staleDate?.timeIntervalSince1970 ?? -1)")
            await self.updateIfChanged(activity, state: state, staleDate: staleDate)
            return
        }

        liveActivityControllerLog.info("Controller updateOrRequest requesting new state=\(self.stateSummary(state), privacy: .public) stale=\(staleDate?.timeIntervalSince1970 ?? -1, privacy: .public)")
        appendLiveActivityDebugLog("Controller updateOrRequest requesting new state=\(self.stateSummary(state)) stale=\(staleDate?.timeIntervalSince1970 ?? -1)")
        self.requestNew(totalDuration: totalDuration, state: state, staleDate: staleDate)
    }

    private func requestNew(
        totalDuration: TimeInterval,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MeditationTimerActivityAttributes(title: "Golden Meditation", totalDuration: totalDuration)
        liveActivityControllerLog.info("Controller request new state=\(self.stateSummary(state), privacy: .public) stale=\(staleDate?.timeIntervalSince1970 ?? -1, privacy: .public)")
        appendLiveActivityDebugLog("Controller request new state=\(self.stateSummary(state)) stale=\(staleDate?.timeIntervalSince1970 ?? -1)")

        do {
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: staleDate),
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            currentState = state
            liveActivityControllerLog.info("Controller request new succeeded activity=\(self.activity?.id ?? "nil", privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
            appendLiveActivityDebugLog("Controller request new succeeded activity=\(self.activity?.id ?? "nil") current=\(self.stateSummary(self.currentState))")
        } catch {
            liveActivityControllerLog.error("Controller request new failed error=\(String(describing: error), privacy: .public)")
            appendLiveActivityDebugLog("Controller request new failed error=\(String(describing: error))")
        }
    }

    private func update(
        _ activity: Activity<MeditationTimerActivityAttributes>,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        liveActivityControllerLog.info("Controller update begin activity=\(activity.id, privacy: .public) state=\(self.stateSummary(state), privacy: .public) stale=\(staleDate?.timeIntervalSince1970 ?? -1, privacy: .public)")
        appendLiveActivityDebugLog("Controller update begin activity=\(activity.id) state=\(self.stateSummary(state)) stale=\(staleDate?.timeIntervalSince1970 ?? -1)")
        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: staleDate))
        } else {
            await activity.update(using: state)
        }
        currentState = state
        liveActivityControllerLog.info("Controller update finished activity=\(activity.id, privacy: .public) current=\(self.stateSummary(self.currentState), privacy: .public)")
        appendLiveActivityDebugLog("Controller update finished activity=\(activity.id) current=\(self.stateSummary(self.currentState))")
    }

    private func endExisting(dismissalPolicy: ActivityUIDismissalPolicy) async {
        let activeActivities = Activity<MeditationTimerActivityAttributes>.activities
        let finalState = MeditationTimerActivityAttributes.ContentState(
            phase: "Stopped",
            endsAt: Date(),
            timerMode: .paused,
            startedAt: nil,
            isPaused: true,
            pausedRemainingText: "0:00",
            primaryTimeText: "0 sec left",
            compactTimeText: "0s",
            nextBellText: nil,
            nextBellAt: nil
        )

        for activeActivity in activeActivities {
            liveActivityControllerLog.info("Controller ending active activity id=\(activeActivity.id, privacy: .public)")
            appendLiveActivityDebugLog("Controller ending active activity id=\(activeActivity.id)")
            if #available(iOS 16.2, *) {
                await activeActivity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: dismissalPolicy
                )
            } else {
                await activeActivity.end(using: finalState, dismissalPolicy: dismissalPolicy)
            }
        }

        activity = nil
        currentState = nil
    }

    private func updateIfChanged(
        _ activity: Activity<MeditationTimerActivityAttributes>,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        guard state != currentState else {
            liveActivityControllerLog.info("Controller update skipped unchanged activity=\(activity.id, privacy: .public) state=\(self.stateSummary(state), privacy: .public)")
            appendLiveActivityDebugLog("Controller update skipped unchanged activity=\(activity.id) state=\(self.stateSummary(state))")
            return
        }
        await update(activity, state: state, staleDate: staleDate)
    }

    private func withBackgroundLiveActivityUpdate(
        named name: String,
        _ operation: @escaping @MainActor () async -> Void
    ) async {
        #if canImport(UIKit)
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: name)
        liveActivityControllerLog.info("Controller background task begin name=\(name, privacy: .public) task=\(backgroundTask.rawValue, privacy: .public)")
        appendLiveActivityDebugLog("Controller background task begin name=\(name) task=\(backgroundTask.rawValue)")
        defer {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                liveActivityControllerLog.info("Controller background task end name=\(name, privacy: .public) task=\(backgroundTask.rawValue, privacy: .public)")
                appendLiveActivityDebugLog("Controller background task end name=\(name) task=\(backgroundTask.rawValue)")
            }
        }
        #endif

        await operation()
    }

    private func stateSummary(_ state: MeditationTimerActivityAttributes.ContentState?) -> String {
        guard let state else { return "nil" }

        return [
            "phase=\(state.phase)",
            "mode=\(state.timerMode.rawValue)",
            "primary=\(state.primaryTimeText)",
            "compact=\(state.compactTimeText)",
            "startedAt=\(state.startedAt?.timeIntervalSince1970 ?? -1)",
            "endsAt=\(state.endsAt.timeIntervalSince1970)",
            "bell=\(state.nextBellText ?? "nil")"
        ].joined(separator: " ")
    }
}
#endif
