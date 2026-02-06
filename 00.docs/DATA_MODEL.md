# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Storage Strategy
- **DB is source-of-truth**
- Sidecar JSON is produced via Export and optional sync writing.

---

## Entities (Conceptual)
### Project
- id, name, createdAt, updatedAt
- settings: LUT preferences, overlays

### Asset
- id
- uri (path)
- fileHashSHA256 (primary match key)
- fileSizeBytes, modifiedAt
- type: video / still / sequence
- derived: proxy links (future)

### ReviewItem
- id, assetId, title, tags
- range: startFrame/endFrame (+ start/end timecode if available)
- createdAt/updatedAt

### Annotation
- id, reviewItemId
- type: pen/rect/circle/arrow/text
- normalized geometry/path (0..1 space)
- style (stroke/fill)
- optional text block

### ExportRecord
- id, reviewItemId, exportPath, exportedAt, notesSchemaVersion

---

## Matching Rules
When opening a project:
1) Try exact `fileHashSHA256`
2) If missing: fallback (size + modifiedAt + filename)
3) If still missing: mark asset as “offline”, keep review data.

---

## Coordinate System
- Normalized 0..1, origin = top-left.
- Stroke widths stored relative to 1080p baseline to preserve look.

---

## Migration / Versioning
- DB schema version tracked.
- notes.json schema version tracked separately (`NOTES_SCHEMA.md`).
