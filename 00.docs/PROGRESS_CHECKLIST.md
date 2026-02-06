# PROGRESS_CHECKLIST

Last updated: 2026-02-07 01:51 KST

Rule: When an item is completed, mark [x] and append "(commit: <hash>, time: <Asia/Seoul>, verify: <note>)".

## 00 — Project Setup & CI
- [ ] Create Xcode workspace with modular targets: PlayerCore, RenderCore, DecodeKit, Review, Library, Export
- [ ] Set up SwiftLint/formatting (optional) and basic coding conventions
- [ ] Add CI pipeline: build Debug/Release, run unit tests
- [ ] Add minimal crash logging hook (can be stub for MVP)
- [ ] Add feature flags system (simple)

## 10 — PlayerCore (Timeline, Modes, Controls)
- [ ] Implement timeline state machine: play/pause/stop/loop/in-out
- [ ] Implement keyboard controls: JKL, frame step, seek-to-frame
- [ ] Implement hybrid mode switching rules (auto precision triggers)
- [ ] Expose playback observables for UI (timecode/frame index)
- [ ] Integrate basic overlay data: fps, resolution, frame index

## 20 — DecodeKit (AVFoundation Decoders for MOV/MP4)
- [ ] Implement DecoderPlugin for MOV/MP4 using AVFoundation
- [ ] Provide timing mapping (fps, timecode if available)
- [ ] Implement precision decodeFrame(frameIndex) with ±0 accuracy on ProRes
- [ ] Implement prefetch(frames) to warm cache window
- [ ] Gracefully handle unsupported streams (errors surfaced to UI)

## 30 — RenderCore (Metal Viewer + LUT + Overlays)
- [ ] Implement Metal view with texture presentation
- [ ] Implement LUT loader for .cube (parse + upload 3D texture)
- [ ] Apply LUT with intensity parameter
- [ ] Implement HUD overlay layer for timecode/frame index/FPS
- [ ] Implement burn-in renderer for export path

## 40 — Review System (Annotations + Persistence)
- [ ] Implement annotation toolset: pen/rect/circle/arrow/text
- [ ] Store geometry in normalized 0..1 coordinates with top-left origin
- [ ] Bind annotations to single frame or frame range
- [ ] Implement DB persistence for review items + annotations
- [ ] On relaunch, restore review state and render overlays on correct frames

## 50 — Export Package (Still + notes.json)
- [ ] Implement still capture from current frame (PNG)
- [ ] Implement burn-in still capture option
- [ ] Generate notes.json per schema version 1.0.0
- [ ] Include asset hash and timeline metadata in notes.json
- [ ] Provide export naming template and destination selection

## 60 — Benchmark Automation (Scripted Tests)
- [ ] Implement step accuracy test: +1 frame x 1000 with expected vs actual
- [ ] Implement random seek test: 100 seeks, measure accuracy and latency
- [ ] Implement LUT toggle consistency test harness
- [ ] Output results as benchmark_report.json
- [ ] Define pass/fail thresholds matching BENCHMARK.md
