# Shared App Audio Sources

These files document the shared app audio assets and the CC0 bell sources considered for the app. Freesound pages were checked on 2026-05-31 and showed Creative Commons 0.

`shared/audio/` is the app-facing source of truth for bell audio. The native iOS app bundles this folder as `audio/`, and the web app imports these files through Vite.

For a final App Store release, prefer downloading the original WAV/FLAC files from Freesound while logged in, then rerun the same trim/mastering step. The candidate files currently kept under `../../audio-candidates/candidates/` are public HQ preview MP3s from Freesound's CDN for local listening and selection.

## License Notes

- License: Creative Commons 0
- Freesound page text for these sounds states that the sound can be copied, modified, distributed, and performed, even for commercial purposes, without asking permission from the author.
- CC0 is suitable for an App Store app, including a free app, but Freesound is user-uploaded content. Keep this source note with the project for provenance.

## Selected App Bell

### Tibetan singing bowl

- Author: enhuber
- Source: https://freesound.org/people/enhuber/sounds/400819/
- License: Creative Commons 0
- Original download shown by Freesound: `400819__enhuber__tibetan-singing-bowl.wav`
- Local unedited preview: `../../audio-candidates/candidates/enhuber-400819-tibetan-singing-bowl-hq.mp3`
- App-ready file: `start.mp3`
- iOS bundle path: `audio/start.mp3`
- Web import path: `../../shared/audio/start.mp3?url`
- Processing notes:
  - Started from the public HQ preview MP3 while keeping the original preview in `../../audio-candidates/candidates/`.
  - The original preview is 1:25.62 long. Trimmed to the manually selected 14.65s start point, leaving about 70.97 seconds of usable bowl sound after the strike.
  - Added only a micro fade-in at the start to avoid an edit click while preserving the bowl hit.
  - Exported a 60-second app-ready file, with the natural bowl tail preserved through 30 seconds and a gradual fade-out from 30s to 60s.
  - Lowered the file gain by 3.4 dB so the longer export keeps a peak level close to the previous app bell and does not become louder than expected.

## Selected Interval Bell

### singing bowl - single strike 7

- Author: s-light
- Source: https://freesound.org/people/s-light/sounds/411485/
- License: Creative Commons 0
- Original download shown by Freesound: `411485__s-light__singing-bowl-single-strike-7.flac`
- Local unedited preview: `../../audio-candidates/candidates/s-light-411485-single-strike-7-bright-hq.mp3`
- App-ready file: `interval-bell.mp3`
- iOS bundle path: `audio/interval-bell.mp3`
- Web import path: `../../shared/audio/interval-bell.mp3?url`
- Processing notes:
  - Trimmed off the tiny lead silence, then exported a 20-second interval bell.
  - Applied a fade-out from the beginning so the bell fully disappears by 20 seconds.
  - Lowered the file gain by 5.8 dB, then the app plays it at 0.65 volume so it stays below the main start/end bell.

## Unedited Additional Candidates

### singing bowl - single strike 1

- Author: s-light
- Source: https://freesound.org/people/s-light/sounds/411484/
- License: Creative Commons 0
- Original download shown by Freesound: `411484__s-light__singing-bowl-single-strike-1.flac`
- Local unedited preview: `../../audio-candidates/candidates/s-light-411484-single-strike-1-hq.mp3`
- Source description notes: soft mallet, main frequencies listed as 182Hz, 519Hz, and 967Hz.

### singing bowl - single strike 2

- Author: s-light
- Source: https://freesound.org/people/s-light/sounds/411483/
- License: Creative Commons 0
- Original download shown by Freesound: `411483__s-light__singing-bowl-single-strike-2.flac`
- Local unedited preview: `../../audio-candidates/candidates/s-light-411483-single-strike-2-hq.mp3`
- Source description notes: soft mallet, main frequencies listed as 182Hz, 519Hz, and 967Hz.

### singing bowl - single strike 7

- Author: s-light
- Source: https://freesound.org/people/s-light/sounds/411485/
- License: Creative Commons 0
- Original download shown by Freesound: `411485__s-light__singing-bowl-single-strike-7.flac`
- Local unedited preview: `../../audio-candidates/candidates/s-light-411485-single-strike-7-bright-hq.mp3`
- Source description notes: brighter candidate; soft mallet, main frequencies listed as 182Hz, 519Hz, and 967Hz.
