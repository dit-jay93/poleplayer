# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Development Plan (Sprints)
> Suggested cadence: 2-week sprints. Adjust as needed.

### Sprint 0 — Risk PoC (1–2 weeks)
**Deliverables**
- Playback PoC: 4K ProRes, JKL, basic scrub.
- Precision path PoC: seek(frameIndex) exact.
- Metal viewer PoC: render + LUT apply (minimal).
- Review PoC: basic rect/pen drawing + save/restore.

**Gate**
- Pass G0 in `ROADMAP.md`.

---

### Sprint 1 — PlayerCore + Library Basics
**Deliverables**
- Import (file/folder), recent items.
- Timeline state machine (play, pause, step, seek).
- Real-time mode stable playback.
- Basic overlays (TC/FPS/frame/res).

**Acceptance**
- 10-minute playback without crash.
- Frame step works and is responsive (even if not yet perfect for all formats).

---

### Sprint 2 — Precision Mode + Caching
**Deliverables**
- Precision decode path (frame-accurate).
- Cache strategy (prefetch N frames around current).
- Mode switching rules implemented (hybrid UX).

**Acceptance**
- ProRes: precision seek and step exact (±0).
- H.265: precision seek exact on reference clip (latency allowed).

---

### Sprint 3 — LUT + QC Minimum
**Deliverables**
- LUT loader (.cube) + intensity + toggle.
- Viewer transforms: 1:1, fit/fill, zoom/pan.
- Pixel sampler tool (read pixel value at cursor).
- Burn-in overlay template (basic).

**Acceptance**
- LUT toggles without visual flicker across frames.
- Pixel sampler stable and correct in zoom states.

---

### Sprint 4 — Review System + Persistence + Export
**Deliverables**
- Annotation tools (pen/rect/circle/arrow/text).
- Review items with frame-range binding.
- DB persistence and project reopen.
- Export package (still + notes.json).

**Acceptance**
- Relaunch restores review items.
- Exported package renders same overlays.

---

## Ongoing (Every Sprint)
- CI build + unit tests run.
- Performance bench subset run.
- Docs updated when interfaces change.
