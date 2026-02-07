# STATUS

Updated: 2026-02-07 20:53 KST

Current phase: 40 — Review System (Annotations + Persistence)

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
- Timeline state machine added (stopped/paused/playing) with in/out points and loop control
- Hybrid mode switching centralized for precision triggers (step/seek/annotate/export)
- DecodeKit precision path wired into PlayerCore (AVFoundationDecoder)
- Decoder prefetch warm-up implemented (best-effort)
- Unsupported codec detection now surfaces an error message
- LUT pipeline: .cube parser + Metal 3D LUT upload + intensity blend
- LUT UI: Open LUT panel + Toggle (T) + intensity slider
- RenderCore HUD overlay (TC/frame/FPS/res) composited in Metal
- RenderCore burn-in renderer helper added for export path
- ReviewStore (SQLite) added with assets/review_items/annotations tables
- Review models include normalized geometry types; ReviewStore round-trip tests pass

What’s next
- Manual GUI playback validation (ProRes/H.264/H.265 + still images)
- Precision frame accuracy spot-check on ProRes (random frames)
- Add import drag & drop and basic recent items
- Wire burn-in renderer into Export flow (future)
- Implement annotation toolset UI + overlay rendering
- Wire ReviewStore into app and restore on relaunch

Blockers / Risks
- Audio/video sync may drift (AssetReader frames are timer-driven)
- VFR support policy not locked yet
- Timecode track parsing deferred (timecode display is fps-derived)

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Use Open… to load clips in `PolePlayer/TestClips`
- J/K/L for reverse/pause/forward, Space to play/pause
- Left/Right arrow or ,/. for frame step
- I = set In point, O = set Out point, U = clear In/Out, P = toggle Loop
- Verify HUD (TC/frame/FPS/res) + debug counters (Src/VFrames/FSize/LastF/RTicks/LastR)
- Confirm checkerboard appears if no frames are arriving
