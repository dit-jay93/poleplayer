# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## `notes.json` Export Schema (v1.0.0)
### Package Layout
- still image(s) + notes.json in one folder (optionally attachments/).

---

## Top-level Structure
- schema: name + version
- export: export_id, timestamp, app info
- author: display_name, role, optional email/org
- project: optional show/sequence/shot context
- asset: uri, file hash, size, modified date
- timeline: fps, timebase, start timecode, duration_frames
- color: LUT reference (name/path/hash/intensity)
- review_items[]: ranges + annotations + notes + attachments

---

## Field Rules (Hard Requirements)
1) `asset.file_hash_sha256` required (HEX string).
2) `annotations[].geometry` uses normalized 0..1 coordinates.
3) `review_items[].range` stores:
   - start/end frame indices
   - start/end timecode strings if available
4) `schema.version` must be semver.

---

## Annotation Types
- rect: x,y,w,h + rotation_deg (rotation currently 0)
- circle: x,y,w,h
- arrow: start/end points {x,y}
- pen: list of points [{x,y}]
- text: x,y + text

### Style
- stroke_rgba: [r,g,b,a]
- fill_rgba: [r,g,b,a]
- stroke_width: number

---

## Example
See `examples/notes.example.json` if provided by project later.
