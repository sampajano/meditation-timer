# Golden Meditation Timer

Golden Meditation Timer is an iOS-first meditation timer. The production iPhone app is a native UIKit/SwiftUI app implemented in `ios/App/App/AppDelegate.swift`. The React + Vite code under `web/` is a separate web implementation and build source for shared static assets.

Much gratitude toward [Gongmeister](http://gongmeister.app/) for the inspiration. Golden Meditation Timer adapts the idea for my own practice preferences, reliable background running when the app is closed (good for walking meditation), and other practice-specific flows close to daily life.

## Screenshots

<p>
  <img src="docs/images/home-setup.jpg" alt="Golden Meditation Timer setup screen" width="260">
  <img src="docs/images/home-meditating.jpg" alt="Golden Meditation Timer meditating screen" width="260">
</p>

## Start Here

- iOS app notes: [`ios/README.md`](ios/README.md)
- Web source: [`web/`](web/)

## Common Commands

```sh
npm install
npm run build
npm run ios:install
npm run ios:open
```

## Web Deployment

For Vercel, keep the project root at the repository root. `vercel.json` sets the build command to `npm run build` and the output directory to `web/dist`.
