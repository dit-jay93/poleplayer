# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## V1 MVP Scope (Must-Have)
### A) Playback (Video/Image)
- Import: drag&drop files/folders, recent items.
- Playback: play/pause, JKL, shuttle, loop, in/out.
- **Frame step**: ±1 frame, repeat-hold behavior.
- Display: timecode, frame number, FPS, resolution.
- Zoom/pan; 1:1 pixel view; fit/fill.
- Still image viewing (single + next/prev).

### B) Precision vs Real-time Modes (Hybrid UX)
- Default: Real-time playback path.
- Auto-switch to Precision on:
  - frame-step, seek(frame), annotation edit, export still/burn-in.
- UI: minimal status pill `REAL-TIME / PRECISION`.
- Settings: optional “lock precision while annotating”.

### C) LUT / Look
- Load 3D LUT (.cube) and apply in viewer.
- LUT intensity 0..1; on/off toggle.
- LUT library folder support (user-configured).

### D) Review / Annotation + Persistence
- Tools: pen, rectangle, circle, arrow, text.
- Annotation ranges: single frame or frame range.
- Notes per review item; tags (free text).
- **Persistence**: App relaunch restores annotations and notes.
- Capture still: with/without burn-in (metadata overlay optional).

### E) Export / Share (Local Package)
- Export package:
  - `still_########.png`
  - optional `still_########_burnin.png`
  - `notes.json` (per `NOTES_SCHEMA.md`)
- Export options: destination folder, naming template.

### F) Audio (Basic)
- Audio playback with volume/mute.
- Sync stability acceptable for playback; no external WAV matching in V1.

---

## Out of Scope (V1)
- ARRIRAW/HDE, R3D native decode (V2 plugin).
- EXR multi-channel & AOV selection (V2).
- Multi-clip compare grid/wipe (V1.5+).
- Full reporting (PDF/HTML) (V2).
- Collaboration cloud sync (V2).

---

## Definition of Done (DoD) — V1
- Frame-step accuracy in Precision mode: **±0 frames**.
- Annotation persistence: 100% restore on relaunch for reference project.
- Export package opens on another machine and reproduces annotations from `notes.json`.
- H.264/H.265: Precision seek works (may be slower); Real-time playback remains smooth.
- Benchmarks meet pass criteria (`BENCHMARK.md`).
