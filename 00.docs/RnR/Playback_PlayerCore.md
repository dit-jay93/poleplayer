# RnR — Playback / PlayerCore Engineer
- Scope: timeline state machine, controls, mode switching logic, playback correctness

## Responsibilities
- Implement timeline state machine (play/pause/loop/in-out).
- Implement input commands (JKL, frame step, seek-to-frame).
- Implement hybrid mode switching rules and provide observables to UI.
- Ensure precision actions force exact frame decode path.
- Provide timecode/frame mapping best-effort for supported formats.

## Primary Deliverables
- `PlayerCore` module implementation
- State transition unit tests
- Benchmark hooks aligned with `BENCHMARK.md`

## Codex Checklist
- [ ] Precision mode: step/seek is ±0 for ProRes reference set
- [ ] Long-GOP: Real-time remains smooth; Precision seek is exact (latency acceptable)
- [ ] No desync between displayed HUD and actual frame index
