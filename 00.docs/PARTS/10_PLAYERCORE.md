# 10 — PlayerCore (Timeline, Modes, Controls)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 00_PROJECT_SETUP.md
- References: ARCHITECTURE.md, BENCHMARK.md

## Deliverables
- Code: PlayerState, Timeline, Commands (JKL/step/seek), mode switching
- Tests/Bench: Unit tests for state transitions; bench harness hooks
- Docs: ARCHITECTURE.md updated if APIs change

## Checklist (Codex)
- [ ] Implement timeline state machine: play/pause/stop/loop/in-out
- [ ] Implement keyboard controls: JKL, frame step, seek-to-frame
- [ ] Implement hybrid mode switching rules (auto precision triggers)
- [ ] Expose playback observables for UI (timecode/frame index)
- [ ] Integrate basic overlay data: fps, resolution, frame index

## Verification
- Manual smoke test:
- Load reference clip, JKL works, frame step updates frame index.
- Automated:
- Unit tests cover mode transitions and in/out loop logic.

## Notes / Decisions
- Precision actions should force allowApproximate=false.
