# Agent Guidelines :)

## iOS Iteration Workflow

- After every iOS app change iteration, run `npm run ios:install` first to build and install the freshly changed app on Eryu's phone.
- Prefer `npm run ios:install` over direct simulator or `xcrun simctl install` commands so the repository script controls the phone target and install behavior.
- If `npm run ios:install` cannot install on the phone, pause and ask whether Eryu wants to build/install to an iOS Simulator instead.

## Architecture Orientation

- Treat the iPhone app as a native UIKit/SwiftUI app.
- The active iOS entry point is `ios/App/GoldenMeditationApp/AppDelegate.swift`, which hosts `MeditationAppView` through `UIHostingController`.
- The React + Vite app under `web/` is separate from the production iPhone UI. Do not assume the iOS app runs the React UI in a WebView.
