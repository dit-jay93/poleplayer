# 60 — Benchmark Automation (Scripted Tests)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 50_EXPORT_PACKAGE.md
- References: BENCHMARK.md

## Deliverables
- Code: Bench runner CLI/tool inside app bundle or separate target
- Tests/Bench: Bench results stored as JSON logs for comparison
- Docs: BENCHMARK.md updated with run instructions

## Checklist (Codex)
- [ ] Implement step accuracy test: +1 frame x 1000 with expected vs actual
- [ ] Implement random seek test: 100 seeks, measure accuracy and latency
- [ ] Implement LUT toggle consistency test harness
- [ ] Output results as benchmark_report.json
- [ ] Define pass/fail thresholds matching BENCHMARK.md

## Verification
- Manual smoke test:
- Run benchmark on reference clips locally; confirm report generated.
- Automated:
- CI runs a reduced benchmark set (small clips) to catch regressions.

## Notes / Decisions
- Keep bench deterministic; log machine specs in report.
