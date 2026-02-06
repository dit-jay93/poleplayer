# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Codec / Container Policy (V1)

### Supported (V1)
- Video:
  - `.mov` ProRes (422/422HQ/4444 family)
  - `.mov`/`.mp4` H.264
  - `.mov`/`.mp4` H.265 (HEVC)
- Images:
  - `.png`, `.tiff`, `.jpg` (still images)

### Partially Supported (V1.5+ target)
- DPX (single + sequence)
- EXR (RGB sequence only)

### Unsupported in V1 (V2 via plugins)
- ARRIRAW / ARRI HDE (SDK/plugin)
- RED `.r3d` (SDK/plugin or proxy resolver)
- MXF camera-specific variants beyond baseline macOS decode

---

## Rules
1) Precision mode must guarantee ±0 frame step/seek **for Supported formats**.
2) For Long-GOP (H.264/H.265):
   - Real-time scrubbing may be approximate.
   - Precision seek/step must be exact (latency acceptable).
3) VFR sources:
   - Either explicitly unsupported in V1, or must be normalized (choose policy early).
4) Color metadata:
   - Display a best-effort summary; do not claim full color management in V1.

---

## User-Facing Messaging
- Clearly label “Supported / Partial / Not supported” in import errors.
- Provide suggestion: generate ProRes proxy for unsupported formats (optional feature later).
