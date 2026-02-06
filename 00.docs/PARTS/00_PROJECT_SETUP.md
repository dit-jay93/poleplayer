# 00 — Project Setup & CI
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: None
- References: README.md, DEV_PLAN.md

## Deliverables
- Code: Xcode project skeleton, module targets, build scripts
- Tests/Bench: CI workflow runs build + tests
- Docs: Update README with build/run steps

## Checklist (Codex)
- [ ] Create Xcode workspace with modular targets: PlayerCore, RenderCore, DecodeKit, Review, Library, Export
- [ ] Set up SwiftLint/formatting (optional) and basic coding conventions
- [ ] Add CI pipeline: build Debug/Release, run unit tests
- [ ] Add minimal crash logging hook (can be stub for MVP)
- [ ] Add feature flags system (simple)

## Verification
- Manual smoke test:
- Open project, build, run app, verify empty window renders.
- Automated:
- CI passes on main branch for build + unit tests.

## Notes / Decisions
- Keep dependencies minimal for V1.
