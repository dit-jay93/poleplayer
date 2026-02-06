# TEST_NOTES

Updated: 2026-02-07 02:14 KST

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
6. Verify HUD shows timecode, frame index, FPS, resolution.
7. Verify mode pill switches to PRECISION on frame-step.
8. Repeat for H.264, H.265, and still images.

## Expected results
- Video plays smoothly for ProRes/H.264/H.265.
- Frame step advances/rewinds by one frame.
- HUD updates with frame index/timecode; resolution matches source.
- Mode pill shows REAL-TIME during play, PRECISION during frame-step.

## Known issues / limitations
- Precision path is AVPlayer seek with zero tolerance (DecodeKit precision path not wired yet).
- Reverse playback uses manual frame stepping (may feel slower on long-GOP clips).
