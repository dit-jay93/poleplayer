# 30 — RenderCore (Metal Viewer + LUT + Overlays)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 20_DECODEKIT_AVF.md
- References: ARCHITECTURE.md, MVP.md

## Deliverables
- Code: Metal renderer, texture upload, LUT apply, HUD overlay composition
- Tests/Bench: Render pipeline unit tests (where possible) + visual baseline manual checks
- Docs: ARCHITECTURE.md LUT section finalized

## Checklist (Codex)
- [ ] Implement Metal view with texture presentation
- [ ] Implement LUT loader for .cube (parse + upload 3D texture)
- [ ] Apply LUT with intensity parameter
- [ ] Implement HUD overlay layer for timecode/frame index/FPS
- [ ] Implement burn-in renderer for export path

## Verification
- Manual smoke test:
- Toggle LUT on/off; no flicker; intensity changes are stable.
- Automated:
- Unit tests for LUT parser; basic render pipeline test harness compiles and runs.

## Notes / Decisions
- If CoreImage is used, document tradeoffs; keep deterministic output.
