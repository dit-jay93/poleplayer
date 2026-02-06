# 50 — Export Package (Still + notes.json)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 40_REVIEW_PERSIST.md
- References: NOTES_SCHEMA.md, MVP.md

## Deliverables
- Code: Still capture, burn-in, notes.json writer, package builder
- Tests/Bench: Schema validation tests + export round-trip replay
- Docs: NOTES_SCHEMA.md finalized, CODEC_POLICY.md updated if needed

## Checklist (Codex)
- [ ] Implement still capture from current frame (PNG)
- [ ] Implement burn-in still capture option
- [ ] Generate notes.json per schema version 1.0.0
- [ ] Include asset hash and timeline metadata in notes.json
- [ ] Provide export naming template and destination selection

## Verification
- Manual smoke test:
- Export a package; move to another machine; re-import and reproduce overlays from notes.json.
- Automated:
- JSON schema checks + unit tests for writer pass.

## Notes / Decisions
- Prefer deterministic ordering in JSON to reduce diffs.
