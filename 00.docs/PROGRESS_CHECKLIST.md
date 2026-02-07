# PROGRESS_CHECKLIST

Last updated: 2026-02-07 21:28 KST

Rule: When an item is completed, mark [x] and append "(commit: <hash>, time: <Asia/Seoul>, verify: <note>)".

## 00 — Project Setup & CI
- [x] Create Xcode workspace with modular targets: PlayerCore, RenderCore, DecodeKit, Review, Library, Export (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: `swift build` + `swift test` ok; open `Package.swift` in Xcode)
- [ ] Set up SwiftLint/formatting (optional) and basic coding conventions
- [x] Add CI pipeline: build Debug/Release, run unit tests (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: workflow file added)
- [x] Add minimal crash logging hook (can be stub for MVP) (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: build ok)
- [x] Add feature flags system (simple) (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: build ok)

## 10 — PlayerCore (Timeline, Modes, Controls)
- [x] Implement timeline state machine: play/pause/stop/loop/in-out (commit: cf24593, time: 2026-02-07 14:36 KST, verify: `swift build` ok)
- [x] Implement keyboard controls: JKL, frame step, seek-to-frame (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: build ok; manual playback pending)
- [x] Implement hybrid mode switching rules (auto precision triggers) (commit: cf24593, time: 2026-02-07 14:36 KST, verify: `swift build` ok)
- [x] Expose playback observables for UI (timecode/frame index) (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: build ok)
- [x] Integrate basic overlay data: fps, resolution, frame index (commit: dfa4a39, time: 2026-02-07 02:14 KST, verify: build ok)

## 20 — DecodeKit (AVFoundation Decoders for MOV/MP4)
- [x] Implement DecoderPlugin for MOV/MP4 using AVFoundation (commit: cf815c6, time: 2026-02-07 15:45 KST, verify: `swift build` ok)
- [x] Provide timing mapping (fps, timecode if available) (commit: cf815c6, time: 2026-02-07 15:45 KST, verify: fps hint wired; timecode derived from fps)
- [x] Implement precision decodeFrame(frameIndex) with ±0 accuracy on ProRes (commit: cf815c6, time: 2026-02-07 15:45 KST, verify: `swift build` ok; manual accuracy check pending)
- [x] Implement prefetch(frames) to warm cache window (commit: cf815c6, time: 2026-02-07 15:45 KST, verify: `swift build` ok)
- [x] Gracefully handle unsupported streams (errors surfaced to UI) (commit: cf815c6, time: 2026-02-07 15:45 KST, verify: `swift build` ok)

## 30 — RenderCore (Metal Viewer + LUT + Overlays)
- [x] Implement Metal view with texture presentation (commit: 75e9ef5, time: 2026-02-07 14:36 KST, verify: manual playback visible in app)
- [x] Implement LUT loader for .cube (parse + upload 3D texture) (commit: 26ebc26, time: 2026-02-07 16:46 KST, verify: `swift build` ok; LUT parser tests added)
- [x] Apply LUT with intensity parameter (commit: 26ebc26, time: 2026-02-07 16:46 KST, verify: `swift test` ok)
- [x] Implement HUD overlay layer for timecode/frame index/FPS (commit: bbaaee6, time: 2026-02-07 17:03 KST, verify: `swift build` + `swift test` ok)
- [x] Implement burn-in renderer for export path (commit: bbaaee6, time: 2026-02-07 17:03 KST, verify: `swift build` + `swift test` ok)

## 40 — Review System (Annotations + Persistence)
- [x] Implement annotation toolset: pen/rect/circle/arrow/text (commit: 70858dd, time: 2026-02-07 21:02 KST, verify: `swift build` + `swift test` ok)
- [x] Store geometry in normalized 0..1 coordinates with top-left origin (commit: 70858dd, time: 2026-02-07 21:02 KST, verify: `swift test` ok; clamp tests added)
- [x] Bind annotations to single frame or frame range (commit: 70858dd, time: 2026-02-07 21:02 KST, verify: `swift test` ok)
- [x] Implement DB persistence for review items + annotations (commit: 354b7bf, time: 2026-02-07 20:53 KST, verify: `swift test` ok)
- [x] On relaunch, restore review state and render overlays on correct frames (commit: 70858dd, time: 2026-02-07 21:02 KST, verify: `swift build` + `swift test` ok; manual restore pending)

## 50 — Export Package (Still + notes.json)
- [x] Implement still capture from current frame (PNG) (commit: f3b9404, time: 2026-02-07 21:20 KST, verify: `swift build` ok)
- [x] Implement burn-in still capture option (commit: f3b9404, time: 2026-02-07 21:20 KST, verify: `swift build` ok)
- [x] Generate notes.json per schema version 1.0.0 (commit: f3b9404, time: 2026-02-07 21:20 KST, verify: `swift test` ok)
- [x] Include asset hash and timeline metadata in notes.json (commit: f3b9404, time: 2026-02-07 21:20 KST, verify: `swift test` ok)
- [x] Provide export naming template and destination selection (commit: f3b9404, time: 2026-02-07 21:20 KST, verify: manual export in UI + `swift build` ok)

## 60 — Benchmark Automation (Scripted Tests)
- [x] Implement step accuracy test: +1 frame x 1000 with expected vs actual (commit: 900ef21, time: 2026-02-07 21:28 KST, verify: `swift build` ok; manual bench run pending)
- [x] Implement random seek test: 100 seeks, measure accuracy and latency (commit: 900ef21, time: 2026-02-07 21:28 KST, verify: `swift build` ok; manual bench run pending)
- [x] Implement LUT toggle consistency test harness (commit: 900ef21, time: 2026-02-07 21:28 KST, verify: `swift build` ok; manual bench run pending)
- [x] Output results as benchmark_report.json (commit: 900ef21, time: 2026-02-07 21:28 KST, verify: `swift build` ok; manual bench run pending)
- [x] Define pass/fail thresholds matching BENCHMARK.md (commit: 900ef21, time: 2026-02-07 21:28 KST, verify: `swift test` ok)
