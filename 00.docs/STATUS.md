# STATUS

Updated: 2026-02-07 11:41 KST

Current phase: 10 — PlayerCore (M0 playback shell in progress)

What’s done
- Swift Package scaffold with modular targets (PlayerCore/DecodeKit/RenderCore/Review/Library/Export)
- Basic app shell + viewer + HUD + REAL-TIME/PRECISION pill
- AVPlayer-backed playback with JKL, space, frame step
- Pretendard fonts bundled + registered on launch
- CI workflow added (build + test)
- Headless AVFoundation smoke decode on TestClips (load + frame extract OK)
- Fix: Video view now expands to avoid zero-size AVPlayerView (blank video issue)

What’s next
- Manual GUI playback validation (ProRes/H.264/H.265 + still images)
- Tighten hybrid mode switching rules + frame-accurate step/seek validation
- Add import drag & drop and basic recent items

Blockers / Risks
- Precision path still uses AVPlayer seek with zero tolerance (placeholder until DecodeKit precision path)
- VFR support policy not locked yet

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Use Open… to load clips in `PolePlayer/TestClips`
- J/K/L for reverse/pause/forward, Space to play/pause
- Left/Right arrow or ,/. for frame step
- Verify HUD (TC/frame/FPS/res) + mode pill updates
