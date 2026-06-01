# Tingsha Source

This folder documents the selected tingsha source for the app. The Freesound page was checked on 2026-05-31 and showed Creative Commons 0.

For a final App Store release, prefer downloading the original WAV from Freesound while logged in, then rerun the same trim/mastering step. The file under `previews-selected/` is the public HQ preview MP3 from Freesound's CDN.

## Selected Tingsha

### Tingsha Cymbal

- Author: steffcaffrey
- Source: https://freesound.org/people/steffcaffrey/sounds/435074/
- License: Creative Commons 0
- Original download shown by Freesound: `435074__steffcaffrey__tingsha-cymbal.wav`
- Local unedited preview: `previews-selected/steffcaffrey-435074-tingsha-cymbal-hq.mp3`
- App-ready file: `final/steffcaffrey-435074-tingsha-cymbal.mp3`
- Tracked app asset added: `web/public/tingsha.mp3`, which Xcode bundles into the iOS app as `public/tingsha.mp3`.
- Local ignored iOS copy synced for device testing: `ios/App/App/public/tingsha.mp3`.
- Processing notes:
  - Trimmed to 4.2 seconds so the tingsha option remains short and distinct from the interval bell.
  - Added only tiny fades to avoid edit clicks or hard stops.
  - Normalized slightly quieter than the selected interval bell because tingsha is naturally brighter.
