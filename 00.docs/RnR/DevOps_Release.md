# RnR — DevOps / Release Engineer
- Scope: CI/CD, signing/notarization, crash logging, build hygiene

## Responsibilities
- Build CI pipeline: build + unit tests; optional reduced benchmark run.
- Manage signing/notarization workflow based on distribution strategy.
- Set up crash/log collection and ensure symbols are uploaded (if used).
- Define release checklist and versioning rules.
- Produce reproducible build artifacts.

## Primary Deliverables
- CI configuration + build scripts
- Release checklist (recommended add): `RELEASE_CHECKLIST.md`
- Artifact naming and retention policy

## Codex Checklist
- [ ] CI is green on main for build + unit tests
- [ ] Release signing/notarization procedure documented and repeatable
- [ ] Crash logging enabled at least in Beta builds
