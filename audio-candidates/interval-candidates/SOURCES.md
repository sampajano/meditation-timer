# Interval Bell Source

This folder documents the final selected interval bell source for the app. The Freesound page was checked on 2026-05-31 and showed Creative Commons 0.

For a final App Store release, prefer downloading the original FLAC from Freesound while logged in, then rerun the same trim/mastering step. The file kept under `../../candidates/` is the public HQ preview MP3 from Freesound's CDN.

## Selected Interval Bell

### singing bowl - single strike 7

- Author: s-light
- Source: https://freesound.org/people/s-light/sounds/411485/
- License: Creative Commons 0
- Original download shown by Freesound: `411485__s-light__singing-bowl-single-strike-7.flac`
- Local unedited preview: `../candidates/s-light-411485-single-strike-7-bright-hq.mp3`
- App-ready file: `final/s-light-411485-interval-bell.mp3`
- Tracked app asset updated: `web/public/interval-bell.mp3`, which Xcode bundles into the iOS app as `public/interval-bell.mp3`.
- Local ignored iOS copy synced for device testing: `ios/App/App/public/interval-bell.mp3`.
- Processing notes:
  - Trimmed off the tiny lead silence, then exported a 20-second interval bell.
  - Applied a fade-out from the beginning so the bell fully disappears by 20 seconds.
  - Lowered the file gain by 5.8 dB, then the app plays it at 0.65 volume so it stays below the main start/end bell.
