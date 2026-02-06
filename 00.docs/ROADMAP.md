# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Roadmap (High-level)
### V1 (MVP) — "Playback + LUT + Review + Persistence + Export"
- Goal: ship a reliable on-set / post review player that is frame-accurate and keeps annotations across restarts.
- Primary formats: **MOV(ProRes)** + **MP4/MOV(H.264/H.265)** + still images.
- Storage: **DB is source of truth**, optional **sidecar JSON export/sync**.

### V1.5 — "QC Depth"
- Add: scopes (waveform/vectorscope/histogram), DPX or EXR basic (RGB) support, improved caching.
- Add: compare views (A/B, wipe) minimal.

### V2 — "Pro Camera Formats + Collaboration"
- Add: plugin decoders (ARRIRAW/HDE, R3D), EXR multi-channel (AOV), multi-clip grid, integrations (Frame.io/ShotGrid/Slack), reporting.

---

## Milestones & Gates
### Gate G0 — Sprint 0 Complete (Risk PoC)
- 4K ProRes real-time playback stable (no consistent dropped frames on reference machine).
- Precision mode prototype: **seek(frameIndex)** returns exact frame.
- Annotation persistence prototype: create → save → relaunch → restore 100%.

### Gate G1 — MVP Feature Complete
- V1 feature checklist satisfied (see `MVP.md`).
- Benchmarks pass (see `BENCHMARK.md`).

### Gate G2 — Beta
- Crash logging enabled.
- Export package is stable (still + notes.json).
- Known issues triaged with severity rules.

### Gate G3 — Release Candidate (RC)
- Regression suite passed.
- Installer/signing/notarization pipeline verified (distribution-dependent).

---

## Dependencies / Risks
- Long-GOP (H.264/H.265) frame-accurate scrubbing is harder → separate real-time vs precision decode paths.
- Pro camera RAW support requires SDK/licensing → V2 plugin approach.
- Sandboxing and TCC access affects sidecar writing → default DB + explicit export.
