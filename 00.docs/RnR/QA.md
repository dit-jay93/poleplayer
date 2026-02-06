# RnR — QA Engineer
- Scope: test plan, regression, benchmark validation, release readiness

## Responsibilities
- Create functional test plan: import, playback, precision step/seek, LUT, review, export.
- Maintain regression suite aligned to `MVP.md` DoD.
- Run and archive benchmark reports (`BENCHMARK.md`) and gate results.
- Own bug triage workflow (severity/priority) and release blocking rules.
- Validate portability: export package opens on another machine/environment.

## Primary Deliverables
- Test case list + regression checklist (recommended add): `TEST_PLAN.md`
- Benchmark reports (JSON logs) archived per build
- Gate pass/fail sign-off notes

## Codex Checklist
- [ ] Precision ±0 verified on ProRes reference set
- [ ] Export package reproduction validated on a second environment
- [ ] Long-run stability test (10+ minutes) passes without consistent stutter/crash
