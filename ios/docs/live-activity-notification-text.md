# Live Activity Notification Text Notes

These notes capture what we learned while iterating on the lock-screen Live Activity text.

## What Works

- Use SwiftUI dynamic date text for the primary timer:
  - `Text(timerInterval: Date()...endsAt, countsDown: true)` for countdown.
  - `Text(timerInterval: startedAt...endsAt, countsDown: false)` for overtime.
- Keep secondary Live Activity text stable when possible. A cadence label such as `Bell every 2m` or `Bell every 1:15` is more reliable than a second countdown.
- Snap display target dates to whole seconds before storing them in ActivityKit state. Sub-second jitter can make state appear different every tick.
- Use fixed-width trailing layout for the timer column so the primary timer and secondary bell text align visually.
- Keep exact cadence formatting separate from countdown formatting:
  - Countdown text can round for readability, such as `Next bell in 2m`.
  - Cadence text should preserve non-minute intervals, such as `Bell every 1:15`.

## What Does Not Work Reliably

- Do not expect ordinary `Text("41 sec left")` in a Live Activity to update every second. Widget extensions are not continuously running views.
- Do not rely on local ActivityKit updates every second to drive visible countdown text. iOS may throttle, coalesce, or delay updates.
- Do not use a secondary `next bell` dynamic countdown if it needs to roll over to the next bell. It can reach `0:00` and stay there until the app is allowed to push a new state.
- Do not make hidden or unused state strings change every tick. Even if the widget does not display them, changing content state can flood Live Activity updates.
- Avoid using relative date formatting for precise countdown behavior. It can be coarse and system-controlled.

## Current Design

- Primary lock-screen timer uses system dynamic timer text.
- The secondary bell line shows stable cadence text: `Bell every 2m`, `Bell every 1:15`, or `Bell every 0:45`.
- The app UI can still show `Next bell in ...`; that is app-controlled foreground UI and does not have the same Live Activity constraints.
- Live Activity updates should happen for real session state transitions, not as a per-second rendering mechanism.
