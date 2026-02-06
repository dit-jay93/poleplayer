# 40 — Review System (Annotations + Persistence)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 30_RENDERCORE_LUT.md
- References: DATA_MODEL.md, NOTES_SCHEMA.md, MVP.md

## Deliverables
- Code: Annotation tools, normalized geometry, range binding, DB save/restore
- Tests/Bench: Round-trip tests: create->save->load equals; geometry normalization tests
- Docs: DATA_MODEL.md updated with final fields

## Checklist (Codex)
- [ ] Implement annotation toolset: pen/rect/circle/arrow/text
- [ ] Store geometry in normalized 0..1 coordinates with top-left origin
- [ ] Bind annotations to single frame or frame range
- [ ] Implement DB persistence for review items + annotations
- [ ] On relaunch, restore review state and render overlays on correct frames

## Verification
- Manual smoke test:
- Create annotations, quit app, reopen project, verify 100% restored.
- Automated:
- Round-trip tests for review items + annotations pass.

## Notes / Decisions
- DB is source-of-truth; sidecar only via export unless user opts in.
