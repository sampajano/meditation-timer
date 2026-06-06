import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MeditationLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MeditationLiveActivityWidget()
    }
}

struct MeditationLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationTimerActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Self.activityCream)
                .activitySystemActionForegroundColor(Self.dhammaGold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.phase)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.dhammaGold)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(for: context)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Self.islandPrimary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            nextBellText(for: context)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Self.islandSecondary)
                                    .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "bell.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.dhammaGoldSoft)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Self.dhammaGold)
            }
        }
    }

    private static let activityCream = Color(red: 1.0, green: 0.95, blue: 0.82)
    private static let dhammaGold = Color(red: 0.76, green: 0.53, blue: 0.16)
    private static let dhammaGoldSoft = Color(red: 0.93, green: 0.72, blue: 0.25)
    private static let dhammaInk = Color(red: 0.16, green: 0.13, blue: 0.08)
    private static let dhammaSecondaryInk = Color(red: 0.38, green: 0.31, blue: 0.18)
    private static let islandPrimary = Color.white
    private static let islandSecondary = Color(red: 0.95, green: 0.79, blue: 0.42)
    private static let lockScreenTimerColumnWidth: CGFloat = 132

    private func lockScreenView(context: ActivityViewContext<MeditationTimerActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Self.dhammaGoldSoft.opacity(0.28))
                Image(systemName: context.state.isPaused ? "pause.fill" : "bell.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Self.dhammaGold)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text(context.attributes.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Self.dhammaInk)
                    .lineLimit(2)

                Text(context.state.phase)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Self.dhammaSecondaryInk)
            }

            Spacer(minLength: 14)

            VStack(alignment: .trailing, spacing: 5) {
                timerText(for: context)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(Self.dhammaInk)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                nextBellText(for: context)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Self.dhammaSecondaryInk)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: Self.lockScreenTimerColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func timerText(for context: ActivityViewContext<MeditationTimerActivityAttributes>) -> some View {
        switch context.state.timerMode {
        case .countdown:
            if context.state.endsAt.timeIntervalSinceNow > 0 {
                Text(context.state.endsAt, style: .timer)
            } else {
                Text(context.state.primaryTimeText)
            }
        case .elapsed:
            Text(context.state.primaryTimeText)
        case .paused:
            Text(context.state.primaryTimeText)
        }
    }

    @ViewBuilder
    private func nextBellText(for context: ActivityViewContext<MeditationTimerActivityAttributes>) -> some View {
        if let nextBellText = context.state.nextBellText {
            Text(nextBellText)
        } else if let nextBellAt = context.state.nextBellAt {
            Text("Next bell ") + Text(nextBellAt, format: .relative(presentation: .numeric, unitsStyle: .narrow))
        }
    }
}
