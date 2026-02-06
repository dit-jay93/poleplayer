# RnR — Review / Data Engineer (Persistence + notes.json)
- Scope: DB schema, annotation model, persistence, export schema writer

## Responsibilities
- Define DB schema for projects/assets/review items/annotations/exports.
- Store annotation geometry in normalized space (0..1) with origin specified.
- Implement asset matching (sha256 + size + mtime) to survive moves/renames.
- Implement notes.json writer compliant with `NOTES_SCHEMA.md`.
- Ensure relaunch restores review state 100% for reference projects.

## Primary Deliverables
- Review persistence layer + migrations (if needed)
- notes.json writer + schema validation tests
- Round-trip tests (create → save → load)

## Codex Checklist
- [ ] Relaunch restores all annotations and notes without drift
- [ ] Exported notes.json contains required identifiers and range info
- [ ] Importing export package can reconstruct overlays (replay tool optional)
