# STATUS

Updated: 2026-02-07 12:28 KST

Current phase: 10 — PlayerCore (M0 playback shell in progress)

What’s done
- Swift Package scaffold with modular targets (PlayerCore/DecodeKit/RenderCore/Review/Library/Export)
- Basic app shell + viewer + HUD + REAL-TIME/PRECISION pill
- AVPlayer-backed playback with JKL, space, frame step
- Pretendard fonts bundled + registered on launch
- CI workflow added (build + test)
- Headless AVFoundation smoke decode on TestClips (load + frame extract OK)
- Viewer rendering path switched to Metal (MTKView)
- AssetReader decode path added for Metal rendering (AVAssetReaderTrackOutput → CVPixelBuffer)

What’s next
- Re-test GUI video playback after AssetReader path
- Manual GUI playback validation (ProRes/H.264/H.265 + still images)
- Tighten hybrid mode switching rules + frame-accurate step/seek validation
- Add import drag & drop and basic recent items

Blockers / Risks
- Video still not visible previously; need confirmation after AssetReader path
- Audio/video sync may drift (AssetReader frames are timer-driven)
- Precision path still uses AVPlayer seek with zero tolerance (placeholder until DecodeKit precision path)
- VFR support policy not locked yet

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Use Open… to load clips in `PolePlayer/TestClips`
- J/K/L for reverse/pause/forward, Space to play/pause
- Left/Right arrow or ,/. for frame step
- Verify HUD (TC/frame/FPS/res) + mode pill updates
- Confirm video frames are visible with AssetReader + Metal viewer
