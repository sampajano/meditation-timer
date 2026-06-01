import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
@MainActor
final class MeditationLiveActivityController {
    static let shared = MeditationLiveActivityController()

    private var activity: Activity<MeditationTimerActivityAttributes>?
    private var currentState: MeditationTimerActivityAttributes.ContentState?
    private var operationChain: Task<Void, Never>?

    private init() {}

    func start(totalDuration: TimeInterval, remaining: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            await self.endExisting(dismissalPolicy: .immediate)

            let state = self.countdownState(remaining: remaining, nextBellRemaining: nextBellRemaining)
            self.requestNew(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func syncRunning(totalDuration: TimeInterval, remaining: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let state = self.countdownState(remaining: remaining, nextBellRemaining: nextBellRemaining)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func resume(remaining: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let totalDuration = Activity<MeditationTimerActivityAttributes>.activities.first?.attributes.totalDuration ?? remaining
            let state = self.countdownState(remaining: remaining, nextBellRemaining: nextBellRemaining)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func updateRunning(remaining: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            guard let activity = self.activeActivity(), var state = self.currentState, state.timerMode == .countdown else { return }

            state.phase = "Meditating"
            state.isPaused = false
            state.pausedRemainingText = nil
            state.primaryTimeText = MeditationLiveActivityLogic.primaryCountdownText(remaining)
            state.compactTimeText = MeditationLiveActivityLogic.compactCountdownText(remaining)
            state.nextBellText = MeditationLiveActivityLogic.nextBellText(nextBellRemaining)
            state.nextBellAt = MeditationLiveActivityLogic.nextBellDate(remaining: nextBellRemaining)

            await self.updateIfChanged(activity, state: state, staleDate: state.endsAt.addingTimeInterval(60))
        }
    }

    func startOvertime(totalDuration: TimeInterval, overtimeElapsed: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let state = self.overtimeState(overtimeElapsed: overtimeElapsed, nextBellRemaining: nextBellRemaining)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func syncOvertime(totalDuration: TimeInterval, overtimeElapsed: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let state = self.overtimeState(overtimeElapsed: overtimeElapsed, nextBellRemaining: nextBellRemaining)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func updateOvertime(overtimeElapsed: TimeInterval, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            guard let activity = self.activeActivity(), var state = self.currentState, state.timerMode == .elapsed else { return }

            state.phase = "Extra time"
            state.isPaused = false
            state.pausedRemainingText = nil
            state.primaryTimeText = MeditationLiveActivityLogic.primaryOvertimeText(overtimeElapsed)
            state.compactTimeText = MeditationLiveActivityLogic.compactOvertimeText(overtimeElapsed)
            state.nextBellText = MeditationLiveActivityLogic.nextBellText(nextBellRemaining)
            state.nextBellAt = MeditationLiveActivityLogic.nextBellDate(remaining: nextBellRemaining)

            await self.updateIfChanged(activity, state: state, staleDate: nil)
        }
    }

    func pause(remaining: TimeInterval, overtimeElapsed: TimeInterval?, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let totalDuration = Activity<MeditationTimerActivityAttributes>.activities.first?.attributes.totalDuration ?? remaining
            let state = self.pausedState(remaining: remaining, overtimeElapsed: overtimeElapsed, nextBellRemaining: nextBellRemaining)

            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func syncPaused(totalDuration: TimeInterval, remaining: TimeInterval, overtimeElapsed: TimeInterval?, nextBellRemaining: TimeInterval?) {
        enqueue { [self] in
            let state = self.pausedState(remaining: remaining, overtimeElapsed: overtimeElapsed, nextBellRemaining: nextBellRemaining)
            await self.updateOrRequest(totalDuration: totalDuration, state: state, staleDate: nil)
        }
    }

    func end() {
        enqueue { [self] in
            await self.endExisting(dismissalPolicy: .immediate)
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = operationChain
        operationChain = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func countdownState(remaining: TimeInterval, nextBellRemaining: TimeInterval?) -> MeditationTimerActivityAttributes.ContentState {
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
            nextBellText: MeditationLiveActivityLogic.nextBellText(nextBellRemaining),
            nextBellAt: MeditationLiveActivityLogic.nextBellDate(remaining: nextBellRemaining)
        )
    }

    private func overtimeState(overtimeElapsed: TimeInterval, nextBellRemaining: TimeInterval?) -> MeditationTimerActivityAttributes.ContentState {
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
            nextBellText: MeditationLiveActivityLogic.nextBellText(nextBellRemaining),
            nextBellAt: MeditationLiveActivityLogic.nextBellDate(remaining: nextBellRemaining)
        )
    }

    private func pausedState(remaining: TimeInterval, overtimeElapsed: TimeInterval?, nextBellRemaining: TimeInterval?) -> MeditationTimerActivityAttributes.ContentState {
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
            nextBellText: MeditationLiveActivityLogic.nextBellText(nextBellRemaining),
            nextBellAt: nil
        )
    }

    private func activeActivity() -> Activity<MeditationTimerActivityAttributes>? {
        let activeActivities = Activity<MeditationTimerActivityAttributes>.activities

        if let activity, activeActivities.contains(where: { $0.id == activity.id }) {
            return activity
        }

        if let firstActivity = activeActivities.first {
            activity = firstActivity
            return firstActivity
        }

        activity = nil
        currentState = nil
        return nil
    }

    private func updateOrRequest(
        totalDuration: TimeInterval,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        if let activity = self.activeActivity() {
            await self.updateIfChanged(activity, state: state, staleDate: staleDate)
            return
        }

        self.requestNew(totalDuration: totalDuration, state: state, staleDate: staleDate)
    }

    private func requestNew(
        totalDuration: TimeInterval,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MeditationTimerActivityAttributes(title: "Golden Meditation", totalDuration: totalDuration)

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
        } catch {
            print("Failed to start meditation Live Activity: \(error)")
        }
    }

    private func update(
        _ activity: Activity<MeditationTimerActivityAttributes>,
        state: MeditationTimerActivityAttributes.ContentState,
        staleDate: Date?
    ) async {
        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: staleDate))
        } else {
            await activity.update(using: state)
        }
        currentState = state
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
        guard state != currentState else { return }
        await update(activity, state: state, staleDate: staleDate)
    }
}
#endif
