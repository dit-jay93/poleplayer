# STATUS

Updated: 2026-02-07 14:00 KST

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
- Debug pattern (checkerboard) + frame counters + render ticks added
- SwiftUI views now observe PlayerController directly so state changes render
- Precision path uses AVAssetImageGenerator to render frozen frame on seek/step
- HUD now distinguishes frozen precision frames: `Src` shows `imageGen` when frozen; `PrecSrc` shows imageGen or imageGen-fail (recent)

What’s next
- Re-test precision frame step/seek with imageGen path
- Manual GUI playback validation (ProRes/H.264/H.265 + still images)
- Tighten hybrid mode switching rules + frame-accurate step/seek validation
- Add import drag & drop and basic recent items

Blockers / Risks
- Audio/video sync may drift (AssetReader frames are timer-driven)
- VFR support policy not locked yet

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Use Open… to load clips in `PolePlayer/TestClips`
- J/K/L for reverse/pause/forward, Space to play/pause
- Left/Right arrow or ,/. for frame step
- Verify HUD (TC/frame/FPS/res) + debug counters (Src/VFrames/FSize/LastF/RTicks/LastR)
- Confirm checkerboard appears if no frames are arriving
