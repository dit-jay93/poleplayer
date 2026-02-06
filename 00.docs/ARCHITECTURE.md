# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Core Architecture
### Modules
- `App` — UI shell (SwiftUI + AppKit bridge)
- `PlayerCore` — timeline, mode state, controls, frame addressing
- `DecodeKit` — decoder interfaces & registry
- `RenderCore` — Metal rendering, LUT application, overlays composition
- `Review` — annotations, notes, ranges, persistence mapping
- `Library` — asset indexing, projects, search/filter
- `Export` — still capture, burn-in, packaging (notes.json)

---

## Playback Modes (Hybrid)
### Real-time Mode
- Goal: smooth playback and scrubbing.
- Uses: AVFoundation pipeline (AVPlayer/AVSampleBufferDisplayLayer approach depending on implementation).
- Allows approximate scrubbing on Long-GOP if necessary.

### Precision Mode
- Goal: frame-accurate (±0) step/seek for QC and annotation.
- Uses: frame-accurate decode path (asset reader / image generator / custom decoder plugin).
- Auto-enter triggers: frame step, seek(frame), annotate, export still.

### UX Exposure
- Minimal status indicator pill `REAL-TIME / PRECISION`
- Advanced: lock precision while annotating.

---

## Rendering Pipeline
1) Decoder outputs `DecodedFrame`:
   - CPU buffer or GPU texture
2) RenderCore uploads (if CPU) and applies:
   - LUT (3D .cube)
   - overlays (burn-in, HUD, guides)
   - review annotations (vector paths)
3) Final composited texture presented in viewer.

---

## Caching Strategy (V1)
- Central `FrameCache` keyed by:
  - assetHash + frameIndex + colorPipelineSignature(LUT on/off, LUT hash, intensity)
- Prefetch window:
  - Precision: ±N frames (e.g. 10–30)
  - Real-time: minimal or disabled (avoid memory spikes)

---

## Persistence Strategy
- DB is source-of-truth.
- Sidecar JSON is produced on export and optionally sync-written (explicit user opt-in).
- Asset matching uses SHA-256 + size + modified time (path is best-effort).
