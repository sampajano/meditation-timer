# Live Activity Design

This document describes the Live Activity design for the native iOS meditation timer.

## Goal

Show the meditation timer on the Lock Screen, Dynamic Island, and paired Mac without moving bell playback or timer ownership into a different alarm system. The iPhone app remains the source of truth for timer state and sound.

## Diagrams

### Concept Flow

![Original Live Activity flow](assets/original-live-activity-flow.png)

### Final Design

![Live Activity design](assets/serial-live-activity-design.png)

### Current Notification Timer Design

![Current Live Activity notification timer design](assets/live-activity-notification-current-design.png)

## Architecture

The app has four boundaries:

- `MeditationAppView` owns session state, bell playback, pause/resume, and overtime.
- `MeditationLiveActivityController` is the ActivityKit boundary. It serializes Live Activity operations on `@MainActor`.
- `MeditationTimerActivityAttributes.ContentState` carries typed display state to the widget extension.
- `MeditationLiveActivityWidget` renders the same state across Lock Screen, Dynamic Island, and Mac menu bar surfaces.

The controller intentionally stays display-focused. It does not schedule alarms, own audio, or replace the existing background timer.

## State Model

The Live Activity state uses stable, codable values:

- `timerMode`: `.countdown`, `.elapsed`, or `.paused`
- `endsAt`: session end date, used by SwiftUI system timer text while running so the visible timer can cross `0:00` without an app-driven redraw
- `startedAt`: overtime start date, used by SwiftUI dynamic elapsed text if the widget receives and renders the overtime state
- `primaryTimeText`: readable main text such as `29 min left`, `43 sec left`, or `+3 min`
- `compactTimeText`: short text such as `29m` or `+3m`
- `nextBellText`: optional secondary text such as `Bell every 15m` or `Bell every 1:15`
- `nextBellAt`: optional next bell date retained in the state model, but not used for the current lock-screen cadence line

The widget uses system dynamic date rendering while the timer is running so Lock Screen and Dynamic Island text can keep moving even if the app is suspended. Paused and stopped states use stable text from state because they should not keep counting.

## Display Rules

Lock Screen:

- Warm cream background.
- Dark readable text.
- Main time uses `Text(endsAt, style: .timer)` while running, and `primaryTimeText` while paused.
- The running timer intentionally does not depend on a boundary update to move past `0:00`. The system timer text keeps moving even if ActivityKit accepts an overtime update but the visible notification does not immediately re-render.
- The `+` prefix is opportunistic. It appears after the widget renders the overtime state, but it is not reliable at the exact end boundary.
- Next bell uses stable cadence text from `nextBellText`, such as `Bell every 10m` or `Bell every 1:15`. A second-by-second next-bell countdown is avoided because it can reach `0:00` and wait for the next ActivityKit refresh.

Dynamic Island:

- Treat system black as the background.
- Use white for primary time and soft gold for secondary text.
- Expanded mode aligns timer and next-bell hierarchy clearly.
- Compact mode has no leading or trailing content because macOS also reuses this presentation for menu bar Live Activities.

Mac menu bar:

- macOS receives the compact Live Activity presentation through Apple Continuity.
- There is no app-level switch for hiding only the Mac menu bar presentation, so compact content is intentionally empty.

## Lifecycle

- Start creates a new Live Activity after any existing one is ended.
- Running ticks update app-owned state and bell playback. They do not drive per-second Live Activity rendering.
- Pause creates a paused state if the activity was swiped away and the app is open.
- Overtime sends an urgent update on the existing activity. Ending the old activity and immediately requesting a replacement can fail with `visibility`, leaving no visible notification.
- Foreground sync recreates the display when a session is active and the Live Activity was dismissed.

## Notification Text Findings

The current design is based on several iOS Live Activity constraints observed on-device:

- System timer text is the only reliable per-second moving element. `Text(endsAt, style: .timer)` continued past `0:00` when ActivityKit state updates did not visibly re-render the card.
- Ordinary state strings such as `41 sec left` do not update continuously in a Live Activity extension.
- Local per-second ActivityKit updates can be throttled, coalesced, or delayed, so they should not be used as the rendering clock.
- Publishing a final `0:00 / Meditating` state before overtime can leave the notification stale if the overtime update is delayed.
- `TimelineView` inside the Live Activity did not reliably flip static surrounding UI, such as a `+` prefix, at the session boundary.
- ActivityKit can accept an overtime state update while the visible notification still shows the previous rendered view.
- Requesting a replacement Live Activity at the overtime boundary can fail with `visibility`. The safer lifecycle is to keep the existing activity and update it.
- Stable cadence copy, such as `Bell every 1:15`, is more reliable than a secondary dynamic countdown that needs to roll over to the next bell.

## Non-Goals

- No separate alarm scheduling system.
- No server push updates.
- No full session restoration after process death in this iteration.
- No `activityStateUpdates` observer yet.

## Mac Sync

Mac menu bar Live Activities are Apple system behavior, not custom app synchronization. Apple Support says that after iPhone Mirroring connects to an iPhone, Mac automatically receives iPhone notifications and Live Activities, and Live Activities appear in the menu bar. Apple Human Interface Guidelines also note that active Live Activities appear in the menu bar of a paired Mac using compact, minimal, and expanded presentations.

References:

- https://support.apple.com/en-us/120684
- https://developer.apple.com/design/human-interface-guidelines/live-activities

## Verification

```sh
npm run test:timer
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
npm run ios:install
```

Latest verification on 2026-06-01: all commands above passed, and the app installed and launched on Eryu's iPhone 16 Pro.
