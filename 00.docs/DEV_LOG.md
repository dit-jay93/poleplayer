# DEV_LOG

## 2026-02-07 01:51 KST
- Initialized tracking artifacts: STATUS, PROGRESS_CHECKLIST, DEV_LOG, TEST_NOTES.
- No code changes yet.

## 2026-02-07 02:14 KST
- Decision: Use Swift Package scaffold with modular targets (open `Package.swift` in Xcode) instead of generating a separate `.xcworkspace` for now. Rationale: no generator installed; SPM keeps modules clean while M0 is prioritized.
- Decision: M0 playback uses AVPlayer for real-time and precision (seek with zero tolerance); DecodeKit precision path is a follow-up. Rationale: deliver earliest testable playback.
- Note: Reverse playback via manual frame-step timer when J is pressed (fallback for negative rate support).
- Verification: `swift build` and `swift test` passed locally.

## 2026-02-07 02:32 KST
- Ran headless AVFoundation smoke probe on `TestClips`:
  - `IMG_6761.MOV` (fps ~23.999, 2160x3840) frame0/frame1 OK
  - `SPNprv.mov` (fps 24.000, 1920x1080) frame0/frame1 OK
  - `🍒사쿠란보!_dl.mp4` (fps 60.000, 1080x1920) frame0/frame1 OK
  - PNG/TIFF/JPEG stills loaded successfully
- Note: Manual GUI playback verification is still pending.

## 2026-02-07 02:48 KST
- Refactor: PlayerCore and DecodeKit migrated to async AVFoundation `load(...)` APIs to remove deprecated calls and avoid build warnings.
- Note: DecodeKit AVFoundation decoder uses `@unchecked Sendable` to allow background async track loading for fps initialization.

## 2026-02-07 11:41 KST
- Fix: Force video view to expand to available space to avoid zero-size AVPlayerView (videos appeared blank while audio played).

## 2026-02-07 11:49 KST
- Fix attempt: Wrap viewer area in GeometryReader to ensure non-zero height for AVPlayerView; aim to resolve “audio-only, no video frames” symptom.

## 2026-02-07 12:02 KST
- Fix: CI uses Swift 6.1.x on macos-latest; set Package.swift tools version to 6.1 to avoid build failure.

## 2026-02-07 12:12 KST
- Fix: removed actor-isolated deinit cleanup in PlayerController to avoid Swift 6.1 CI error (isolated deinit requires experimental flag). Cleanup remains in explicit `clear()` path.

## 2026-02-07 12:12 KST
- Plan execution: switched viewer rendering to Metal (MTKView + CVPixelBuffer -> MTLTexture) to bypass AVPlayerView blank video issue.
- Added AVPlayerItemVideoOutput in PlayerCore to pull BGRA pixel buffers for Metal display.
- Metal shader is embedded as a source string in RenderCore to avoid SwiftPM .metal handling issues.

## 2026-02-07 12:28 KST
- Implemented AssetReader-based decode path (DecodeKit.AssetReaderFrameSource) and wired PlayerCore to use it when Metal rendering is enabled.
- Real-time frames now come from AVAssetReader on a timer; audio still uses AVPlayer and may drift.

## 2026-02-07 12:41 KST
- Debug: Added Metal fallback checkerboard pattern when no frame is available and HUD counters for frame source/count/size/last frame timestamp.
- This is intended to force visibility of the render path even if decode fails.

## 2026-02-07 12:55 KST
- Debug: Added render tick counters to confirm MTKView draw loop is active even if frames are missing.
- Fix: Restored valid Swift tools comment in Package.swift (was corrupted to '/ /').

## 2026-02-07 13:18 KST
- Fix: SwiftUI subviews now observe PlayerController directly (@ObservedObject) so video state changes (hasVideo/mode/debug counters) render immediately. This should unblock Metal viewer display + debug HUD updates.

## 2026-02-07 13:32 KST
- Fix: FontRegistrar now searches both Bundle.module and Bundle.main for Pretendard fonts; logs bundle resource paths to diagnose missing font resources.

## 2026-02-07 13:45 KST
- Precision: Added AVAssetImageGenerator path to produce frozen frames on precision seek/step (imageGen -> CVPixelBuffer -> Metal).

## 2026-02-07 14:00 KST
- Debug: Differentiated frozen imageGen frames vs assetReader in HUD (`Src` now shows `imageGen` when frozen). Added precision failure indicator (`imageGen-fail`) to confirm imageGen attempts even if frame creation fails.

## 2026-02-07 14:36 KST
- PlayerCore: Added timeline state machine (stopped/paused/playing) with in/out points and looping controls; loop seek now clamps to in/out range.
- PlayerCore: Hybrid mode switching centralized (precision triggers recorded for step/seek/annotate/export).
- UI: Added I/O/U/P keyboard shortcuts for in/out/clear/loop; transport hint updated.

## 2026-02-07 15:45 KST
- DecodeKit: Precision path now routed through DecoderPlugin (AVFoundationDecoder) instead of direct AVAssetImageGenerator calls in PlayerCore.
- DecodeKit: Added fps hinting and prefetch warm-up; precision decode uses frameIndex mapping with zero tolerance.
- PlayerCore: Added codec subtype validation to surface unsupported streams to UI.
- Decision: Timecode track parsing deferred; timecode display remains fps-derived (no drop-frame handling yet).

## 2026-02-07 16:46 KST
- RenderCore: Added .cube LUT parser + 3D LUT texture upload (RGBA16F) with intensity blending in Metal shader.
- App: Added LUT open panel, toggle (T), and intensity slider wired to Metal renderer.
- Tests: Added RenderCore LUT parser tests; `swift test` passes.

## 2026-02-07 17:03 KST
- RenderCore: Added HUD overlay renderer (timecode/frame/fps/res) as a texture composited in Metal.
- RenderCore: Added burn-in renderer helper for export path (renders HUD overlay onto a still image).
- Build hygiene: Fixed accidental `Package.swift` tools header corruption (restored `// swift-tools-version: 6.1`).

## 2026-02-07 20:53 KST
- Review: Added SQLite-backed ReviewStore with assets/review_items/annotations tables.
- Review: Added normalized geometry models + round-trip tests for ReviewStore.

## 2026-02-07 21:02 KST
- Review/UI: Added annotation toolset (pen/rect/circle/arrow/text) with normalized geometry capture.
- RenderCore: Added overlay composer for HUD + annotations; annotations render in Metal overlay.
- Review: Added ReviewSession (load/create, draft, persist) and asset hashing for DB restore.
- Tests: Added normalized geometry clamp tests; `swift test` passes.

## 2026-02-07 21:20 KST
- Export: Added Export module with notes.json writer (schema v1.0.0) and package builder.
- Export: Still capture wired to precision decoder (fallback to current pixel buffer).
- UI: Added Burn-in toggle and Export… panel (folder chooser + naming template).
- Notes: Export writes asset hash + timeline metadata + annotations into notes.json.
- Tests: Added ExportNotes tests; `swift test` passes.

## 2026-02-07 21:28 KST
- Bench: Added PolePlayerBench CLI (step accuracy, random seek, LUT toggle harness) with JSON report output.
- Bench: CI runs reduced benchmark on generated H.264 clip.
- Docs: BENCHMARK.md updated with run instructions.
