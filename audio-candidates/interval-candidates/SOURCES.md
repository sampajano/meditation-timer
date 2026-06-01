# Interval Bell Source

This folder documents the selected interval bell source for the app. The Freesound page was checked on 2026-05-31 and showed Creative Commons 0.

For a final App Store release, prefer downloading the original AIFF from Freesound while logged in, then rerun the same trim/mastering step. The file under `previews-selected/` is the public HQ preview MP3 from Freesound's CDN.

## Selected Interval Bell

### BELLS 05

- Author: ganapataye
- Source: https://freesound.org/people/ganapataye/sounds/390203/
- License: Creative Commons 0
- Original download shown by Freesound: `390203__ganapataye__bells-05.aiff`
- Local unedited preview: `previews-selected/ganapataye-390203-bells-05-hq.mp3`
- App-ready file: `final/ganapataye-390203-interval-bell.mp3`
- Tracked app asset replaced: `web/public/tingsha3.mp3`, which Xcode bundles into the iOS app as `public/tingsha3.mp3`.
- Local ignored iOS copy synced for device testing: `ios/App/App/public/tingsha3.mp3`.
- Processing notes:
  - Trimmed to 5.4 seconds so the interval bell is distinct and short enough for repeated use.
  - Added only tiny fades to avoid edit clicks or hard stops.
  - Normalized quieter than the main start/end bell so interval bells feel supportive rather than dominant.
