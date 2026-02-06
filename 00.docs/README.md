# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Document Index
1. `ROADMAP.md` — Release roadmap & milestones
2. `MVP.md` — V1 scope (MVP) and DoD
3. `DEV_PLAN.md` — Sprint plan with acceptance gates
4. `ARCHITECTURE.md` — Modules, modes, rendering/decoding strategy
5. `CODEC_POLICY.md` — Supported/partial/unsupported formats (V1) + rules
6. `BENCHMARK.md` — Frame-accuracy benchmark scenarios + pass criteria
7. `DATA_MODEL.md` — DB + sidecar storage model
8. `NOTES_SCHEMA.md` — `notes.json` export schema + field rules
9. `DECODER_API.md` — Plugin decoder API (interface contract)
10. `PARTS/` — Per-part task lists (same format) for Codex checkoffs
11. `RnR/` — Role & Responsibility checklists (by owner)

## How to use with Codex
- Treat each task list as a checklist.
- For each checklist item, Codex should:
  1) implement, 2) add tests/bench, 3) update docs, 4) run a verification step.

## Naming
- App name is placeholder; replace later.
