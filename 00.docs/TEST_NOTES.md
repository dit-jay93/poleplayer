# TEST_NOTES

Updated: 2026-02-07 14:36 KST

## How to run
1. Open `Package.swift` in Xcode.
2. Select the `PolePlayerApp` scheme and run.

## Test clips (set your local paths)
- ProRes MOV (e.g., `.../ProRes_422HQ.mov`)
- H.264 MOV/MP4 (e.g., `.../H264.mp4`)
- H.265 MOV/MP4 (e.g., `.../H265.mov`)
- Still image PNG/TIFF/JPG

## M0 smoke steps
1. Launch the app.
2. Click Open… and load a ProRes MOV.
3. Confirm playback starts with Play button or Space.
4. Use J/K/L:
   - J = reverse step playback (manual frame stepping)
   - K = pause
   - L = play forward (press L again to increase rate)
5. Use Left/Right arrow (or ,/.) to frame-step.
6. In/Out + Loop:
   - I = set In point at current frame
   - O = set Out point at current frame
   - U = clear In/Out
   - P = toggle Loop on/off
7. Verify HUD shows timecode, frame index, FPS, resolution.
8. Verify mode pill switches to PRECISION on frame-step.
9. Repeat for H.264, H.265, and still images.

## Debug visibility checks (NEW)
- If video frames are not visible, a **checkerboard debug pattern** should still appear.
- HUD shows debug counters:
  - `Src`: frame source (`assetReader` or `videoOutput`)
  - `VFrames`: number of frames delivered to renderer
  - `FSize`: pixel buffer size
  - `LastF`: last frame host timestamp
  - `RTicks`: render loop tick count
  - `LastR`: last render tick timestamp
  - `PrecSrc`: imageGen usage indicator (shows `imageGen` or `imageGen-fail` for ~2s after precision step/seek)
  - When precision frame step/seek runs, `Src` should show `imageGen` while the frozen frame is active

## Automated smoke (headless decode)
Ran AVFoundation probe via a Swift script to validate load + frame extract on current `TestClips`:
- `IMG_6761.MOV`: playable, fps ~23.999, 2160x3840, duration ~214s, frame0 ok, frame1 ok
- `SPNprv.mov`: playable, fps 24.000, 1920x1080, duration ~290s, frame0 ok, frame1 ok
- `🍒사쿠란보!_dl.mp4`: playable, fps 60.000, 1080x1920, duration ~27s, frame0 ok, frame1 ok
- `KakaoTalk_20260206_172632119_01.png`: loaded, 653x8192
- `background.tiff`: loaded, 540x380
- `images.jpeg`: loaded, 284x177

## Expected results
- Video frames are visible (Metal viewer).
- Checkerboard appears if no frames are arriving.
- Frame counters update when frames arrive.
- Render tick counters increase continuously.
- Video plays smoothly for ProRes/H.264/H.265.
- Frame step advances/rewinds by one frame.
- HUD updates with frame index/timecode; resolution matches source.
- Mode pill shows REAL-TIME during play, PRECISION during frame-step.

## Known issues / limitations
- AssetReader video frames are timer-driven; audio/video sync may drift.
- Precision path still uses AVPlayer seek with zero tolerance (DecodeKit precision path not wired yet).
- Reverse playback uses manual frame stepping (may feel slower on long-GOP clips).
